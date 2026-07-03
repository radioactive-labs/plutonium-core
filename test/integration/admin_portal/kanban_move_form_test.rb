# frozen_string_literal: true

require "test_helper"

# Integration tests for the kanban_move_form member action (Task 3).
#
# Route:  GET /admin/tasks/:id/kanban_move_form?from_column=&to_column=&to_index=
#
# When a card is dropped into a column that declares a `enter_interaction:`, the
# client opens this modal. It renders the drop interaction's normal form, but
# the form POSTs to the `kanban_move` route carrying the move context
# (from_column/to_column/to_index) as hidden fields alongside the interaction's
# own inputs.
#
# The Task board fixture (TaskDefinition) declares:
#   column :lost, enter_interaction: MarkLostInteraction
# and MarkLostInteraction exposes a required :reason input.
class AdminPortal::KanbanMoveFormTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @task = Task.create!(title: "Doing One", status: "doing")
  end

  teardown { Task.delete_all }

  def kanban_move_form_url(task, **query)
    "/admin/tasks/#{task.id}/kanban_move_form?#{query.to_query}"
  end

  # ─── Criterion 1: renders the interaction's inputs ─────────────────────────

  test "renders the drop interaction's form fields (reason input)" do
    get kanban_move_form_url(@task, from_column: "doing", to_column: "lost", to_index: 0)

    assert_response :ok
    assert_includes response.body, "interaction[reason]",
      "the modal must render the drop interaction's reason input"
  end

  # ─── Criterion 2: form targets kanban_move + hidden move context ───────────

  test "form targets the kanban_move path" do
    get kanban_move_form_url(@task, from_column: "doing", to_column: "lost", to_index: 0)

    assert_response :ok
    assert_includes response.body, "/admin/tasks/#{@task.id}/kanban_move\"",
      "the form must POST to the kanban_move member route"
  end

  test "form carries from_column, to_column and to_index as hidden fields" do
    get kanban_move_form_url(@task, from_column: "doing", to_column: "lost", to_index: 2)

    assert_response :ok
    body = response.body
    assert_match(/<input[^>]*name="from_column"[^>]*value="doing"/, body,
      "from_column hidden field must carry the query value")
    assert_match(/<input[^>]*name="to_column"[^>]*value="lost"/, body,
      "to_column hidden field must carry the query value")
    assert_match(/<input[^>]*name="to_index"[^>]*value="2"/, body,
      "to_index hidden field must carry the query value")
  end

  # ─── Criterion 3: non-drop column → 422 ────────────────────────────────────

  test "to_column without a enter_interaction returns 422" do
    get kanban_move_form_url(@task, from_column: "todo", to_column: "doing", to_index: 0)

    assert_response :unprocessable_content
  end

  test "unknown to_column returns 422" do
    get kanban_move_form_url(@task, from_column: "todo", to_column: "nope", to_index: 0)

    assert_response :unprocessable_content
  end

  # ─── Criterion 4: policy denial → 403 ──────────────────────────────────────

  test "kanban_move? denying entry to :lost returns 403" do
    TaskPolicy.deny_enter_column = :lost
    begin
      get kanban_move_form_url(@task, from_column: "doing", to_column: "lost", to_index: 0)
      assert_response :forbidden
    ensure
      TaskPolicy.deny_enter_column = nil
    end
  end

  # ─── Authentication ────────────────────────────────────────────────────────

  test "unauthenticated request is redirected" do
    logout_admin
    get kanban_move_form_url(@task, from_column: "doing", to_column: "lost", to_index: 0)
    assert_response :redirect
  end
end
