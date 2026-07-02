# frozen_string_literal: true

require "test_helper"

# Integration tests for the server↔JS DOM contract that the kanban Stimulus
# controller (Task 11) depends on.
#
# System tests (Capybara + Chrome) would be the preferred verification path,
# but this suite relies only on ActionDispatch::IntegrationTest so it runs
# reliably in CI without a browser driver.
#
# Contract verified here:
#   Board shell (GET /admin/tasks?view=kanban):
#     • Wrapper div has data-controller="kanban"
#     • Wrapper div has data-kanban-move-url-template-value with the correct
#       URL format (/path/__ID__/kanban_move) — consumed by kanban_controller.js
#       to build the per-record move endpoint at drop time.
#
#   Column body (GET /admin/tasks?view=kanban&column=<key>):
#     • Card list has data-kanban-target="column"
#     • Card list has data-kanban-column-key-value="<key>"
#     • Each card has draggable="true"
#     • Each card has data-kanban-record-id="<id>"
#     • Each card has data-kanban-column-key="<key>"
#
# These guarantees mean kanban_controller.js can always find the target column,
# extract record id + source column key from the dragged card, compute to_index,
# and POST to the move URL — without any browser execution required to test
# the seam.
class AdminPortal::KanbanDomContractTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @todo = Task.create!(title: "Todo Alpha", status: "todo")
    @doing = Task.create!(title: "Doing One", status: "doing")
  end

  teardown { Task.delete_all }

  # ─── Board shell: Stimulus controller + move URL template ─────────────────

  test "board wrapper has data-controller=kanban" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    assert_match(/data-controller="kanban"/, response.body)
  end

  test "board wrapper has data-kanban-move-url-template-value" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    assert_match(/data-kanban-move-url-template-value=/, response.body)
  end

  test "move url template contains the collection path" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    # The template must be rooted at the resource collection path.
    assert_match(%r{data-kanban-move-url-template-value="/admin/tasks/}, response.body)
  end

  test "move url template contains __ID__ placeholder" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    assert_match(/__ID__/, response.body)
  end

  test "move url template ends with /kanban_move" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    assert_match(%r{__ID__/kanban_move}, response.body)
  end

  # ─── Frozen-board sync contract (search / filter / scope) ──────────────────
  # The board is data-turbo-permanent so it survives index navigations intact;
  # the kanban controller then reloads the column frames (found via
  # data-kanban-col-frame) and morphs them (refresh="morph").

  test "board wrapper is turbo-permanent with a resource-scoped id" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    assert_match(/data-turbo-permanent/, response.body)
    # Resource-scoped so navigating between two boards doesn't cross-preserve.
    assert_match(/id="kanban-board-task"/, response.body)
  end

  test "each column frame is morphable and tagged for the controller" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    # The todo column frame carries refresh=morph and its column key so the
    # controller can rewrite its src to the current URL params and morph-reload.
    frame = response.body[/<turbo-frame\b[^>]*\bid="kanban-col-todo"[^>]*>/]
    assert frame, "expected the todo column frame"
    assert_includes frame, %(refresh="morph")
    assert_includes frame, %(data-kanban-col-frame="todo")
  end

  # ─── Column body: drop zone + card attributes ──────────────────────────────

  test "column card list has data-kanban-target=column" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-target="column"/, response.body)
  end

  test "column card list has data-kanban-column-key-value matching the column key" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-column-key-value="todo"/, response.body)
  end

  test "todo column card is marked draggable" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/draggable="true"/, response.body)
  end

  test "todo column card has data-kanban-record-id" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-record-id="#{@todo.id}"/, response.body)
  end

  test "todo column card has data-kanban-column-key matching its column" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-column-key="todo"/, response.body)
  end

  test "doing column card has correct record id and column key" do
    get "/admin/tasks?view=kanban&column=doing"
    assert_response :success
    assert_match(/data-kanban-record-id="#{@doing.id}"/, response.body)
    assert_match(/data-kanban-column-key="doing"/, response.body)
  end

  test "cards from other columns do not appear in todo column body" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    # The doing card's record-id must not appear in the todo column body.
    refute_match(/data-kanban-record-id="#{@doing.id}"/, response.body)
  end
end
