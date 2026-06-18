# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Exercises a MAIN-APP (portal-less) AUTHENTICATED wizard — `register_wizard`
# mounted directly on `Rails.application.routes`, outside any portal engine
# (`MainAppOnboardingWizard` at `/onboarding`). Proves:
#
#   - auth works off the app's `::PlutoniumController` (Rodauth(:user)): an
#     unauthenticated visitor is bounced to login; a logged-in user gets in;
#   - the synthesized top-level `WizardsController` is DISTINCT from the public
#     `PublicWizardsController` (the dummy also registers a guest wizard), so the
#     authenticated wizard isn't hijacked by the guest controller;
#   - the full launch → step → step → review → finalize flow runs standalone.
class MainAppWizardTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  def base = "/onboarding"

  setup do
    Plutonium::Wizard::Session.delete_all
    @user = create_user!
  end

  test "an unauthenticated visitor is redirected to login, not into the wizard" do
    get base
    assert_response :redirect
    refute_match %r{/onboarding/}, URI(response.location).path,
      "must not resolve a run for an anonymous visitor"
  end

  test "the main-app wizard dispatches to the authenticated controller, not the public one" do
    login_as(@user, portal: :user)
    get base
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "WizardsController", @controller.class.name,
      "main-app authenticated wizard must use ::WizardsController, not PublicWizardsController"
  end

  test "a main-app wizard renders shell-less (standalone) by default" do
    login_as(@user, portal: :user)
    get base
    follow_redirect!
    assert_response :success
    refute_includes response.body, "sidebar-navigation",
      "a main-app wizard defaults to the bare basic layout"
  end

  test "an authenticated user runs the main-app wizard to completion" do
    login_as(@user, portal: :user)

    # Launch resolves/mints the run and PRGs to the first step (token in the URL).
    get base
    assert_response :redirect
    step_base = URI(response.location).path[%r{\A/onboarding/[A-Za-z0-9]{32}}]
    assert step_base, "launch redirects into a tokened run URL (#{response.location})"

    follow_redirect! # → profile
    assert_response :success
    assert_includes response.body, %(name="wizard[display_name]")

    post "#{step_base}/profile", params: {wizard: {display_name: "Ada"}, _direction: "next"}
    follow_redirect! # → preferences
    assert_includes response.body, %(name="wizard[newsletter]")

    post "#{step_base}/preferences", params: {wizard: {newsletter: "yes"}, _direction: "next"}
    follow_redirect! # → review
    assert_includes response.body, "Review"

    post "#{step_base}/review", params: {_direction: "next"} # finalize
    assert_response :redirect

    assert_equal 0, Plutonium::Wizard::Session.where(status: "in_progress").count,
      "a repeatable wizard clears its run on completion"
  end
end
