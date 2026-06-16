# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Drives the AUTHENTICATION-HARDENING surface (§4.5):
#
# - an `anonymous` (guest) wizard runs with NO `current_user`, mounted on a PUBLIC
#   route (outside the portal's auth constraint), completes, and clears its run-id
#   cookie on completion — `execute` is the only boundary it may cross;
# - a non-`anonymous` wizard with no `current_user` rejects entry (redirect/401);
# - owner-scoping: user B cannot resume user A's in-progress run via A's URL.
class AdminPortal::WizardAnonymousTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    Plutonium::Wizard::Session.delete_all
    Organization.delete_all
  end

  # --- anonymous (guest) wizard on a public route -----------------------------

  def signup = "/signup"

  test "an anonymous wizard runs with no current_user and renders its first step" do
    # No login. The public mount is OUTSIDE the portal auth constraint.
    get "#{signup}/account"
    assert_response :success
    assert_includes response.body, %(name="wizard[name]")
  end

  test "an anonymous wizard completes (execute runs) and clears its run-id cookie" do
    get "#{signup}/account"
    assert_response :success

    assert_difference -> { Organization.count }, 1 do
      post "#{signup}/account", params: {wizard: {name: "Guest Co"}, _direction: "next"}
      follow_redirect! # → review
      post "#{signup}/review", params: {_direction: "next"} # finalize → execute
    end
    assert_response :redirect
    assert Organization.exists?(name: "Guest Co")

    # The run-id cookie is cleared on completion (§4.5).
    cookie_key = Plutonium::Wizard::Driving.token_cookie_key(GuestSignupWizard)
    set_cookie = response.headers["Set-Cookie"]
    assert set_cookie.to_s.include?(cookie_key.to_s),
      "completion must touch (clear) the run-id cookie"
  end

  # --- auth required by default -----------------------------------------------

  test "a non-anonymous wizard with no current_user rejects entry" do
    # Not logged in; the admin portal is mounted behind Rodauth's auth constraint,
    # so an unauthenticated request to the portal-hosted wizard is rejected.
    get "/admin/onboarding/identity"
    refute_equal 200, response.status, "unauthenticated entry must not render the step"
    assert_includes [301, 302, 303, 401, 404], response.status
  end

  # --- owner-scoping: B cannot resume A's run ---------------------------------

  test "user B cannot resume user A's in-progress run via A's URL" do
    admin_a = create_admin!
    admin_b = create_admin!

    # A starts a run.
    login_as(admin_a, portal: :admin)
    post "/admin/onboarding/identity",
      params: {wizard: {name: "A's Org", plan: "pro"}, _direction: "next"}
    assert_response :redirect
    row = Plutonium::Wizard::Session.where(status: "in_progress").sole
    assert_equal admin_a.to_global_id.to_s, row.owner.to_global_id.to_s

    # The run id leaks into a URL (the token). B logs in and tries to resume it.
    leaked_token = row.token
    sign_out(portal: :admin)
    login_as(admin_b, portal: :admin)

    get "/admin/onboarding/#{leaked_token}/identity"
    assert_response :not_found, "a leaked run id must not be resumable by another user"

    # A's row is untouched (not forked, not stolen).
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count
    assert_equal admin_a.to_global_id.to_s,
      Plutonium::Wizard::Session.where(status: "in_progress").sole.owner.to_global_id.to_s
  end
end
