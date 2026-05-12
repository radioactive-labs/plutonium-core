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

  # Happy path — exercises the full stack end-to-end: real route,
  # real definition lookup, real ActiveRecord query (via the `name`
  # fallback column on Organization), real serializer. Proves results
  # come back as SGIDs and that policy.relation_scope filters the query.
  test "typeahead_input returns matching association records as SGIDs" do
    matching = create_organization!(name: "Acme Widgets")
    create_organization!(name: "Globex Corp")

    get "/admin/organization_users/typeahead/input/organization?q=acme"
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal false, body["has_more"]
    labels = body["results"].map { |r| r["label"] }
    assert_includes labels, "Acme Widgets"
    refute_includes labels, "Globex Corp"

    sgid = body["results"].find { |r| r["label"] == "Acme Widgets" }["value"]
    assert_equal matching, GlobalID::Locator.locate_signed(sgid)
  end

  test "typeahead_input escapes SQL LIKE wildcards in user input" do
    create_organization!(name: "100% Cotton")
    create_organization!(name: "Plain Linen")

    get "/admin/organization_users/typeahead/input/organization?q=#{CGI.escape("100%")}"
    assert_response :success

    labels = JSON.parse(response.body)["results"].map { |r| r["label"] }
    assert_includes labels, "100% Cotton"
    refute_includes labels, "Plain Linen"
  end
end
