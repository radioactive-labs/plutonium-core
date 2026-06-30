# frozen_string_literal: true

require "test_helper"

# Integration tests for the card_fields DSL option (GAP 1).
#
# card_fields(**slots) on a board declaration overrides which slots each card
# renders.  Without card_fields the card uses the resource definition's
# grid_fields (or the default header-only fallback).  With card_fields, the
# declared slots take precedence.
#
# TaskDefinition declares:
#   card_fields header: :title, meta: [:status]
#
# Without card_fields wired, a column response would contain cards with no
# meta badge (because TaskDefinition has no grid_fields, so defined_grid_fields
# returns {}). After wiring, cards show a status badge.
class AdminPortal::KanbanCardFieldsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @todo_task = Task.create!(title: "Widget Alpha", status: "todo")
  end

  teardown { Task.delete_all }

  # When card_fields is wired, the meta slot renders status values as badges.
  # The badge HTML contains the CSS class "pu-badge". Without card_fields,
  # TaskDefinition has no grid_fields so no meta slot renders → no badge.
  test "card_fields meta slot produces status badge in column card HTML" do
    get "/admin/tasks?view=kanban&column=todo"

    assert_response :success
    assert_includes response.body, "pu-badge",
      "expected a status badge because card_fields(meta: [:status]) is declared"
  end

  # The header slot (card_fields header: :title) shows the task title.
  # This is indistinguishable from the default fallback (to_label), but we
  # include it to confirm the card renders at all.
  test "card renders the task title in the header" do
    get "/admin/tasks?view=kanban&column=todo"

    assert_response :success
    assert_includes response.body, "Widget Alpha"
  end
end
