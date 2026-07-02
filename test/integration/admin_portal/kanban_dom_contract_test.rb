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

  # ─── Drop-interaction contract (modal-on-drop columns) ─────────────────────
  # A column that declares drop_interaction: advertises, on its [data-kanban-col]
  # wrapper, that a drop requires the interaction modal and the kanban_move_form
  # URL template (with __ID__ for the dragged card's id). Task 6's Stimulus code
  # reads these to open the modal instead of committing the move immediately.

  test "drop-interaction column advertises data-kanban-drop-interaction" do
    get "/admin/tasks?view=kanban&column=lost"   # :lost declares drop_interaction
    assert_response :success
    wrapper = response.body[/<div[^>]*data-kanban-col="lost"[^>]*>/]
    assert wrapper, "expected the lost column wrapper"
    assert_includes wrapper, 'data-kanban-drop-interaction="true"'
  end

  test "drop-interaction column advertises the kanban_move_form url template" do
    get "/admin/tasks?view=kanban&column=lost"
    assert_response :success
    wrapper = response.body[/<div[^>]*data-kanban-col="lost"[^>]*>/]
    assert wrapper, "expected the lost column wrapper"
    # Template is rooted at the collection path, carries the __ID__ placeholder,
    # and points at the kanban_move_form member route.
    assert_match(
      %r{data-kanban-drop-form-url-template="/admin/tasks/__ID__/kanban_move_form"},
      wrapper
    )
  end

  test "a plain column renders neither drop-interaction attribute" do
    get "/admin/tasks?view=kanban&column=todo"   # :todo has no drop_interaction
    assert_response :success
    wrapper = response.body[/<div[^>]*data-kanban-col="todo"[^>]*>/]
    assert wrapper, "expected the todo column wrapper"
    refute_includes wrapper, "data-kanban-drop-interaction"
    refute_includes wrapper, "data-kanban-drop-form-url-template"
  end

  # ─── Collapse cookie (server renders the user's state) ─────────────────────
  # The board persists per-column collapse as a compact cookie of columns
  # flipped from their default; the server reads it and renders each column in
  # the user's state, so there's no client re-apply / FOUC.

  COLLAPSE_COOKIE = Plutonium::UI::Kanban::Resource.collapse_cookie_name(Task)

  test "board exposes the collapse cookie name and path to the controller" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    assert_match(/data-kanban-collapse-cookie-value="#{COLLAPSE_COOKIE}"/o, response.body)
    assert_match(%r{data-kanban-collapse-path-value="/admin"}, response.body)
  end

  test "a column advertises its default collapse state for delta encoding" do
    get "/admin/tasks?view=kanban&column=done"   # :done role ⇒ default collapsed
    assert_response :success
    assert_match(/data-kanban-default-collapsed="true"/, response.body)
    get "/admin/tasks?view=kanban&column=todo"   # default expanded
    assert_response :success
    assert_match(/data-kanban-default-collapsed="false"/, response.body)
  end

  test "done column renders collapsed by default (no cookie)" do
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    wrapper = response.body[/<div[^>]*data-kanban-col="done"[^>]*>/]
    assert_includes wrapper, "pu-kanban-column-collapsed"
  end

  test "the cookie flips a column's rendered collapse state" do
    # done defaults collapsed → flipping it expands it
    cookies[COLLAPSE_COOKIE] = "done"
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    done = response.body[/<div[^>]*data-kanban-col="done"[^>]*>/]
    refute_includes done, "pu-kanban-column-collapsed", "expected 'done' flipped to expanded"

    # todo defaults expanded → the same cookie leaves it untouched
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    todo = response.body[/<div[^>]*data-kanban-col="todo"[^>]*>/]
    refute_includes todo, "pu-kanban-column-collapsed"

    # …and flipping todo collapses it
    cookies[COLLAPSE_COOKIE] = "todo"
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    todo = response.body[/<div[^>]*data-kanban-col="todo"[^>]*>/]
    assert_includes todo, "pu-kanban-column-collapsed", "expected 'todo' flipped to collapsed"
  end
end
