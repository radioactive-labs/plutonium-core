# frozen_string_literal: true

require "test_helper"

# Smoke test for the Task kanban board fixture.
#
# This test verifies what is buildable NOW (DSL compilation + positioning),
# without any HTTP/controller/UI (those land in later tasks).
class AdminPortal::KanbanSmokeTest < ActiveSupport::TestCase
  teardown { Task.delete_all }

  # ─── Definition: :kanban view is registered ────────────────────────────────

  test "TaskDefinition registers the :kanban index view" do
    assert_includes TaskDefinition.defined_index_views, :kanban
  end

  test "TaskDefinition stores a kanban block" do
    assert_not_nil TaskDefinition.defined_kanban_block
    assert TaskDefinition.defined_kanban_block.respond_to?(:call)
  end

  # ─── Board compilation ─────────────────────────────────────────────────────

  def board
    @board ||= Plutonium::Kanban::DSL.build(&TaskDefinition.defined_kanban_block)
  end

  test "kanban DSL compiles to a Board" do
    assert_instance_of Plutonium::Kanban::Board, board
  end

  test "board has exactly 3 columns" do
    assert_equal 3, board.columns.length
  end

  test "board column keys are :todo, :doing, :done" do
    assert_equal %i[todo doing done], board.columns.map(&:key)
  end

  test "board per_column is 25" do
    assert_equal 25, board.per_column
  end

  # ─── Column: :todo (role: :backlog) ────────────────────────────────────────

  def todo_col
    board.columns.find { |c| c.key == :todo }
  end

  test ":todo column exists" do
    assert_not_nil todo_col
  end

  test ":todo column has add? true from backlog role" do
    assert todo_col.add?, ":todo should have add:true from role: :backlog"
  end

  test ":todo column has a scope proc" do
    assert todo_col.scope.respond_to?(:call)
  end

  test ":todo column has an on_drop proc" do
    assert todo_col.on_drop.respond_to?(:call)
  end

  # ─── Column: :doing (wip: 3) ───────────────────────────────────────────────

  def doing_col
    board.columns.find { |c| c.key == :doing }
  end

  test ":doing column exists" do
    assert_not_nil doing_col
  end

  test ":doing column wip is 3" do
    assert_equal 3, doing_col.wip
  end

  # ─── Column: :done (role: :done + action) ──────────────────────────────────

  def done_col
    board.columns.find { |c| c.key == :done }
  end

  test ":done column exists" do
    assert_not_nil done_col
  end

  test ":done column collapsed from done role" do
    assert done_col.collapsed?, ":done should be collapsed from role: :done"
  end

  test ":done column has green color from done role" do
    assert_equal :green, done_col.color
  end

  test ":done column has archive_all action" do
    action = done_col.actions.find { |a| a.key == :archive_all }
    assert_not_nil action, ":done column should have an :archive_all action"
    assert_equal ArchiveTasksInteraction, action.interaction
    assert_equal :all, action.on
    assert_equal "Archive all", action.label
  end

  # ─── Positioning ───────────────────────────────────────────────────────────

  test "Task model includes Plutonium::Positioning" do
    assert Task.include?(Plutonium::Positioning)
  end

  test "positioning_column is :position" do
    assert_equal :position, Task.positioning_column
  end

  test "positioning_scope_attr is :status" do
    assert_equal :status, Task.positioning_scope_attr
  end

  test "first task in a status gets position 1.0" do
    task = Task.create!(title: "First", status: "todo")
    assert_equal 1.0, task.position.to_f
  end

  test "second task in same status gets a higher position" do
    t1 = Task.create!(title: "First", status: "todo")
    t2 = Task.create!(title: "Second", status: "todo")
    assert t2.position > t1.position,
      "second task position (#{t2.position}) should be greater than first (#{t1.position})"
  end

  test "tasks in different status groups have independent positions" do
    todo = Task.create!(title: "Todo task", status: "todo")
    done = Task.create!(title: "Done task", status: "done")
    # Both should start at 1.0 since they're in separate scope groups
    assert_equal 1.0, todo.position.to_f
    assert_equal 1.0, done.position.to_f
  end
end
