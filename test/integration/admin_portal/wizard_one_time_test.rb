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
  # WelcomeWizard is mounted `at: "welcome_aboard"` (≠ its class slug "welcome"),
  # exercising the gate's route-by-`wizard_class`-default resolution (§5.3 / C10).
  def wizard = "/admin/welcome_aboard"

  test "un-completed user is redirected into the wizard when hitting the gated page" do
    get gated
    assert_response :redirect
    # The gate redirects to the bare LAUNCH route (resume-aware), which then PRGs
    # to the run's entry step.
    assert_match %r{/admin/welcome_aboard\z}, response.headers["Location"]
    follow_redirect!
    assert_response :redirect
    assert_match %r{/admin/welcome_aboard/greeting}, response.headers["Location"]
  end

  test "completing the one-time wizard records the durable marker and gate lets the user through" do
    # Hit the gate → bounced into the wizard (stashes return_to = /admin/gated).
    get gated
    assert_response :redirect

    # Complete the wizard.
    post "#{wizard}/greeting", params: {wizard: {acknowledged: "yes"}, _direction: "next"}
    follow_redirect! # → review
    post "#{wizard}/review", params: {_direction: "next"} # finalize

    # The durable completion marker exists at this user's recomputed key.
    assert Plutonium::Wizard::Store::ActiveRecord.new.completed?(
      instance_key: welcome_key_for(@admin)
    ), "a completed marker must exist for the user"

    # PRG bounce back to the stashed destination.
    assert_response :redirect
    assert_match %r{/admin/gated}, response.headers["Location"]

    # The gate now lets the user through.
    get gated
    assert_response :success
    assert_includes response.body, "gated ok"
  end

  # Re-opening a completed one-time wizard renders the standalone "already
  # completed" page (its `data` was cleared on completion, so there's nothing to
  # review) — not a redirect to root, and not the review/form.
  test "re-opening a completed one-time wizard renders the completed page" do
    Plutonium::Wizard::Session.create!(
      wizard: WelcomeWizard.name, instance_key: welcome_key_for(@admin),
      status: "completed", owner: @admin
    )

    get "#{wizard}/greeting"
    assert_response :success
    assert_includes response.body, "pu-wizard-completed"
    assert_includes response.body, "already completed"
    assert_includes response.body, %(data-wizard-completed="exit") # the Continue button
    # Not the step form.
    refute_includes response.body, %(name="wizard[acknowledged]")

    # The bare launch URL lands on the same completed page (not a redirect to a step).
    get wizard
    assert_response :success
    assert_includes response.body, "pu-wizard-completed"
  end

  test "an already-completed user passes straight through the gate" do
    Plutonium::Wizard::Session.create!(
      wizard: WelcomeWizard.name, instance_key: welcome_key_for(@admin),
      status: "completed", owner: @admin
    )

    get gated
    assert_response :success
    assert_includes response.body, "gated ok"
  end

  private

  # Recompute the WelcomeWizard instance_key the gate/runner would use for a given
  # user (admin portal is not entity-scoped → tenant folds to nil). MUST match the
  # framework digest, so it goes through the same helper.
  def welcome_key_for(user)
    Plutonium::Wizard.compute_instance_key(
      wizard_class: WelcomeWizard, current_user: user,
      current_scoped_entity: nil, anchor: nil, wizard_token: nil
    )
  end
end
