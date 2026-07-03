# frozen_string_literal: true

require "test_helper"

# Integration tests for the per-column quick-add affordance (Task 12).
#
# When a column declares `add: true` (or has a role preset that implies it,
# e.g. role: :backlog), the column's lazy-frame response renders a "+ Add"
# link in the header.  Clicking the link opens the resource's existing NEW
# form (same Turbo modal used by the index "New" button) with the column key
# threaded via the `kanban_column=` query param.
#
# The `KanbanActions#apply_kanban_column_defaults!` before_action intercepts
# the new action, runs an in-memory dry-run of the column's on_enter callback
# (with save! / update! intercepted so no DB row is written), and injects the
# resulting attribute changes into params so the form pre-fills the grouping
# attribute (e.g. `status: "todo"`).
#
# The acceptance criteria tested here:
#   * :todo column (add: true via role: :backlog) renders a "+ Add" control
#   * :doing and :done columns (no add: true) do NOT render "+ Add"
#   * The "+ Add" link opens the new form in the Turbo modal frame
#   * The new form, accessed with kanban_column=todo, pre-fills status="todo"
#   * Submitting the pre-filled form creates a task that lands in the :todo
#     column with position assigned (via the Positioning before_create hook)
#   * When the policy denies create?, the "+ Add" control is not rendered
class AdminPortal::KanbanQuickAddTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  teardown do
    Task.delete_all
    TaskPolicy.deny_create = false
  end

  # ─── "+ Add" link present in :todo column ─────────────────────────────────

  test ":todo column renders a '+ Add' link" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_includes response.body, "+ Add",
      ":todo column (add: true from backlog role) should render the + Add link"
  end

  test ":todo column '+ Add' link carries the kanban_column param" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_includes response.body, "kanban_column=todo",
      "+ Add link must carry kanban_column=todo so the new form can seed the column"
  end

  test ":todo column '+ Add' link points to the new resource form" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_includes response.body, "/admin/tasks/new",
      "+ Add link must point to the existing new-task path"
  end

  test ":todo column '+ Add' link targets the remote modal frame" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    # The link must carry data-turbo-frame="remote_modal" so the form opens
    # in the existing modal overlay, not a full-page navigation.
    assert_includes response.body, "remote_modal",
      "+ Add link must target the remote_modal turbo frame"
  end

  # ─── "+ Add" absent in columns without add: true ─────────────────────────

  test ":doing column does NOT render '+ Add'" do
    get "/admin/tasks?view=kanban&column=doing"
    assert_response :success
    refute_includes response.body, "+ Add",
      ":doing column has no add: true preset, so + Add must not appear"
  end

  test ":done column does NOT render '+ Add'" do
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    refute_includes response.body, "+ Add",
      ":done column (role: :done) has no add: true, so + Add must not appear"
  end

  # ─── New form seeding via kanban_column param ────────────────────────────

  test "new form accessed with kanban_column=todo returns 200" do
    get "/admin/tasks/new?kanban_column=todo"
    assert_response :success
  end

  test "new form with kanban_column=todo pre-fills the grouping attribute" do
    get "/admin/tasks/new?kanban_column=todo"
    assert_response :success
    # The on_enter for :todo assigns status="todo". apply_kanban_column_defaults!
    # injects that into params so the rendered form carries the pre-filled value.
    # Assert the actual status INPUT carries value="todo" rather than just that
    # the string "todo" appears somewhere in the page (which would pass even
    # without any pre-fill, e.g. from the column key in the + Add link).
    # Regex (not assert_select) because the [status] brackets break Nokogiri's
    # CSS attribute-selector parsing. [^>]* keeps the match within one tag.
    assert_match(/name="task\[status\]"[^>]*value="todo"/, response.body,
      "the task[status] input should be pre-filled with value=\"todo\"")
  end

  # ─── Creating via the quick-add flow lands the record in the column ───────

  test "creating a task with the seeded status lands it in the :todo column" do
    # Simulate the user filling in the title and submitting the pre-filled form.
    # The form submission includes status="todo" because the form was pre-filled.
    post "/admin/tasks", params: {task: {title: "Quick-Add Task", status: "todo"}}

    assert_response :redirect, "successful create should redirect"

    task = Task.order(created_at: :desc).first
    assert_not_nil task, "a task should have been created"
    assert_equal "Quick-Add Task", task.title
    assert_equal "todo", task.status,
      "task should be in the :todo column (status='todo')"
  end

  test "created task has a position assigned by the Positioning before_create hook" do
    post "/admin/tasks", params: {task: {title: "Positioned Task", status: "todo"}}
    assert_response :redirect

    task = Task.order(created_at: :desc).first
    assert_not_nil task.position,
      "Positioning concern's before_create must assign a position"
    assert task.position > 0, "position must be positive"
  end

  test "second task created in :todo gets a higher position than the first" do
    post "/admin/tasks", params: {task: {title: "First", status: "todo"}}
    post "/admin/tasks", params: {task: {title: "Second", status: "todo"}}

    first = Task.find_by(title: "First")
    second = Task.find_by(title: "Second")
    assert second.position > first.position,
      "second task should have a higher position than the first (appended to end of column)"
  end

  test "task created in :todo appears in the :todo column frame on reload" do
    post "/admin/tasks", params: {task: {title: "Reloaded Task", status: "todo"}}
    assert_response :redirect

    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_includes response.body, "Reloaded Task",
      "newly created task should appear in the :todo column frame"
  end

  # ─── Policy gate ──────────────────────────────────────────────────────────

  test "'+ Add' is absent when policy denies create?" do
    TaskPolicy.deny_create = true

    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    refute_includes response.body, "+ Add",
      "+ Add must be hidden when the policy's create? returns false"
  end

  test "policy gate is per-request: re-enabling create? restores the link" do
    TaskPolicy.deny_create = true
    get "/admin/tasks?view=kanban&column=todo"
    refute_includes response.body, "+ Add"

    TaskPolicy.deny_create = false
    get "/admin/tasks?view=kanban&column=todo"
    assert_includes response.body, "+ Add",
      "+ Add must reappear when create? is re-enabled"
  end

  # ─── Symbol on_enter seed branch (fix #2) ─────────────────────────────────

  # The :todo column uses a Proc on_enter. The Symbol branch of the seed
  # extractor (record.public_send(sym)) is exercised here by binding the
  # private controller method against a column with a Symbol on_enter. The
  # Task#mark_done! method calls update!(status: "done"); the seed extractor
  # stubs update! so the change is captured in-memory without a DB write.
  test "kanban_column_on_enter_seed captures attrs set by a Symbol on_enter" do
    column = Plutonium::Kanban::Column.new(:done_add, add: true, on_enter: :mark_done!)

    harness = Object.new
    harness.define_singleton_method(:resource_class) { Task }
    seed_method = Plutonium::Resource::Controllers::KanbanActions
      .instance_method(:kanban_column_on_enter_seed)

    result = seed_method.bind_call(harness, column)

    assert_equal "done", result["status"],
      "Symbol on_enter (:mark_done!) should seed status='done' without a DB write"
    assert_equal 0, Task.where(status: "done").count,
      "the dry-run must not persist any record"
  end

  # ─── Raising on_enter degrades gracefully (fix #1) ────────────────────────

  # An on_enter that raises during the dry-run must NOT 500 the new form. The
  # controller rescues, logs a warning, and serves the form UNSEEDED so the
  # user can still create the record. We swap Grouping.resolve_columns (called
  # synchronously within the in-process request) for one returning a column
  # whose on_enter raises, then restore it in ensure.
  test "raising on_enter renders the new form unseeded (200), not a 500" do
    boom_column = Plutonium::Kanban::Column.new(
      :todo, add: true, on_enter: ->(_r) { raise "kaboom in on_enter" }
    )

    grouping = Plutonium::Kanban::Grouping
    original = grouping.method(:resolve_columns)
    grouping.define_singleton_method(:resolve_columns) { |*| [boom_column] }
    begin
      get "/admin/tasks/new?kanban_column=todo"
    ensure
      grouping.define_singleton_method(:resolve_columns, original)
    end

    assert_response :success, "a raising on_enter must degrade to a 200 form, not crash"
    # Unseeded: the status input must NOT carry a pre-filled value="todo".
    refute_match(/name="task\[status\]"[^>]*value="todo"/, response.body,
      "form should be unseeded when the on_enter dry-run raises")
  end
end
