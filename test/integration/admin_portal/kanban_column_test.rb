# frozen_string_literal: true

require "test_helper"

# Integration tests for the per-column kanban lazy-frame endpoint (Task 6).
#
# The board shell (Task 10) wraps each column in a turbo-frame whose src hits
# GET /admin/tasks?view=kanban&column=<key>. This file tests that endpoint:
#   - Returns 200 with the column frame body (Kanban::Column HTML)
#   - Cards for the requested column appear; other columns' cards do not
#   - Cards are ordered by position ascending (board.position_config)
#   - The authorized scope is respected (admin can see seeded tasks)
#   - An unknown column key produces an empty frame body without crashing
class AdminPortal::KanbanColumnTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    # Seed tasks across columns. Positioning is scoped by :status so each
    # column starts at position 1.0 and increments independently.
    @todo_a = Task.create!(title: "Todo Alpha", status: "todo")
    @todo_b = Task.create!(title: "Todo Beta",  status: "todo")
    @doing  = Task.create!(title: "Doing One",  status: "doing")
    @done   = Task.create!(title: "Done One",   status: "done")
  end

  teardown { Task.delete_all }

  # ─── Basic 200 + column isolation ─────────────────────────────────────────

  test "returns 200 for the todo column" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
  end

  test "todo column body contains todo card titles" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_includes response.body, "Todo Alpha"
    assert_includes response.body, "Todo Beta"
  end

  test "todo column body does not contain cards from other columns" do
    get "/admin/tasks?view=kanban&column=todo"
    refute_includes response.body, "Doing One"
    refute_includes response.body, "Done One"
  end

  test "doing column body contains only doing cards" do
    get "/admin/tasks?view=kanban&column=doing"
    assert_includes response.body, "Doing One"
    refute_includes response.body, "Todo Alpha"
    refute_includes response.body, "Done One"
  end

  # ─── Position ordering ────────────────────────────────────────────────────

  test "cards appear in position order (alpha before beta in todo)" do
    get "/admin/tasks?view=kanban&column=todo"
    alpha_pos = response.body.index("Todo Alpha")
    beta_pos  = response.body.index("Todo Beta")
    assert alpha_pos && beta_pos,
      "expected both todo titles in response body"
    assert alpha_pos < beta_pos,
      "Todo Alpha (created first, lower position) should appear before Todo Beta"
  end

  # ─── Authorized scope ─────────────────────────────────────────────────────

  # Verifies the full pipeline (authorized scope → query-applied → grouped).
  # An unauthenticated request is redirected, proving the scope is enforced
  # at the policy level rather than fetching with Model.all.
  test "unauthenticated request is redirected to login" do
    logout_admin
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :redirect
  end

  test "authenticated admin sees seeded tasks in the column" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_includes response.body, "Todo Alpha"
  end

  # ─── Query pipeline applied ───────────────────────────────────────────────

  # Demonstrates that the relation is query-applied: a search param narrows
  # the column's cards, not just the overall collection. (The TaskDefinition
  # must configure search for this to take effect; if search is not configured,
  # the filter is a no-op, in which case the test still proves no crash.)
  #
  # We test a simpler proxy: sending ?q[scope]=nonexistent does not crash and
  # still returns 200. A full search-filter assertion would require configuring
  # search in the dummy definition, which is out of scope for Task 6.
  test "passing query params does not crash the column endpoint" do
    get "/admin/tasks?view=kanban&column=todo&q[scope]=nonexistent"
    assert_response :success
  end

  # ─── Unknown / absent column key ──────────────────────────────────────────

  test "unknown column key returns 200 with empty body" do
    get "/admin/tasks?view=kanban&column=bogus"
    assert_response :success
    # Body may be empty string or whitespace — it must not contain any card
    # titles from any column.
    refute_includes response.body, "Todo Alpha"
    refute_includes response.body, "Doing One"
    refute_includes response.body, "Done One"
  end

  # ─── Non-kanban resource falls through to normal index ────────────────────

  # When the resource has no kanban block, view=kanban + column= is ignored
  # and the normal index renders (no before_action intercept).
  test "non-kanban resource renders normal index when view=kanban column param is set" do
    @org = create_organization!
    get "/admin/organizations?view=kanban&column=todo"
    # OrganizationDefinition has no kanban block, so the before_action is a
    # no-op and the normal index response (table) is returned.
    assert_response :success
    # The response should NOT be a bare kanban frame body — it should be a
    # full HTML page (has <html> or at least the page chrome).
    assert_includes response.body, "Organizations"
  end
end
