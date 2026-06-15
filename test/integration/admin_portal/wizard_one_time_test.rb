# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# End-to-end test of the one-time wizard gate (§9) through the admin portal:
# an un-completed user hitting a gated page is bounced into the WelcomeWizard
# (with their destination stashed); on completing the wizard they're bounced back
# to that destination (PRG); a completed user passes straight through; and the
# durable completion marker is recorded.
class AdminPortal::WizardOneTimeTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    Plutonium::Wizard::Session.delete_all
  end

  def gated = "/admin/gated"
  def wizard = "/admin/welcome"

  test "un-completed user is redirected into the wizard when hitting the gated page" do
    get gated
    assert_response :redirect
    assert_match %r{/admin/welcome/greeting}, response.headers["Location"]
  end

  test "completing the one-time wizard records the durable marker and gate lets the user through" do
    # Hit the gate → bounced into the wizard (stashes return_to = /admin/gated).
    get gated
    assert_response :redirect

    # Complete the wizard.
    post "#{wizard}/greeting", params: {wizard: {acknowledged: "yes"}, _direction: "next"}
    follow_redirect! # → review
    post "#{wizard}/review", params: {_direction: "next"} # finalize

    # The durable completion marker exists for this user.
    assert Plutonium::Wizard::Store::ActiveRecord.new.completed?(
      wizard: WelcomeWizard.name, owner: @admin
    ), "a completed marker must exist for the user"

    # PRG bounce back to the stashed destination.
    assert_response :redirect
    assert_match %r{/admin/gated}, response.headers["Location"]

    # The gate now lets the user through.
    get gated
    assert_response :success
    assert_includes response.body, "gated ok"
  end

  test "an already-completed user passes straight through the gate" do
    Plutonium::Wizard::Session.create!(
      wizard: WelcomeWizard.name, instance_key: SecureRandom.hex,
      status: "completed", owner: @admin
    )

    get gated
    assert_response :success
    assert_includes response.body, "gated ok"
  end
end
