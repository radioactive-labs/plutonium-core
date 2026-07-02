# frozen_string_literal: true

require "application_system_test_case"

# Browser-level (Task 8) validation of the kanban drop-interaction flow — the
# CLIENT layer the server integration tests (kanban_drop_interaction_test.rb)
# and the DOM-contract test (kanban_dom_contract_test.rb) can't reach.
#
# The TaskDefinition board declares a :lost column with
# `drop_interaction: MarkLostInteraction` (a required :reason input). Dropping a
# card from another column into :lost must open the interaction's modal, and
# submitting it must commit the interaction + the move atomically and close the
# modal.
#
# ## How the drop is driven
#
# Native HTML5 drag-and-drop is unreliable to simulate through Selenium's
# synthetic pointer, so instead of faking a pointer drag we dispatch the exact
# DOM events the REAL kanban Stimulus controller listens for — `dragstart` on
# the card and `drop` on the destination column's drop zone, each carrying a
# real DataTransfer. Everything downstream is the genuine client code path:
# kanban_controller.js#onDrop reads the dragged card + destination wrapper,
# sees data-kanban-drop-interaction="true", and points the #remote_modal frame
# at the kanban_move_form URL. The modal, its form, the submit POST, the
# Turbo-Stream commit response, and the modal close are all real. Only the
# pointer gesture itself is synthesised.
class AdminPortal::KanbanDropInteractionTest < ApplicationSystemTestCase
  setup do
    @admin = create_admin!
    # A card sitting in the :doing column — the source of every drop below.
    @doing = Task.create!(title: "Ship the thing", status: "doing")
  end

  teardown { Task.delete_all }

  # ─── Scenario 1: drop → modal → submit with reason → atomic commit ─────────

  test "dropping onto :lost opens the modal; submitting with a reason commits and closes it" do
    open_task_board

    drop_card_into_column(@doing.id, "lost")

    # The interaction modal opens with its reason field.
    assert_selector "dialog[open]", wait: 5
    assert_field "interaction[reason]", wait: 5

    fill_in "interaction[reason]", with: "budget cut"
    click_button "Mark Lost"

    # The card now renders in the :lost column (the Turbo-Stream commit response
    # re-rendered both column frames). Its appearance there means the server
    # transaction committed, so the DB row is safe to assert.
    assert_selector "[data-kanban-col='lost'] [data-kanban-record-id='#{@doing.id}']", wait: 5
    assert_no_selector "[data-kanban-col='doing'] [data-kanban-record-id='#{@doing.id}']"

    # The modal closed (remote_modal frame emptied by the success stream).
    assert_no_selector "dialog[open]"

    # The interaction's success message surfaced as a toast.
    assert_text "Marked as lost"

    @doing.reload
    assert_equal "lost", @doing.status, "the interaction must transition status to lost"
    assert_equal "budget cut", @doing.lost_reason, "the interaction must record the reason"
  end

  # ─── Scenario 2: blank reason → error, modal stays, no move ────────────────
  #
  # Two layers of "blank reason is rejected" are validated in a real browser:
  #   (a) the reason input is `required`, so the browser's native HTML5
  #       validation blocks the blank submit before it ever reaches the server;
  #   (b) with that native guard bypassed (a determined client), the SERVER
  #       rejects the blank value with a 422 and re-renders the modal in place
  #       with the AR presence error — the snap-back-with-error path the
  #       integration test exercises server-side.
  test "a blank reason is rejected (native + server) and never moves the card" do
    open_task_board

    drop_card_into_column(@doing.id, "lost")

    assert_selector "dialog[open]", wait: 5
    assert_field "interaction[reason]", wait: 5

    # (a) Native guard: the blank field is invalid, so clicking submit is a
    # no-op — the browser refuses to submit and shows its own validation bubble.
    invalid = page.evaluate_script(
      "document.querySelector(\"[name='interaction[reason]']\").checkValidity() === false"
    )
    assert invalid, "the reason input must be `required` so the browser blocks a blank submit"

    click_button "Mark Lost"

    # Nothing moved and the modal is still open (native validation stopped it).
    assert_selector "dialog[open]"
    assert_selector "[data-kanban-col='doing'] [data-kanban-record-id='#{@doing.id}']"
    @doing.reload
    assert_equal "doing", @doing.status, "the native guard must block the blank submit"

    # (b) Force the blank value past the native guard so the SERVER path runs:
    # drop the `required` attribute + set the form to skip native validation.
    page.execute_script(<<~JS)
      const input = document.querySelector("[name='interaction[reason]']");
      input.removeAttribute("required");
      input.form.noValidate = true;
    JS

    click_button "Mark Lost"

    # The server returns 422 and re-renders the modal in place with the AR
    # presence error; the modal stays open.
    assert_text(/can\S*t be blank/i, wait: 5)
    assert_selector "dialog[open]"
    assert_field "interaction[reason]"

    # The card still has NOT moved — still in :doing, absent from :lost.
    assert_selector "[data-kanban-col='doing'] [data-kanban-record-id='#{@doing.id}']"
    assert_no_selector "[data-kanban-col='lost'] [data-kanban-record-id='#{@doing.id}']"

    @doing.reload
    assert_equal "doing", @doing.status, "status must be unchanged when the interaction fails"
    assert_nil @doing.lost_reason, "lost_reason must be unset when the interaction fails"
  end

  # ─── Scenario 3: cancel → modal closes, card stays put ─────────────────────

  test "dismissing the modal closes it and leaves the card in its source column" do
    open_task_board

    drop_card_into_column(@doing.id, "lost")

    assert_selector "dialog[open]", wait: 5
    assert_field "interaction[reason]", wait: 5

    # Dismiss via the modal's close control (data-action="remote-modal#close").
    find("dialog[open] [aria-label='Close dialog']").click

    # Modal closes; native HTML5 DnD never re-parented the card, so it is still
    # in :doing with nothing to snap back.
    assert_no_selector "dialog[open]", wait: 5
    assert_selector "[data-kanban-col='doing'] [data-kanban-record-id='#{@doing.id}']"
    assert_no_selector "[data-kanban-col='lost'] [data-kanban-record-id='#{@doing.id}']"

    @doing.reload
    assert_equal "doing", @doing.status, "the card must not move when the modal is dismissed"
    assert_nil @doing.lost_reason, "nothing must persist when the modal is dismissed"
  end

  private

  # Log into the admin portal and land on the Task kanban board, waiting until
  # the lazy column frames have loaded (the source card + the :lost drop zone
  # are both present).
  def open_task_board
    visit "/admin/tasks?view=kanban"
    fill_in "login", with: @admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"

    # Board rendered and lazy frames loaded.
    assert_selector "[data-controller~='kanban']", wait: 5
    assert_selector "[data-kanban-record-id='#{@doing.id}']", wait: 5
    assert_selector "[data-kanban-target='column'][data-kanban-column-key-value='lost']", wait: 5
  end

  # Drive the real kanban controller's drop path: dispatch a native dragstart on
  # the card and a native drop on the destination column's drop zone, each with
  # a real DataTransfer. The controller does the rest (opening the interaction
  # modal for drop_interaction columns). Only the pointer gesture is synthesised.
  def drop_card_into_column(card_id, to_column)
    dispatched = page.evaluate_script(<<~JS)
      (() => {
        const card = document.querySelector("[data-kanban-record-id='#{card_id}']");
        const zone = document.querySelector(
          "[data-kanban-target='column'][data-kanban-column-key-value='#{to_column}']"
        );
        if (!card || !zone) return false;

        const dt = new DataTransfer();
        card.dispatchEvent(new DragEvent("dragstart",
          { bubbles: true, cancelable: true, dataTransfer: dt }));

        const rect = zone.getBoundingClientRect();
        zone.dispatchEvent(new DragEvent("drop",
          { bubbles: true, cancelable: true, dataTransfer: dt,
            clientX: rect.left + 5, clientY: rect.top + 5 }));

        card.dispatchEvent(new DragEvent("dragend",
          { bubbles: true, cancelable: true, dataTransfer: dt }));
        return true;
      })()
    JS

    assert dispatched,
      "drag simulation could not find card ##{card_id} or the '#{to_column}' drop zone"
  end
end
