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
# There is NO pre-create seeding. The form threads kanban_column to the create
# POST as a hidden field; the record is created normally (with the model's
# DEFAULT grouping value), and `KanbanActions#after_create_persisted` then
# applies the column's on_enter to the freshly-persisted record and positions it
# into the column. on_enter runs against a REAL record — no dry-run, no stubbing.
#
# The acceptance criteria tested here:
#   * :todo column (add: true via role: :backlog) renders a "+ Add" control
#   * :doing and :done columns (no add: true) do NOT render "+ Add"
#   * The "+ Add" link opens the new form in the Turbo modal frame
#   * The new form threads kanban_column to create as a hidden field
#   * A quick-add create applies the column's on_enter POST-create (lands in the
#     clicked column, positioned)
#   * A raising on_enter KEEPS the created record in its default column + toasts
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

  test "new form threads kanban_column to create as a hidden field" do
    get "/admin/tasks/new?kanban_column=todo"
    assert_response :success
    # No pre-fill anymore; instead the column key rides to the create POST as a
    # hidden field so after_create_persisted can apply the column's on_enter.
    assert_match(/<input[^>]*name="kanban_column"[^>]*value="todo"/, response.body,
      "the new form must carry kanban_column as a hidden field")
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

  # ─── on_enter applied POST-create + positioning ───────────────────────────

  # No pre-fill: the record is created with the model default, then on_enter runs
  # against the REAL persisted record and it's positioned into the column. We swap
  # resolve_columns for an addable column whose Symbol on_enter (:mark_done! →
  # update!(status: "done")) sets a status DIFFERENT from the default ("todo"), so
  # the assertion proves on_enter actually ran post-create (not just the default).
  test "quick-add create applies the column's on_enter post-create and appends it" do
    existing_done = Task.create!(title: "Existing Done", status: "done")

    sink = Plutonium::Kanban::Column.new(
      :sink, add: true, scope: -> { where(status: "done") }, on_enter: :mark_done!
    )
    grouping = Plutonium::Kanban::Grouping
    original = grouping.method(:resolve_columns)
    grouping.define_singleton_method(:resolve_columns) { |*| [sink] }
    begin
      # No task[status] — relies on the model default, then on_enter overrides it.
      post "/admin/tasks", params: {task: {title: "Sunk"}, kanban_column: "sink"}
    ensure
      grouping.define_singleton_method(:resolve_columns, original)
    end

    assert_response :redirect
    task = Task.find_by(title: "Sunk")
    assert_not_nil task, "the record must be created"
    assert_equal "done", task.status,
      "on_enter must run POST-create against the real record (status=done, not the default todo)"
    assert task.position > existing_done.reload.position,
      "the new card must be appended to the END of the destination column"
  end

  # ─── raising on_enter KEEPS the record + toasts (no rollback) ──────────────

  # If on_enter raises after the record is already created, the create is NOT
  # rolled back: the record stays in its DEFAULT column and the failure is
  # toasted. Create completes independently of the enter step.
  test "a raising on_enter keeps the created record in its default column and toasts" do
    boom = Plutonium::Kanban::Column.new(
      :boom, add: true, scope: -> { where(status: "done") },
      on_enter: ->(_r) { raise "kaboom in on_enter" }
    )
    grouping = Plutonium::Kanban::Grouping
    original = grouping.method(:resolve_columns)
    grouping.define_singleton_method(:resolve_columns) { |*| [boom] }
    begin
      post "/admin/tasks", params: {task: {title: "Kept"}, kanban_column: "boom"}
    ensure
      grouping.define_singleton_method(:resolve_columns, original)
    end

    assert_response :redirect, "a raising on_enter must not 500 — the create still succeeds"
    task = Task.find_by(title: "Kept")
    assert_not_nil task, "the record must be KEPT (create is not rolled back)"
    assert_equal "todo", task.status,
      "the record stays in its default column when on_enter fails"
    assert_match(/couldn.t place/i, flash[:alert].to_s,
      "the on_enter failure must be surfaced as a toast")
  end
end
