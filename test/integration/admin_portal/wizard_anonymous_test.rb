# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Drives the AUTHENTICATION-HARDENING surface (§4.5):
#
# - an `anonymous` (guest) wizard runs with NO `current_user`, mounted on a PUBLIC
#   route (outside the portal's auth constraint), persists across requests via the
#   RAILS SESSION (no cookie, no URL token), completes, and clears its session
#   token on completion — `execute` is the only boundary it may cross;
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

  # The session key shape for a guest run's token (§4.5).
  def guest_session_key = Plutonium::Wizard::Driving.session_token_key(GuestSignupWizard)

  test "an anonymous wizard runs with no current_user and renders its first step" do
    # No login. The public mount is OUTSIDE the portal auth constraint.
    get "#{signup}/account"
    assert_response :success
    assert_includes response.body, %(name="wizard[name]")
  end

  test "a guest run persists across requests via the Rails session (no cookie, no URL token)" do
    # First POST stages data → mints a session token and an in_progress row.
    post "#{signup}/account", params: {wizard: {name: "Guest Co"}, _direction: "next"}
    assert_response :redirect

    # The token lives in the Rails session, namespaced per wizard — NOT in a cookie.
    bucket = session[Plutonium::Wizard::Driving::SESSION_TOKENS_KEY]
    assert bucket.is_a?(Hash), "guest token must live in the Rails session"
    token = bucket[guest_session_key]
    assert token.present?, "a guest run mints a session token"

    # No dedicated wizard token cookie was set, and no URL carries the token.
    set_cookie = response.headers["Set-Cookie"].to_s
    refute_includes set_cookie, "pu_wizard", "no wizard token cookie may be set"
    refute_includes response.headers["Location"].to_s, token,
      "the guest token must not appear in any URL"

    # The row exists and is keyed by the session token.
    row = Plutonium::Wizard::Session.where(status: "in_progress").sole
    assert_equal token, row.token

    # A FRESH request (same session) resumes that same row — staged data survives.
    assert_no_difference -> { Plutonium::Wizard::Session.count } do
      get "#{signup}/account"
    end
    assert_response :success
    assert_includes response.body, %(value="Guest Co"), "staged data survives across requests"
  end

  test "an anonymous wizard completes (execute runs) and clears its session token" do
    post "#{signup}/account", params: {wizard: {name: "Guest Co"}, _direction: "next"}
    assert_response :redirect
    assert session[Plutonium::Wizard::Driving::SESSION_TOKENS_KEY].present?

    assert_difference -> { Organization.count }, 1 do
      follow_redirect! # → review
      post "#{signup}/review", params: {_direction: "next"} # finalize → execute
    end
    assert_response :redirect
    assert Organization.exists?(name: "Guest Co")

    # The session token entry is cleared on completion (§4.5).
    bucket = session[Plutonium::Wizard::Driving::SESSION_TOKENS_KEY]
    assert bucket.nil? || !bucket.key?(guest_session_key),
      "completion must clear the guest run's session token"
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
