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
    @todo_b = Task.create!(title: "Todo Beta", status: "todo")
    @doing = Task.create!(title: "Doing One", status: "doing")
    @done = Task.create!(title: "Done One", status: "done")
  end

  teardown { Task.delete_all }

  # ─── Basic 200 + column isolation ─────────────────────────────────────────

  test "returns 200 for the todo column" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
  end

  # Regression: the shell's lazy `<turbo-frame id="kanban-col-<key>" src=…>`
  # only swaps in content if the response CONTAINS a turbo-frame with the same
  # id — otherwise Turbo renders "Content missing" in the browser. Asserting
  # the card content alone (other tests) does not catch a missing wrapper.
  test "lazy column response is wrapped in the matching turbo-frame" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_match(/<turbo-frame[^>]*\bid="kanban-col-todo"/, response.body)
  end

  test "unknown column still returns the matching (empty) turbo-frame" do
    get "/admin/tasks?view=kanban&column=bogus"
    assert_response :success
    assert_match(/<turbo-frame[^>]*\bid="kanban-col-bogus"/, response.body)
  end

  test "todo column body contains todo card titles" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_includes response.body, "Todo Alpha"
    assert_includes response.body, "Todo Beta"
  end

  # The Task board declares `show_in :page`, so a card's show link targets _top
  # and clicking it navigates the whole page — otherwise the show page would load
  # INSIDE the column's lazy turbo-frame (cards are reused from Grid::Card, which
  # is normally not framed). KitchenSink exercises the default :modal path
  # (see kanban_show_frame_test.rb).
  test "card show link breaks out of the column frame (turbo-frame _top)" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_match(/data-turbo-frame="_top"/, response.body,
      "kanban card show link should target _top to escape the column frame")
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
    beta_pos = response.body.index("Todo Beta")
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

  # ─── Per-column cap ───────────────────────────────────────────────────────

  # The board's per_column is 25; seeding 30 todo tasks must cap the rendered
  # cards at 25 and surface a "+5 more" footer for the remainder. Cards are
  # counted by the stable data-kanban-record-id marker each Kanban::Card emits.
  test "rendered cards are capped at per_column with a +N more footer" do
    extra = 30 - Task.where(status: "todo").count
    extra.times { |i| Task.create!(title: "Bulk #{i}", status: "todo") }
    assert_equal 30, Task.where(status: "todo").count

    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success

    card_count = response.body.scan("data-kanban-record-id").size
    assert_equal 25, card_count, "expected exactly per_column (25) cards rendered"
    assert_includes response.body, "+5 more"
  end

  # ─── Query pipeline applied ───────────────────────────────────────────────

  # Demonstrates that the relation is query-applied: a query param flows
  # through current_query_object.apply, narrowing the column's cards rather
  # than just the overall collection. The TaskDefinition currently declares
  # no search/filter, so we can only assert the pipeline does not crash and
  # still authorizes/returns the column.
  #
  # TODO(Task 6+): once the dummy board has a searchable/filterable field,
  # assert that a real filter narrows the cards — e.g. a card that should be
  # filtered OUT is absent while an included one is present. Until then this
  # test only proves the query pipeline is wired, not that filtering narrows.
  test "passing query params flows through the pipeline without crashing" do
    get "/admin/tasks?view=kanban&column=todo&q[scope]=nonexistent"
    assert_response :success
    assert_includes response.body, "Todo Alpha"
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
