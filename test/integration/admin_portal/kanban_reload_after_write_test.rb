# frozen_string_literal: true

require "test_helper"

# A create/update/destroy that returns to a kanban board tags the redirect with
# kanban_reload=1 (KanbanActions#kanban_reload_url), so the client re-fetches the
# permanent board's otherwise-cached column frames on arrival. The marker is only
# added when the redirect actually lands on the board.
class AdminPortal::KanbanReloadAfterWriteTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  teardown { Task.delete_all }

  test "create returning to the board tags the redirect with kanban_reload" do
    post "/admin/tasks",
      params: {task: {title: "New", status: "todo"}, return_to: "/admin/tasks?view=kanban"}
    assert_response :redirect
    assert_match(/kanban_reload=1/, response.location,
      "a board-bound create redirect must be tagged so the board refreshes")
  end

  test "destroy returning to the board tags the redirect with kanban_reload" do
    task = Task.create!(title: "Doomed", status: "todo")
    delete "/admin/tasks/#{task.id}", params: {return_to: "/admin/tasks?view=kanban"}
    assert_response :redirect
    assert_match(/kanban_reload=1/, response.location)
  end

  test "a destroy from within a column frame lands on the full board, not the fragment" do
    # A card's delete button rendered inside a lazy column frame defaults its
    # return_to to that frame's URL (view=kanban&column=<key>). The redirect must
    # be normalized to the full board — column= stripped — or it lands on the
    # bare single-column fragment (maybe_render_kanban_column) instead of the board.
    task = Task.create!(title: "Doomed", status: "done")
    delete "/admin/tasks/#{task.id}",
      params: {return_to: "/admin/tasks?view=kanban&column=done"}
    assert_response :redirect
    assert_match(/kanban_reload=1/, response.location)
    refute_match(/column=/, response.location,
      "column= must be stripped so the redirect targets the full board")
    assert_match(/view=kanban/, response.location)
  end

  test "an interactive action returning to the board tags the redirect" do
    # Interactive actions redirect via redirect_url_after_action_on (not
    # after_submit), which the prepended ReloadRedirects also wraps. archive_all
    # is a bulk action; posting it with a board return_to must be tagged.
    task = Task.create!(title: "Done", status: "done")
    post "/admin/tasks/bulk_actions/archive_all",
      params: {ids: [task.id], return_to: "/admin/tasks?view=kanban"}
    assert_response :redirect
    assert_match(/kanban_reload=1/, response.location,
      "redirect_url_after_action_on must be tagged for board-bound actions too")
  end

  test "a redirect that does NOT land on the board is not tagged" do
    # No return_to → create falls back to the record show page (not the board).
    post "/admin/tasks", params: {task: {title: "New", status: "todo"}}
    assert_response :redirect
    refute_match(/kanban_reload/, response.location,
      "only board-bound redirects should be tagged")
  end

  test "the marker is not doubled if already present" do
    post "/admin/tasks",
      params: {task: {title: "New", status: "todo"}, return_to: "/admin/tasks?view=kanban&kanban_reload=1"}
    assert_response :redirect
    assert_equal 1, response.location.scan("kanban_reload").size
  end
end
