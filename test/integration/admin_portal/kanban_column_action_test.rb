# frozen_string_literal: true

require "test_helper"

# Integration tests for kanban column-scoped actions (Task 8).
#
# The :done column in TaskDefinition declares:
#   action :archive_all, interaction: ArchiveTasksInteraction, on: :all, label: "Archive all"
#
# When the :done column frame is loaded the header renders an "Archive all"
# link that targets the existing interactive_bulk_action route:
#   GET /admin/tasks/bulk_actions/archive_all?ids[]=<id>&ids[]=<id>…
#
# The interaction is auto-registered via Definition::IndexViews.kanban so the
# route resolves without any manual `action :archive_all` in the definition.
#
# Coverage:
#   * :done column frame renders an "Archive all" link when tasks are present
#   * link href targets the bulk endpoint with all done-task ids (on: :all
#     ignores per_column cap — seeds > per_column, asserts all ids present)
#   * GET to the bulk URL returns 200 (interaction form / confirmation)
#   * POST to the bulk commit URL archives the tasks (status = "archived")
#   * A user whose archive_all? policy returns false does not see the link
class AdminPortal::KanbanColumnActionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  teardown do
    Task.delete_all
    TaskPolicy.deny_archive_all = false
  end

  # ─── Link rendered in column header ──────────────────────────────────────

  test ":done column renders an 'Archive all' link when done tasks exist" do
    Task.create!(title: "Done 1", status: "done")
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    assert_includes response.body, "Archive all"
  end

  test ":done column link targets the bulk_actions endpoint" do
    task = Task.create!(title: "Done 1", status: "done")
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    assert_includes response.body, "/admin/tasks/bulk_actions/archive_all"
    assert_includes response.body, "ids%5B%5D=#{task.id}"
  end

  # ─── on: :all includes ALL records, ignoring per_column cap ──────────────

  # The board's per_column is 25; seed 30 done tasks. The action link must
  # include all 30 ids, not just the 25 rendered cards. This proves on: :all
  # bypasses the per_column limit.
  test "action link includes all done-column ids regardless of per_column cap" do
    30.times { |i| Task.create!(title: "Done #{i}", status: "done") }
    assert_equal 30, Task.where(status: "done").count

    get "/admin/tasks?view=kanban&column=done"
    assert_response :success

    # All 30 task ids must be present in the action link href.
    done_ids = Task.where(status: "done").pluck(:id)
    assert_equal 30, done_ids.size

    done_ids.each do |id|
      assert_includes response.body, "ids%5B%5D=#{id}",
        "Expected id=#{id} in archive_all link but it was absent"
    end
  end

  # ─── Bulk route resolves (GET shows confirmation / interaction form) ──────

  test "GET to bulk action URL returns 200" do
    task = Task.create!(title: "Done 1", status: "done")
    get "/admin/tasks/bulk_actions/archive_all?ids[]=#{task.id}"
    assert_response :success
  end

  # ─── POST commits the interaction ────────────────────────────────────────

  test "POST to bulk commit URL archives all targeted done tasks" do
    done1 = Task.create!(title: "Done 1", status: "done")
    done2 = Task.create!(title: "Done 2", status: "done")
    _todo = Task.create!(title: "Todo 1", status: "todo")

    post "/admin/tasks/bulk_actions/archive_all",
      params: {ids: [done1.id, done2.id]}

    # Should redirect after success.
    assert_response :redirect

    done1.reload
    done2.reload
    _todo.reload

    assert_equal "archived", done1.status, "done1 should be archived"
    assert_equal "archived", done2.status, "done2 should be archived"
    assert_equal "todo",     _todo.status, "todo task should be untouched"
  end

  # ─── Policy gate hides the action for unauthorized users ─────────────────

  test "action link is absent when policy denies archive_all?" do
    Task.create!(title: "Done 1", status: "done")
    TaskPolicy.deny_archive_all = true

    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    refute_includes response.body, "Archive all",
      "action link should not render when policy denies archive_all?"
  end

  # ─── No action link in non-done columns ──────────────────────────────────

  test ":todo column does not render any column action link" do
    Task.create!(title: "Todo 1", status: "todo")
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    # :todo column has no declared actions — no archive link.
    refute_includes response.body, "bulk_actions",
      "todo column should have no bulk-action links"
  end

  # ─── Empty done column renders no action link ────────────────────────────

  # An empty id set would make resource_url_for(..., ids: []) resolve to the
  # RESOURCE action route instead of the bulk route, so the link is suppressed
  # entirely. Assert it is absent (and that the empty column does not crash).
  test "done column with no tasks renders no action link" do
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    refute_includes response.body, "bulk_actions",
      "empty column should render no bulk-action link"
    refute_includes response.body, "Archive all"
  end
end
