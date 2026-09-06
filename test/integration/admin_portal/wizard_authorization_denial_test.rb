# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# End-to-end regression for the entry-authorization DENIAL path in
# {Plutonium::Wizard::Driving#authorize_wizard_entry!}.
#
# Every existing dummy wizard gates `authorize?` behind `current_user.present?`,
# and the portal is mounted behind `Rodauth::Rails.authenticate(:admin)`, so the
# denial branch (`authorize?` -> false) is never reached by the rest of the suite.
# Before the fix it crashed with `NameError: uninitialized constant
# Plutonium::ActionPolicy::Unauthorized` (bare `ActionPolicy` resolves to the
# `Plutonium` namespace), and — once the `::` prefix is added —
# `NoMethodError: undefined method 'result' for class <Wizard>` (the exception's
# default `result = policy.result` is invoked on a Class).
#
# Here a wizard whose `authorize?` returns false (driven by overriding the
# instance method on the registered `LateRevealWizard` for the test's duration
# only) must produce a 403 Forbidden response — the request is handled by the
# existing `::ActionPolicy::Unauthorized` rescue, not by an unhandled crash.
class AdminPortal::WizardAuthorizationDenialTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  TURBO_STREAM_ACCEPT = "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    Plutonium::Wizard::Session.delete_all
  end

  def base = "/admin/late-reveal"

  def wizard_class
    LateRevealWizard
  end

  # Override `authorize?` to return false for the duration of the block, then
  # restore the original method — guaranteed by `ensure`, so the shared wizard
  # class is untouched for any other test.
  def with_entry_denied
    wizard_class.alias_method(:__denied_test_authorize__, :authorize?)
    wizard_class.define_method(:authorize?) { false }
    yield
  ensure
    if wizard_class.method_defined?(:__denied_test_authorize__)
      wizard_class.alias_method(:authorize?, :__denied_test_authorize__)
      wizard_class.remove_method(:__denied_test_authorize__)
    end
  end

  test "a denied wizard launch responds 403 Forbidden, not an unhandled crash (HTML)" do
    with_entry_denied do
      get base
      assert_response :forbidden, "denied entry must be a forbidden response, not a crash"
    end
  end

  test "a denied wizard launch responds 403 Forbidden for Turbo Stream requests" do
    with_entry_denied do
      get base, headers: {"Accept" => TURBO_STREAM_ACCEPT}
      assert_response :forbidden, "denied entry must be forbidden for turbo_stream too"
    end
  end

  test "the forbidden response carries no internal crash signature from the buggy raise" do
    with_entry_denied do
      get base
      assert_response :forbidden
      body = response.body.to_s
      refute_includes body, "undefined method 'result'", "must not leak the NoMethodError"
      refute_includes body, "Plutonium::ActionPolicy::Unauthorized",
        "must not leak the namespace-collision NameError"
    end
  end

  test "authorization deny is per-request: restoring authorize? re-enables the wizard" do
    with_entry_denied do
      get base
      assert_response :forbidden
    end

    # The original `authorize? = current_user.present?` is restored; logged-in
    # admin launches normally again (redirect to the first step, no 403).
    get base
    assert_response :redirect, "happy path must not regress once authorization is restored"
    assert_match %r{/late-reveal/[^/]+/details\z}, URI(response.location).path
  end

  test "an in-progress run is also denied when authorize? returns false" do
    # Mint a real, admin-owned in-progress run via the happy path, then flip the
    # gate to deny and prove BOTH the GET (wizard_show) and POST (wizard_update)
    # guested entries return 403 — not a crash — through the same shared rescue.
    get base
    assert_response :redirect
    token = URI(response.location).path[%r{/late-reveal/([^/]+)/}, 1]
    run = "#{base}/#{token}"

    # Sanity: the step renders for the authenticated owner while authorized.
    get "#{run}/details"
    assert_response :success

    with_entry_denied do
      get "#{run}/details"
      assert_response :forbidden, "wizard_show on a denied wizard must be 403, not a crash"

      post "#{run}/details", params: {wizard: {template: "pro"}, _direction: "next"}
      assert_response :forbidden, "wizard_update on a denied wizard must be 403, not a crash"
    end

    # Restoration: the same run is reachable again (no 403, no leak).
    get "#{run}/details"
    assert_response :success
    refute_equal :forbidden, response.status
  end
end
