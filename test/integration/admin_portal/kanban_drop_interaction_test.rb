# frozen_string_literal: true

require "test_helper"

# Integration tests for the kanban_move member action's drop_interaction path
# (Task 4).
#
# Route:   POST /admin/tasks/:id/kanban_move
# Params:  from_column, to_column, to_index, interaction[...]
# Formats: Turbo Stream (Accept: text/vnd.turbo-stream.html)
#
# When the destination column declares a `drop_interaction:`, the POST commits
# the interaction AND the move in ONE transaction:
#   (1) on_drop membership write + save
#   (2) authorize the transition + build & run the interaction
#   (3) reposition + save
#
# Interaction failure rolls everything back and re-renders the modal at 422.
# Success emits the column Turbo Streams PLUS a stream that closes the modal.
#
# The Task board fixture (TaskDefinition):
#   :lost — drop_interaction: MarkLostInteraction (required :reason input;
#           execute sets status="lost", lost_reason=reason)
#   TaskPolicy#mark_lost? delegates to update? (deny_mark_lost toggle for 403).
class AdminPortal::KanbanDropInteractionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html"
  REMOTE_MODAL_FRAME = Plutonium::REMOTE_MODAL_FRAME

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @doing = Task.create!(title: "Doing One", status: "doing")
    # An existing lost card so the reposition can be observed.
    @lost_a = Task.create!(title: "Lost Alpha", status: "lost")
  end

  teardown { Task.delete_all }

  def kanban_move_url(task)
    "/admin/tasks/#{task.id}/kanban_move"
  end

  # ─── Criterion 1: interaction + move committed atomically ──────────────────

  test "drop onto :lost with a reason commits the interaction AND the move" do
    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "lost", to_index: 0,
               interaction: {reason: "budget cut"}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok

    @doing.reload
    assert_equal "lost", @doing.status, "interaction must transition status to lost"
    assert_equal "budget cut", @doing.lost_reason, "interaction must record the reason"

    # Repositioned at index 0 of the lost column → before the existing lost card.
    assert @doing.position < @lost_a.reload.position,
      "the card must be repositioned into the destination column"
  end

  test "successful drop updates the destination column frame" do
    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "lost", to_index: 0,
               interaction: {reason: "budget cut"}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    assert_includes response.body, 'target="kanban-col-doing"',
      "response must update the source (doing) frame"
    assert_includes response.body, 'target="kanban-col-lost"',
      "response must update the destination (lost) frame"
  end

  # ─── Criterion 2: interaction failure rolls back + re-renders modal ────────

  test "drop onto :lost with a blank reason returns 422 and rolls everything back" do
    original_status = @doing.status
    original_position = @doing.position

    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "lost", to_index: 0,
               interaction: {reason: ""}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content

    @doing.reload
    assert_equal original_status, @doing.status,
      "status must be unchanged when the interaction fails (rollback)"
    assert_nil @doing.lost_reason,
      "lost_reason must be unset when the interaction fails (rollback)"
    assert_equal original_position, @doing.position,
      "position must be unchanged when the interaction fails (rollback)"
  end

  test "blank reason re-renders the modal with the validation error" do
    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "lost", to_index: 0,
               interaction: {reason: ""}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
    assert_includes response.body, "interaction[reason]",
      "the re-rendered modal must contain the reason input"
    assert_match(/can\S*t be blank/i, response.body,
      "the re-rendered modal must show the presence validation error")
  end

  test "blank reason re-render keeps the hidden move context for resubmit" do
    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "lost", to_index: 2,
               interaction: {reason: ""}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
    body = response.body
    assert_match(/<input[^>]*name="from_column"[^>]*value="doing"/, body)
    assert_match(/<input[^>]*name="to_column"[^>]*value="lost"/, body)
    assert_match(/<input[^>]*name="to_index"[^>]*value="2"/, body)
  end

  # ─── Criterion 3: transition authorization ─────────────────────────────────

  test "denied mark_lost? returns 403 and persists nothing" do
    original_status = @doing.status

    TaskPolicy.deny_mark_lost = true
    begin
      post kanban_move_url(@doing),
        params: {from_column: "doing", to_column: "lost", to_index: 0,
                 interaction: {reason: "budget cut"}},
        headers: {"Accept" => TURBO_STREAM_ACCEPT}
      assert_response :forbidden
    ensure
      TaskPolicy.deny_mark_lost = false
    end

    @doing.reload
    assert_equal original_status, @doing.status, "status must not change on 403"
    assert_nil @doing.lost_reason, "lost_reason must not be set on 403"
  end

  # ─── Criterion 4: move-guard rejection precedes the interaction ────────────

  test "a move-guard rejection returns 422 and never runs the interaction" do
    # :done accepts only cards whose status is "doing" — a todo card is
    # rejected BEFORE any transaction/interaction work. (:done has no
    # drop_interaction, but this proves the guard path still short-circuits.)
    todo = Task.create!(title: "Todo One", status: "todo")
    original_status = todo.status

    post kanban_move_url(todo),
      params: {from_column: "todo", to_column: "done", to_index: 0,
               interaction: {reason: "should be ignored"}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :unprocessable_content
    todo.reload
    assert_equal original_status, todo.status, "guard rejection must not mutate the record"
    assert_nil todo.lost_reason, "the interaction must not run on a guard rejection"
  end

  # ─── Criterion 6: success closes the remote modal frame ────────────────────

  test "successful drop appends a stream that closes the remote modal frame" do
    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "lost", to_index: 0,
               interaction: {reason: "budget cut"}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    assert_includes response.body, %(target="#{REMOTE_MODAL_FRAME}"),
      "success via the modal path must emit a stream closing the remote modal frame"
  end

  # ─── Criterion 7: interaction success message surfaced as a toast ──────────

  test "successful drop appends the interaction's success message as a toast" do
    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "lost", to_index: 0,
               interaction: {reason: "budget cut"}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    assert_includes response.body, %(target="kanban-flash"),
      "the interaction's success message must be appended to the flash region"
    assert_includes response.body, "Marked as lost",
      "the toast must carry the interaction's success message"
  end

  # ─── Criterion 8: a column with BOTH on_drop AND drop_interaction ──────────

  test "cross-column drop into a column with on_drop AND drop_interaction persists both in order" do
    # :blocked declares on_drop (status=blocked + lost_reason sentinel) AND
    # BlockTaskInteraction (status=blocked + lost_reason=reason). An existing
    # blocked card lets the reposition be observed.
    blocked_zero = Task.create!(title: "Blocked Zero", status: "blocked")

    post kanban_move_url(@doing),
      params: {from_column: "doing", to_column: "blocked", to_index: 0,
               interaction: {reason: "waiting on vendor"}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok

    @doing.reload
    # on_drop's membership write persisted (status).
    assert_equal "blocked", @doing.status,
      "the on_drop membership write must persist"
    # The interaction's extras persisted, overwriting on_drop's sentinel — which
    # proves on_drop ran FIRST, then the interaction (ordering guarantee).
    assert_equal "waiting on vendor", @doing.lost_reason,
      "the interaction extras must persist and overwrite the on_drop sentinel"
    refute_equal "SET_BY_ON_DROP", @doing.lost_reason,
      "the interaction must run AFTER on_drop (sentinel must be overwritten)"

    # Both set status → final value is the interaction's (== on_drop's here).
    assert_equal "blocked", @doing.status

    # reposition ran last: index 0 places the card before the existing one.
    assert @doing.position < blocked_zero.reload.position,
      "reposition must run after on_drop + interaction"
  end

  # ─── Criterion 9: same-column reorder into a drop_interaction column ────────

  test "same-column reorder into :lost does NOT run the drop_interaction" do
    # An already-lost card with a recorded reason. Reordering WITHIN the lost
    # column must not re-prompt (the interaction represents ENTERING the column,
    # not repositioning inside it).
    @lost_a.update!(lost_reason: "already recorded")
    Task.create!(title: "Lost Beta", status: "lost")

    post kanban_move_url(@lost_a),
      params: {from_column: "lost", to_column: "lost", to_index: 1,
               interaction: {reason: "should be ignored"}},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    assert_response :ok
    refute_includes response.body, %(target="#{REMOTE_MODAL_FRAME}"),
      "a same-column reorder must NOT emit the drop-interaction modal-close stream"
    refute_includes response.body, "Marked as lost",
      "a same-column reorder must NOT run the interaction (no success toast)"

    @lost_a.reload
    assert_equal "already recorded", @lost_a.lost_reason,
      "the interaction did not run, so lost_reason is unchanged"
    assert_equal "lost", @lost_a.status,
      "status is unchanged on a same-column reorder"
  end

  # ─── Criterion 10: same-column reorder skips on_drop (positioning only) ─────

  test "same-column reorder into :blocked does NOT run on_drop (positioning only)" do
    # :blocked declares BOTH an on_drop (status=blocked + lost_reason sentinel)
    # AND a drop_interaction. A same-column reorder must run ONLY the positioning
    # code — neither on_drop nor the interaction fires, since both represent
    # ENTERING the column, not repositioning inside it.
    blocked_card = Task.create!(title: "Blocked One", status: "blocked")
    # Set a DISTINCT reason directly so it differs from the on_drop sentinel; if
    # on_drop ran it would clobber this with "SET_BY_ON_DROP".
    blocked_card.update!(lost_reason: "original reason")
    # A second blocked card so there is something to reorder relative to.
    blocked_two = Task.create!(title: "Blocked Two", status: "blocked")

    original_position = blocked_card.position

    # SAME column, no interaction params: a plain reposition to index 1 (after
    # the second card).
    post kanban_move_url(blocked_card),
      params: {from_column: "blocked", to_column: "blocked", to_index: 1},
      headers: {"Accept" => TURBO_STREAM_ACCEPT}

    # A plain reposition succeeds (not a 422/modal).
    assert_response :ok

    blocked_card.reload
    # on_drop was skipped: it never overwrote lost_reason with the sentinel.
    assert_equal "original reason", blocked_card.lost_reason,
      "on_drop must NOT run on a same-column reorder (sentinel must not overwrite)"
    refute_equal "SET_BY_ON_DROP", blocked_card.lost_reason,
      "the on_drop sentinel proves on_drop was skipped"
    assert_equal "blocked", blocked_card.status,
      "status is unchanged on a same-column reorder"

    # Reposition still ran: the card moved after the second blocked card.
    refute_equal original_position, blocked_card.position,
      "the reposition must still run on a same-column reorder"
    assert blocked_card.position > blocked_two.reload.position,
      "index 1 must place the card after the second blocked card"

    # The interaction was skipped too: no modal-close stream, no success toast.
    refute_includes response.body, %(target="#{REMOTE_MODAL_FRAME}"),
      "a same-column reorder must NOT emit the drop-interaction modal-close stream"
    refute_includes response.body, "Task blocked",
      "a same-column reorder must NOT run the interaction (no success toast)"
  end
end
