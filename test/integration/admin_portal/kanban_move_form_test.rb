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

  # ─── Criterion 4: policy denial → 403 turbo-stream rejection ───────────────
  #
  # The client opens this modal via `frame.src`, so a denial must come back as a
  # turbo-stream rejection (empties the modal frame + snaps the source column +
  # toasts) — NOT the global rescue_from's HTML 403 error page, which would land
  # in the remote-modal frame as a broken "content missing" modal. Asserting only
  # the 403 status is vacuous: the HTML error page is also a 403.
  test "kanban_move? denying entry to :lost returns a 403 turbo-stream rejection" do
    TaskPolicy.deny_enter_column = :lost
    begin
      get kanban_move_form_url(@task, from_column: "doing", to_column: "lost", to_index: 0),
        headers: {"Turbo-Frame" => Plutonium::REMOTE_MODAL_FRAME}
      assert_response :forbidden

      assert_equal "text/vnd.turbo-stream.html", response.media_type,
        "a denial must be a turbo-stream, not an HTML error page morphed into the modal frame"
      refute_includes response.body, "Exception caught",
        "must not leak the framework error page"
      assert_includes response.body, 'target="kanban-col-doing"',
        "must re-assert (snap back) the claimed source column"
      assert_includes response.body, %(target="#{Plutonium::REMOTE_MODAL_FRAME}"),
        "must empty the remote-modal frame so no broken modal is left open"
      assert_includes response.body, "not authorized",
        "must surface a rejection toast"
    ensure
      TaskPolicy.deny_enter_column = nil
    end
  end

  # ─── Criterion 5: structural gate mirrors kanban_move (belt & suspenders) ──
  #
  # kanban_move_form must NOT open a modal for a drop the commit (kanban_move POST)
  # would inevitably reject — otherwise the user fills the interaction form only to
  # eat a 422 snap-back on submit. It applies the SAME structural gate as the POST
  # (membership → accepts?/locked?) and, on failure, renders the SAME turbo-stream
  # rejection (Turbo processes it from the frame.src navigation) instead of the
  # doomed form. Asserting a turbo-stream (not the modal form) is the crux — the
  # modal's signature is its reason input (interaction[reason]).

  test "spoofed/stale source column is rejected before the modal opens" do
    # @task really sits in :doing; claim it started in :todo. The membership check
    # fails, so the modal must never open.
    get kanban_move_form_url(@task, from_column: "todo", to_column: "lost", to_index: 0),
      headers: {"Turbo-Frame" => Plutonium::REMOTE_MODAL_FRAME}

    assert_response :unprocessable_content
    assert_equal "text/vnd.turbo-stream.html", response.media_type,
      "a stale/spoofed source must snap back as a stream, not open the modal"
    assert_includes response.body, 'target="kanban-col-todo"', "must snap the claimed source back"
    assert_includes response.body, %(target="#{Plutonium::REMOTE_MODAL_FRAME}"), "must empty the modal frame"
    refute_includes response.body, "interaction[reason]", "the doomed modal form must NOT be rendered"
  end

  test "a source the destination does not accept is rejected before the modal opens" do
    # :review declares accepts: [:doing] + enter_interaction. A card that really
    # sits in :todo (membership passes) dropped into :review must be rejected by
    # the accepts gate BEFORE the modal opens — mirroring the POST's accepts gate.
    todo = Task.create!(title: "Todo One", status: "todo")

    get kanban_move_form_url(todo, from_column: "todo", to_column: "review", to_index: 0),
      headers: {"Turbo-Frame" => Plutonium::REMOTE_MODAL_FRAME}

    assert_response :unprocessable_content
    assert_equal "text/vnd.turbo-stream.html", response.media_type,
      "an unaccepted source must snap back as a stream, not open the modal"
    assert_includes response.body, 'target="kanban-col-todo"', "must snap the source back"
    refute_includes response.body, "interaction[reason]", "the doomed modal form must NOT be rendered"
  end

  test "an accepted source into the same accepts-restricted column DOES open the modal" do
    # Positive control: :review accepts [:doing], so a card really in :doing opens
    # the modal normally — proving the gate rejects only genuinely-invalid drops.
    doing = Task.create!(title: "Doing Two", status: "doing")

    get kanban_move_form_url(doing, from_column: "doing", to_column: "review", to_index: 0)

    assert_response :ok
    assert_includes response.body, "interaction[reason]",
      "an accepted drop must open the interaction modal"
  end

  # ─── Authentication ────────────────────────────────────────────────────────

  test "unauthenticated request is redirected" do
    logout_admin
    get kanban_move_form_url(@task, from_column: "doing", to_column: "lost", to_index: 0)
    assert_response :redirect
  end
end
