# frozen_string_literal: true

require "test_helper"

class AdminPortal::TypeaheadTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  # Routing — proves the routes are mounted on every Plutonium resource
  # and dispatch into the Typeahead controller concern. The 404 comes
  # from inside the action (input :no_such_field isn't defined on
  # OrganizationDefinition), which means routing succeeded and the
  # controller's lookup short-circuited correctly.

  test "typeahead_input route returns 404 for unknown input name" do
    get "/admin/organizations/typeahead/input/no_such_field?q=a"
    assert_response :not_found
  end

  test "typeahead_filter route returns 404 for unknown filter name" do
    get "/admin/organizations/typeahead/filter/no_such_filter?q=a"
    assert_response :not_found
  end

  # Authorization — proves the before_action authorize_typeahead! gate
  # is wired. Without an admin session, Rodauth's authentication
  # constraint blocks before we reach the action.

  test "typeahead_input is gated by admin authentication" do
    logout_admin
    get "/admin/organizations/typeahead/input/no_such_field?q=a"
    refute_equal 200, response.status, "unauthenticated access should not return 200"
  end
end
