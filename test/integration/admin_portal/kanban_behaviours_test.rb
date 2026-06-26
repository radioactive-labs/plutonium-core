# frozen_string_literal: true

require "test_helper"

# Integration tests for Task 13: column collapse toggle + client-side drop hints.
#
# Verifies the server-side DOM contract that the kanban Stimulus controller
# depends on for:
#
#   1. Drop-policy data attributes on each column wrapper:
#      • data-kanban-accepts — "all", "none", or comma-separated source keys
#      • data-kanban-locked  — "true" or "false"
#      These are consumed by kanban_controller.js#applyDropHints to show
#      visual hints during a drag without re-implementing server logic.
#
#   2. Collapse toggle control on every column (both initial states):
#      • data-action="click->kanban#toggleColumn" on the expand/collapse button
#      • data-kanban-column-key="<key>" on the same button so the Stimulus
#        action handler can find the column wrapper to toggle.
#
#   3. Structural role attributes on strip and body:
#      • data-kanban-role="strip" — the collapsed narrow strip
#      • data-kanban-role="body"  — the expanded card list + header
#      Both are always emitted; CSS (controlled by pu-kanban-column-collapsed
#      on the wrapper) shows one and hides the other.
#
# The dummy Task board (TaskDefinition) uses:
#   :todo  (role :backlog)  — accepts: true (all), locked: false
#   :doing (wip: 3)         — accepts: true (all), locked: false
#   :done  (role :done,     — accepts: [:doing],   locked: false
#           accepts: [:doing], collapsed: true by role)
#
# All tests are server-side only (ActionDispatch::IntegrationTest); no browser
# required for JS behaviour verification.
class AdminPortal::KanbanBehavioursTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)

    @doing_task = Task.create!(title: "Doing Task", status: "doing")
  end

  teardown { Task.delete_all }

  # ─── Drop-policy data attributes ───────────────────────────────────────────

  test "unrestricted column carries data-kanban-accepts=all" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-accepts="all"/, response.body)
  end

  test "restricted column carries data-kanban-accepts with allowed source keys" do
    # :done column has accepts: [:doing], so only cards from :doing may be dropped.
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    assert_match(/data-kanban-accepts="doing"/, response.body)
  end

  test "doing column carries data-kanban-accepts=all" do
    get "/admin/tasks?view=kanban&column=doing"
    assert_response :success
    assert_match(/data-kanban-accepts="all"/, response.body)
  end

  test "column carries data-kanban-locked=false when not locked" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-locked="false"/, response.body)
  end

  # ─── Collapse toggle control — initially collapsed column ─────────────────

  test "collapsed column renders a toggle control with kanban#toggleColumn action" do
    # :done is collapsed by role: :done
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    # Phlex renders data-action values without encoding >, so match the literal arrow.
    assert_match(/data-action="click->kanban#toggleColumn"/, response.body)
  end

  test "collapsed column toggle control carries data-kanban-column-key" do
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    assert_match(/data-kanban-column-key="done"/, response.body)
  end

  # ─── Collapse toggle control — initially expanded column ──────────────────

  test "expanded column also renders a toggle control for collapsing" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-action="click->kanban#toggleColumn"/, response.body)
    assert_match(/data-kanban-column-key="todo"/, response.body)
  end

  test "doing column renders a collapse toggle button" do
    get "/admin/tasks?view=kanban&column=doing"
    assert_response :success
    assert_match(/data-action="click->kanban#toggleColumn"/, response.body)
  end

  # ─── Strip / body structural roles ────────────────────────────────────────

  test "column body renders with data-kanban-role=body" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-role="body"/, response.body)
  end

  test "column strip renders with data-kanban-role=strip" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    assert_match(/data-kanban-role="strip"/, response.body)
  end

  test "both strip and body are present in collapsed column response" do
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    assert_match(/data-kanban-role="strip"/, response.body)
    assert_match(/data-kanban-role="body"/, response.body)
  end

  # ─── Wrapper carries initial CSS class for collapsed state ────────────────

  test "collapsed column wrapper carries pu-kanban-column-collapsed class" do
    get "/admin/tasks?view=kanban&column=done"
    assert_response :success
    assert_match(/pu-kanban-column-collapsed/, response.body)
  end

  test "expanded column wrapper does not carry pu-kanban-column-collapsed class" do
    get "/admin/tasks?view=kanban&column=todo"
    assert_response :success
    refute_match(/pu-kanban-column-collapsed/, response.body)
  end

  # ─── Board still renders (smoke check) ────────────────────────────────────

  test "board shell still renders with all columns" do
    get "/admin/tasks?view=kanban"
    assert_response :success
    assert_match(/data-controller="kanban"/, response.body)
  end
end
