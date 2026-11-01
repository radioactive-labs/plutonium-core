# frozen_string_literal: true

require "application_system_test_case"

# Browser-level check of a capped column: "Show more" loads the next cards into
# the column's frame, a drag afterwards keeps that expanded count, and a drag
# on a searched board re-renders the columns under the search.
#
# The drop is driven by dispatching the native drag events the kanban
# controller listens for (see kanban_drop_interaction_test.rb).
class AdminPortal::KanbanLoadMoreTest < ApplicationSystemTestCase
  setup do
    @admin = create_admin!
    @todos = 5.times.map { |i| Task.create!(title: "Todo #{i}", status: "todo") }
    @doing = Task.create!(title: "Doing One", status: "doing")
    @original_board = TaskDefinition.defined_kanban_board
    TaskDefinition.defined_kanban_board = Plutonium::Kanban::DSL.build(resource_class: Task) do
      per_column 2
      column_summary ->(relation) { "#{relation.count} in column" }
      card_fields header: :title, meta: [:status], footer: false
      column :todo, scope: -> { where(status: "todo") }, on_enter: ->(r) { r.update!(status: "todo") }
      column :doing, scope: -> { where(status: "doing") }, on_enter: ->(r) { r.update!(status: "doing") }
    end
  end

  teardown do
    TaskDefinition.defined_kanban_board = @original_board
    Task.delete_all
  end

  test "Show more expands the column and a drag keeps it expanded" do
    open_board

    assert_cards "todo", 2
    within("[data-kanban-col='todo']") { assert_text "5 in column" }

    click_link "Show 2 more"
    assert_cards "todo", 4

    drop_card_into_column(@doing.id, "todo")

    assert_selector "[data-kanban-col='todo'] [data-kanban-record-id='#{@doing.id}']", wait: 5
    assert_cards "todo", 4
    within("[data-kanban-col='todo']") { assert_text "6 in column" }
  end

  test "a drag on a searched board re-renders the columns under the search" do
    open_board("q[search]=Todo")
    assert_no_text "Doing One"

    drop_card_into_column(@todos.first.id, "doing")

    assert_selector "[data-kanban-col='doing'] [data-kanban-record-id='#{@todos.first.id}']", wait: 5
    assert_no_text "Doing One"
    assert_equal "doing", @todos.first.reload.status
  end

  private

  def open_board(query = nil)
    visit ["/admin/tasks?view=kanban", query].compact.join("&")
    fill_in "login", with: @admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"

    assert_selector "[data-controller~='kanban']", wait: 5
    assert_selector "[data-kanban-target='column'][data-kanban-column-key-value='doing']", wait: 5
  end

  def assert_cards(column, count)
    assert_selector "[data-kanban-col='#{column}'] [data-kanban-record-id]", count:, wait: 5
  end

  def drop_card_into_column(card_id, to_column)
    dispatched = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector("[data-kanban-record-id='#{card_id}']");
        const zone = document.querySelector(
          "[data-kanban-target='column'][data-kanban-column-key-value='#{to_column}']"
        );
        if (!card || !zone) return false;

        const dt = new DataTransfer();
        card.dispatchEvent(new DragEvent("dragstart",
          { bubbles: true, cancelable: true, dataTransfer: dt }));

        const rect = zone.getBoundingClientRect();
        zone.dispatchEvent(new DragEvent("drop",
          { bubbles: true, cancelable: true, dataTransfer: dt,
            clientX: rect.left + 5, clientY: rect.top + 5 }));

        card.dispatchEvent(new DragEvent("dragend",
          { bubbles: true, cancelable: true, dataTransfer: dt }));
        return true;
      })()
    JS

    assert dispatched, "drag simulation could not find card ##{card_id} or the '#{to_column}' drop zone"
  end
end
