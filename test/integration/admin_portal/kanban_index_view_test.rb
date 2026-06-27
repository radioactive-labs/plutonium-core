# frozen_string_literal: true

require "test_helper"

# Integration tests for the kanban board shell on the index page (Task 10).
#
# Route: GET /admin/tasks?view=kanban  (no column param)
#
# The shell is rendered by Plutonium::UI::Kanban::Resource, wired into
# Index#render_default_content via the :kanban branch + _resource_kanban partial.
# Each column emits a lazy turbo-frame (id kanban-col-<key>, loading="lazy")
# that the Task 6 column endpoint fills on demand.
#
# Covered:
#   * ?view=kanban (no column) → 200 with board shell
#   * Shell contains one turbo-frame per column with correct id + lazy loading
#   * Shell contains column header labels
#   * Shell does NOT render the table (no <table> element)
#   * View switcher includes a "Board" segment when :kanban is in index_views
#   * ?view=table (default) renders the table, not the board
#   * ?view=kanban selection is honoured (resolves to kanban view)
class AdminPortal::KanbanIndexViewTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @todo  = Task.create!(title: "Todo Alpha",  status: "todo")
    @doing = Task.create!(title: "Doing One",   status: "doing")
    @done  = Task.create!(title: "Done One",    status: "done")
  end

  teardown { Task.delete_all }

  # ─── Board shell: 200 + turbo-frames per column ─────────────────────────────

  test "GET ?view=kanban returns 200" do
    get "/admin/tasks?view=kanban"
    assert_response :success
  end

  test "board shell renders a lazy turbo-frame for each column" do
    get "/admin/tasks?view=kanban"
    # Each column emits its own <turbo-frame id="kanban-col-<key>" … loading="lazy">.
    # Assert id AND lazy together per frame so neither can silently regress.
    %w[todo doing done].each do |key|
      assert_match(/<turbo-frame[^>]*loading="lazy"[^>]*id="kanban-col-#{key}"/, response.body,
        "expected a lazy turbo-frame for the #{key} column")
    end
  end

  test "board shell does not render a table element" do
    get "/admin/tasks?view=kanban"
    # The <table> tag is the hallmark of the Table::Resource component.
    # The kanban shell must not include it — cards are lazy-loaded per column.
    refute_includes response.body, "<table"
  end

  # ─── Column frame src encodes view=kanban + column=<key> ────────────────────

  test "todo frame src includes view=kanban and column=todo" do
    get "/admin/tasks?view=kanban"
    assert_match(/view=kanban/, response.body)
    assert_match(/column=todo/, response.body)
  end

  test "doing frame src includes column=doing" do
    get "/admin/tasks?view=kanban"
    assert_match(/column=doing/, response.body)
  end

  test "done frame src includes column=done" do
    get "/admin/tasks?view=kanban"
    assert_match(/column=done/, response.body)
  end

  # ─── Column headers are present in the shell ────────────────────────────────

  # The shell renders column headers inside each turbo-frame so the board is
  # meaningful while the lazy card bodies load. Labels come from the DSL column
  # definitions (title-cased from the key by default).
  #
  # These assertions target the HEADER label span specifically — the
  # `font-semibold … truncate` span that Kanban::Resource#render_column_header
  # wraps the label in — rather than a bare substring. A bare /todo/ would pass
  # trivially against card titles ("Todo Alpha") and prove nothing about the
  # header. (Cards aren't even rendered in the lazy shell, but the precise
  # match keeps the test honest regardless.)
  test "board shell renders each column label inside the header span" do
    get "/admin/tasks?view=kanban"
    {todo: "Todo", doing: "Doing", done: "Done"}.each do |_key, label|
      assert_match(/class="font-semibold[^"]*truncate"[^>]*>\s*#{label}\s*</, response.body,
        "expected the #{label} label inside the column header span")
    end
  end

  # ─── Table still renders on default / explicit table view ───────────────────

  test "default index (no view param) renders the table, not the board" do
    get "/admin/tasks"
    assert_response :success
    assert_includes response.body, "<table"
    refute_includes response.body, 'id="kanban-col-todo"'
  end

  test "?view=table explicitly renders the table, not the board" do
    get "/admin/tasks?view=table"
    assert_response :success
    assert_includes response.body, "<table"
    refute_includes response.body, 'id="kanban-col-todo"'
  end

  # ─── ?view=kanban selection resolves to kanban ──────────────────────────────

  test "?view=kanban param selects the board shell" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    # At least one kanban column frame present confirms the kanban branch fired.
    assert_includes response.body, 'id="kanban-col-todo"'
  end

  # ─── Unauthenticated is redirected ─────────────────────────────────────────

  test "unauthenticated request is redirected" do
    logout_admin
    get "/admin/tasks?view=kanban"
    assert_response :redirect
  end

  # ─── Shared toolbar (view switcher + search) renders on every view ──────────

  # The TaskDefinition registers :kanban in defined_index_views, so the
  # view switcher (rendered inside the shared TableToolbar) has >1 view and
  # therefore renders.

  test "table view response includes Board segment in view switcher" do
    get "/admin/tasks"
    assert_response :success
    assert_includes response.body, "Board"
  end

  # The board view renders the SAME toolbar as table/grid, so users can switch
  # back to Table/Grid (and search/filter where configured) from the board —
  # not just see bare columns.
  test "kanban board renders the view switcher toolbar" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    # The view-switcher segmented control (its Stimulus controller) is present…
    assert_match(/data-controller="view-switcher"/, response.body)
    # …with the Board segment marked selected and a Table segment to switch to.
    assert_match(/data-view-switcher-view-param="kanban"[^>]*|aria-selected="true"[^>]*Board/m, response.body)
    assert_includes response.body, "Board"
    assert_includes response.body, "Table"
    # Wrapped in the filter-panel controller (so the filter button can open it).
    assert_match(/data-controller="filter-panel"/, response.body)
  end
end
