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
end
