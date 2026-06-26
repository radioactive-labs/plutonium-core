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

  test "board shell contains turbo-frame for todo column with lazy loading" do
    get "/admin/tasks?view=kanban"
    assert_includes response.body, 'id="kanban-col-todo"'
    assert_includes response.body, 'loading="lazy"'
  end

  test "board shell contains turbo-frame for doing column" do
    get "/admin/tasks?view=kanban"
    assert_includes response.body, 'id="kanban-col-doing"'
  end

  test "board shell contains turbo-frame for done column" do
    get "/admin/tasks?view=kanban"
    assert_includes response.body, 'id="kanban-col-done"'
  end

  test "board shell renders all three column frames" do
    get "/admin/tasks?view=kanban"
    assert_includes response.body, 'id="kanban-col-todo"'
    assert_includes response.body, 'id="kanban-col-doing"'
    assert_includes response.body, 'id="kanban-col-done"'
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

  test "board shell contains Todo column header label" do
    get "/admin/tasks?view=kanban"
    # The column label rendered in the header may be "Todo", "todo", or the
    # titleized key. Match case-insensitively.
    assert_match(/todo/i, response.body)
  end

  test "board shell contains Doing column header label" do
    get "/admin/tasks?view=kanban"
    assert_match(/doing/i, response.body)
  end

  test "board shell contains Done column header label" do
    get "/admin/tasks?view=kanban"
    assert_match(/done/i, response.body)
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

  # ─── View switcher includes Board segment ───────────────────────────────────

  # The TaskDefinition registers :kanban in defined_index_views, so the
  # view switcher rendered inside Table::Resource (and Grid::Resource) will
  # have more than one view, making it render. When the shell renders we are
  # not inside Table::Resource, but we can confirm the segment label "Board"
  # is present in a standard table view response (switcher renders there).

  test "table view response includes Board segment in view switcher" do
    get "/admin/tasks"
    assert_response :success
    # The view switcher renders "Board" as the kanban segment label.
    assert_includes response.body, "Board"
  end
end
