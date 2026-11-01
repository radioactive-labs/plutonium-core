# frozen_string_literal: true

require "test_helper"

# A column holding more cards than per_column:
#   * every count (header badge, WIP badge, collapsed strip) is the full total
#   * the footer links to the same column frame with a higher kanban_limit
#   * kanban_limit is clamped to [per_column, KANBAN_COLUMN_LIMIT_MAX]
#   * a move keeps the columns' limits (from_limit/to_limit) and the board query
# and the board-level column_summary renders over the whole column.
class AdminPortal::KanbanColumnOverflowTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html"

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @todos = 5.times.map { |i| Task.create!(title: "Todo #{i}", status: "todo") }
    @doing = Task.create!(title: "Doing One", status: "doing")
  end

  teardown { Task.delete_all }

  test "count badge shows the column total, not the capped card count" do
    with_board do
      get "/admin/tasks?view=kanban&column=todo"
      assert_equal 2, card_count
      assert_match(%r{pu-badge[^"]*"[^>]*>5</span>}, response.body)
    end
  end

  test "footer links to the column frame with the next kanban_limit" do
    with_board do
      get "/admin/tasks?view=kanban&column=todo&q[search]=Todo"
      link = more_link
      assert link, "expected a load-more link"
      assert_equal "kanban-col-todo", link["data-turbo-frame"]
      query = Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)
      assert_equal({"column" => "todo", "kanban_limit" => "4", "view" => "kanban", "q" => {"search" => "Todo"}}, query)
      assert_includes response.body, "+3 more"
      assert_includes link.text, "Show 2 more"
    end
  end

  test "kanban_limit loads more cards and the last page has no link" do
    with_board do
      get "/admin/tasks?view=kanban&column=todo&kanban_limit=4"
      assert_equal 4, card_count
      assert_includes more_link.text, "Show 1 more"

      get "/admin/tasks?view=kanban&column=todo&kanban_limit=6"
      assert_equal 5, card_count
      assert_nil more_link
    end
  end

  test "kanban_limit is clamped to per_column and the maximum" do
    with_board do
      get "/admin/tasks?view=kanban&column=todo&kanban_limit=1"
      assert_equal 2, card_count

      get "/admin/tasks?view=kanban&column=todo&kanban_limit=-5"
      assert_equal 2, card_count
    end

    with_board(per_column: 1, max: 3) do
      get "/admin/tasks?view=kanban&column=todo&kanban_limit=1000"
      assert_equal 3, card_count
      assert_nil more_link, "no link once the maximum is reached"
      assert_includes response.body, "+2 more"
    end
  end

  test "column_summary renders over the whole column under the board query" do
    with_board(summary: ->(relation) { "#{relation.count} tasks" }) do
      get "/admin/tasks?view=kanban&column=todo"
      assert_includes response.body, "5 tasks"

      get "/admin/tasks?view=kanban&column=todo&q[search]=Todo%201"
      assert_includes response.body, "1 tasks"
    end
  end

  test "column_summary block receives the column" do
    with_board(summary: proc { |relation, column| "#{column.key}:#{relation.count}" }) do
      get "/admin/tasks?view=kanban&column=doing"
      assert_includes response.body, "doing:1"
    end
  end

  test "a move keeps each column's limit" do
    with_board do
      post "/admin/tasks/#{@doing.id}/kanban_move",
        params: {from_column: "doing", to_column: "todo", to_index: 0, from_limit: 2, to_limit: 6},
        headers: {"Accept" => TURBO_STREAM_ACCEPT}
      assert_response :ok
      todo = stream_frame("kanban-col-todo")
      assert_equal 6, todo.css("[data-kanban-record-id]").size
    end
  end

  test "a move applies the board query sent in the URL" do
    with_board do
      post "/admin/tasks/#{@todos.first.id}/kanban_move?q[search]=Todo",
        params: {from_column: "todo", to_column: "doing", to_index: 0},
        headers: {"Accept" => TURBO_STREAM_ACCEPT}
      assert_response :ok
      doing = stream_frame("kanban-col-doing")
      assert_includes doing.text, "Todo 0"
      refute_includes doing.text, "Doing One", "the search must filter the re-rendered column"
    end
  end

  test "an on: :visible column action covers the cards shown after Show more" do
    with_board(visible_action: true) do
      get "/admin/tasks?view=kanban&column=todo&kanban_limit=4"
      link = Nokogiri::HTML(response.body).at_css(%(a[data-kanban-action="archive_all"]))
      ids = Rack::Utils.parse_nested_query(URI.parse(link["href"]).query)["ids"]
      assert_equal 4, ids.size
    end
  end

  private

  def card_count
    Nokogiri::HTML(response.body).css("[data-kanban-record-id]").size
  end

  def more_link
    Nokogiri::HTML(response.body).at_css("a[data-kanban-load-more]")
  end

  def stream_frame(target)
    node = Nokogiri::HTML(response.body).at_css(%(turbo-stream[target="#{target}"] template))
    Nokogiri::HTML.fragment(node.inner_html)
  end

  def with_board(per_column: 2, max: nil, summary: nil, visible_action: false)
    original_board = TaskDefinition.defined_kanban_board
    TaskDefinition.defined_kanban_board = Plutonium::Kanban::DSL.build(resource_class: Task) do
      per_column per_column
      column_summary summary if summary
      card_fields header: :title, meta: [:status], footer: false
      column :todo, scope: -> { where(status: "todo") }, on_enter: ->(r) { r.update!(status: "todo") } do
        # :archive_all is registered by TaskDefinition's own board.
        action :archive_all, interaction: ArchiveTasksInteraction, on: :visible if visible_action
      end
      column :doing, scope: -> { where(status: "doing") }, on_enter: ->(r) { r.update!(status: "doing") }
    end
    if max
      original_max = Plutonium::Resource::Controllers::KanbanActions::KANBAN_COLUMN_LIMIT_MAX
      silence_warnings { Plutonium::Resource::Controllers::KanbanActions.const_set(:KANBAN_COLUMN_LIMIT_MAX, max) }
    end
    yield
  ensure
    TaskDefinition.defined_kanban_board = original_board
    silence_warnings { Plutonium::Resource::Controllers::KanbanActions.const_set(:KANBAN_COLUMN_LIMIT_MAX, original_max) } if original_max
  end
end
