# frozen_string_literal: true

require "application_system_test_case"

# The board is data-turbo-permanent, so returning to it after a write keeps the
# cached (stale) column frames. A write that lands back on the board tags the URL
# with kanban_reload=1; the controller re-fetches the columns so the change shows
# without a manual reload. Verifies the quick-add case end-to-end.
class AdminPortal::KanbanReloadAfterWriteTest < ApplicationSystemTestCase
  setup do
    @admin = create_admin!
    Task.create!(title: "Existing todo", status: "todo")
  end

  teardown { Task.delete_all }

  test "a quick-added card appears on the board without a manual reload" do
    open_board

    click_link "+ Add"
    assert_selector "dialog[open]", wait: 5
    within "dialog[open]" do
      fill_in "task[title]", with: "Brand new card"
      find("button[type='submit']").click
    end

    # Back on the board (return_to), the reloaded Todo column shows the new card,
    # and the one-shot marker has been stripped from the URL.
    assert_current_path(%r{/admin/tasks\?}, wait: 5)
    assert_text "Brand new card", wait: 5
    assert_no_current_path(/kanban_reload/, wait: 5)
  end

  private

  def open_board
    visit "/admin/tasks?view=kanban"
    fill_in "login", with: @admin.email
    click_button "Login"
    fill_in "password", with: "password123"
    click_button "Login"
    assert_selector "[data-controller~='kanban']", wait: 5
    assert_link "+ Add", wait: 5
  end
end
