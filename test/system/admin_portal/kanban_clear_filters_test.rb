# frozen_string_literal: true

require "application_system_test_case"

# Clearing filters from the slideover must keep the user on whatever view they
# were looking at. On the kanban board the panel's "Clear" button used to submit
# the toolbar's bare search form (the first <form> in the panel scope), which
# carries no view/sort/scope state, so a GET replaced the query string and
# dropped ?view=kanban — bouncing the user back to the table.
class AdminPortal::KanbanClearFiltersTest < ApplicationSystemTestCase
  setup do
    @admin = create_admin!
    Task.create!(title: "Existing todo", status: "todo")
  end

  teardown { Task.delete_all }

  test "clearing filters from the board stays on the board" do
    open_board

    # Open the slideover and hit Clear.
    click_button "Filter"
    within "#filter-form" do
      click_button "Clear"
    end

    # Must still be on the board, not bounced to the table.
    assert_selector "[data-controller~='kanban']", wait: 5
    assert_no_selector "table", wait: 5
    assert_current_path(/view=kanban/, wait: 5)
  end

  private

  def open_board
    visit "/admin/tasks?view=kanban"
    fill_in "login", with: @admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"
    assert_selector "[data-controller~='kanban']", wait: 5
  end
end
