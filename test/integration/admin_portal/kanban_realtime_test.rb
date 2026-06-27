# frozen_string_literal: true

require "test_helper"
require "turbo/broadcastable/test_helper"

# Integration tests for Task 14: opt-in realtime kanban broadcaster.
#
# The Task board fixture is NOT realtime (realtime defaults to false).
# Tests that need a realtime board temporarily swap TaskDefinition.defined_kanban_board
# (a class_attribute setter) for the duration of the test and restore it in an
# ensure block. The shared fixture is unchanged so all other kanban tests are
# unaffected.
#
# The admin portal is not entity-scoped → scoped_entity is nil → the
# stream-name tenant segment is "global".
#
# Covered:
#   Non-realtime board:
#     * move does NOT broadcast to the kanban stream
#     * board shell does NOT contain <turbo-cable-stream-source>
#
#   Realtime board (temp swap):
#     * successful move broadcasts to the correctly-scoped stream
#     * board shell contains <turbo-cable-stream-source>
#     * rejected move does NOT broadcast
class AdminPortal::KanbanRealtimeTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Turbo::Broadcastable::TestHelper

  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html"

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @todo_a = Task.create!(title: "Todo Alpha", status: "todo")
    @doing_a = Task.create!(title: "Doing One", status: "doing")
  end

  teardown { Task.delete_all }

  # ─── Non-realtime board: no broadcasts ─────────────────────────────────────

  test "non-realtime board move does not broadcast" do
    stream = board_stream_name
    assert_no_turbo_stream_broadcasts(stream) do
      post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
        headers: {"Accept" => TURBO_STREAM_ACCEPT}
      assert_response :ok
    end
  end

  test "non-realtime board shell does not include turbo-cable-stream-source" do
    get "/admin/tasks?view=kanban"
    assert_response :ok
    refute_includes response.body, "turbo-cable-stream-source"
  end

  # ─── Realtime board: broadcasts on successful move ─────────────────────────

  test "realtime board move broadcasts to the correct kanban stream" do
    with_realtime_board do
      assert_turbo_stream_broadcasts(board_stream_name) do
        post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
          headers: {"Accept" => TURBO_STREAM_ACCEPT}
        assert_response :ok
      end
    end
  end

  test "realtime board move broadcasts both column frames on cross-column move" do
    with_realtime_board do
      captured = capture_turbo_stream_broadcasts(board_stream_name) do
        post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "doing", to_index: 0},
          headers: {"Accept" => TURBO_STREAM_ACCEPT}
        assert_response :ok
      end

      assert captured.any?, "expected at least one broadcast element"
      targets = captured.map { |node| node["target"] }.compact
      assert_includes targets, "kanban-col-todo", "todo frame must be in the broadcast"
      assert_includes targets, "kanban-col-doing", "doing frame must be in the broadcast"
    end
  end

  test "realtime board same-column reorder broadcasts only one column frame" do
    @todo_b = Task.create!(title: "Todo Beta", status: "todo")

    with_realtime_board do
      captured = capture_turbo_stream_broadcasts(board_stream_name) do
        post kanban_move_url(@todo_b), params: {from_column: "todo", to_column: "todo", to_index: 0},
          headers: {"Accept" => TURBO_STREAM_ACCEPT}
        assert_response :ok
      end

      targets = captured.map { |node| node["target"] }.compact
      assert_equal 1, targets.size, "same-column reorder must broadcast exactly one frame"
      assert_equal "kanban-col-todo", targets.first
    end
  end

  test "realtime board rejected move does not broadcast" do
    # :done column only accepts from :doing — a todo→done drop is always rejected.
    with_realtime_board do
      assert_no_turbo_stream_broadcasts(board_stream_name) do
        post kanban_move_url(@todo_a), params: {from_column: "todo", to_column: "done", to_index: 0},
          headers: {"Accept" => TURBO_STREAM_ACCEPT}
        assert_response :unprocessable_content
      end
    end
  end

  # ─── Realtime board shell: subscription element present ────────────────────

  test "realtime board shell includes turbo-cable-stream-source element" do
    with_realtime_board do
      get "/admin/tasks?view=kanban"
      assert_response :ok
      assert_includes response.body, "turbo-cable-stream-source",
        "realtime board shell must include a turbo-cable-stream-source subscription element"
    end
  end

  private

  def kanban_move_url(task)
    "/admin/tasks/#{task.id}/kanban_move"
  end

  # The stream name array for the Task board in the admin portal (no tenant → global).
  def board_stream_name
    Plutonium::Kanban::Broadcaster.stream_name(resource_class: Task, scoped_entity: nil)
  end

  # Builds a minimal realtime version of the Task board.
  # Columns mirror the Task fixture so on_drop / accepts constraints work.
  def build_realtime_task_board
    Plutonium::Kanban::DSL.build do
      realtime true
      per_column 25

      column :todo,
        scope: -> { where(status: "todo") },
        on_drop: ->(r) { r.update!(status: "todo") },
        role: :backlog

      column :doing,
        scope: -> { where(status: "doing") },
        on_drop: ->(r) { r.update!(status: "doing") },
        wip: 3

      column :done,
        scope: -> { where(status: "done") },
        on_drop: ->(r) { r.update!(status: "done") },
        accepts: [:doing],
        role: :done
    end
  end

  # Temporarily replaces TaskDefinition's compiled board with a realtime one
  # for the duration of the block. Restores the original on exit (even on raise).
  def with_realtime_board
    original_board = TaskDefinition.defined_kanban_board
    TaskDefinition.defined_kanban_board = build_realtime_task_board
    yield
  ensure
    TaskDefinition.defined_kanban_board = original_board
  end
end
