# frozen_string_literal: true

require "test_helper"

# Integration tests for the kanban_move member action (Task 7).
#
# Route:   POST /admin/tasks/:id/kanban_move
# Params:  from_column, to_column, to_index
# Formats: Turbo Stream (Accept: text/vnd.turbo-stream.html)
#
# The Task board fixture (TaskDefinition):
#   :todo   — Proc on_drop, accepts all, backlog role
#   :doing  — Proc on_drop, wip: 3, accepts all
#   :done   — Symbol on_drop (:mark_done!), accepts: [:doing] only
#
# Covered scenarios:
#   * todo → doing success (Proc on_drop, status + position updated)
#   * doing → done success (Symbol on_drop, status + position updated)
#   * response contains turbo-stream updates for both column frames
#   * same-column reorder: only one frame updated
#   * unauthenticated: redirect (auth layer enforced)
#   * denied kanban_move?: 403, no DB change
#   * accepts: restriction (todo → done rejected): 422, no DB change
#   * wip exceeded (4th card into doing): 422, no DB change
class AdminPortal::KanbanMoveTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html"

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    # Seed tasks. Positioning is scoped by :status so each column is
    # independent (positions 1.0, 2.0, … within each status group).
    @todo_a = Task.create!(title: "Todo Alpha", status: "todo")
    @todo_b = Task.create!(title: "Todo Beta",  status: "todo")
    @doing_a = Task.create!(title: "Doing One",  status: "doing")
    @done_a  = Task.create!(title: "Done One",   status: "done")
  end

  teardown { Task.delete_all }

  # ─── Success: Proc on_drop (todo → doing) ──────────────────────────────────

  test "move todo to doing returns 200 and updates status + position" do
    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    @todo_a.reload
    assert_equal "doing", @todo_a.status
    # Task moved to index 0 in doing → position < @doing_a.position
    assert @todo_a.position < @doing_a.reload.position,
      "moved card should have a lower position than the existing doing card"
  end

  test "move todo to doing response is turbo-stream content type" do
    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    assert_includes response.content_type, "turbo-stream"
  end

  # ─── Success: Symbol on_drop (doing → done) ────────────────────────────────

  test "move doing to done returns 200 and updates status via symbol on_drop" do
    post kanban_move_url(@doing_a), params: {from_column: "doing", to_column: "done", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    @doing_a.reload
    assert_equal "done", @doing_a.status
  end

  test "symbol on_drop updates position correctly" do
    post kanban_move_url(@doing_a), params: {from_column: "doing", to_column: "done", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    @doing_a.reload
    assert @doing_a.position < @done_a.reload.position,
      "moved card at index 0 should be positioned before the existing done card"
  end

  # ─── Response: both frames updated on cross-column move ────────────────────

  test "cross-column move response replaces from and to column frames" do
    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    assert_includes response.body, 'target="kanban-col-todo"',
      "response must update the source (todo) frame"
    assert_includes response.body, 'target="kanban-col-doing"',
      "response must update the destination (doing) frame"
  end

  test "cross-column move response does not include the moved card in the source frame" do
    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    # Response contains two turbo-stream blocks; the todo block should NOT
    # contain Todo Alpha (it moved away) but should still contain Todo Beta.
    # We assert the moved card title is no longer in the todo frame HTML while
    # Todo Beta still is. (The title appears in both blocks; use position of
    # the todo block before the doing block to disambiguate.)
    todo_frame_start = response.body.index('target="kanban-col-todo"')
    doing_frame_start = response.body.index('target="kanban-col-doing"')
    assert todo_frame_start && doing_frame_start

    todo_segment = response.body[todo_frame_start...doing_frame_start]
    assert_includes todo_segment, "Todo Beta",  "Todo Beta must still be in the todo frame"
    refute_includes todo_segment, "Todo Alpha", "Todo Alpha must have left the todo frame"
  end

  # ─── Same-column reorder: only one frame updated ───────────────────────────

  test "same-column reorder returns 200 and updates only one frame" do
    @todo_b_pos = @todo_b.position

    post kanban_move_url(@todo_b), params: {from_column: "todo", to_column: "todo", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    @todo_b.reload
    # Moved to index 0, should now have position lower than @todo_a
    assert @todo_b.position < @todo_a.reload.position

    # Only one turbo-stream update (no duplicate frame for same column)
    todo_frame_count = response.body.scan('target="kanban-col-todo"').size
    assert_equal 1, todo_frame_count, "same-column reorder should emit exactly one frame update"
  end

  # ─── Authentication / authorization ────────────────────────────────────────

  test "unauthenticated request is redirected" do
    logout_admin
    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}
    assert_response :redirect
  end

  test "denied kanban_move? returns 403 and makes no DB change" do
    original_status = @todo_a.status
    original_position = @todo_a.position

    TaskPolicy.deny_kanban_move = true
    begin
      post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
        headers: {"Accept" => TURBO_STREAM_ACCEPT}
      assert_response :forbidden
    ensure
      TaskPolicy.deny_kanban_move = false
    end

    @todo_a.reload
    assert_equal original_status,   @todo_a.status,   "status must not change on 403"
    assert_equal original_position, @todo_a.position, "position must not change on 403"
  end

  # ─── Accepts restriction (todo → done rejected) ────────────────────────────

  test "drop rejected by accepts returns 422" do
    # :done column declares accepts: [:doing], so a todo card cannot go directly
    # to done.
    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "done", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
  end

  test "drop rejected by accepts makes no DB change" do
    original_status   = @todo_a.status
    original_position = @todo_a.position

    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "done", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    @todo_a.reload
    assert_equal original_status,   @todo_a.status
    assert_equal original_position, @todo_a.position
  end

  test "drop rejected by accepts re-renders the source column frame for snap-back" do
    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "done", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
    assert_includes response.body, 'target="kanban-col-todo"',
      "422 response must update the source frame so the card snaps back"
  end

  # ─── WIP limit exceeded ────────────────────────────────────────────────────

  test "move to wip-full column returns 422" do
    # doing has wip: 3; fill it to the limit (one card already seeded).
    @doing_b = Task.create!(title: "Doing Two",   status: "doing")
    @doing_c = Task.create!(title: "Doing Three", status: "doing")
    # doing now has 3 cards = at WIP limit. Moving a 4th in must be rejected.
    assert_equal 3, Task.where(status: "doing").count

    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
  end

  test "move to wip-full column makes no DB change" do
    @doing_b = Task.create!(title: "Doing Two",   status: "doing")
    @doing_c = Task.create!(title: "Doing Three", status: "doing")

    original_status   = @todo_a.status
    original_position = @todo_a.position

    post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    @todo_a.reload
    assert_equal original_status,   @todo_a.status
    assert_equal original_position, @todo_a.position
  end

  test "same-column reorder when at wip limit is not rejected" do
    # Fill doing to exactly wip (3 cards). A within-column reorder should pass
    # because it does not change the column cardinality.
    @doing_b = Task.create!(title: "Doing Two",   status: "doing")
    @doing_c = Task.create!(title: "Doing Three", status: "doing")
    assert_equal 3, Task.where(status: "doing").count

    post kanban_move_url(@doing_a), params: {from_column: "doing", to_column: "doing", to_index: 2},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
  end

  private

  def kanban_move_url(task)
    "/admin/tasks/#{task.id}/kanban_move"
  end
end
