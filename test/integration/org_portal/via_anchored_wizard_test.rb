# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Drives a CONTEXT-anchored (`anchored via:`) portal-level wizard mounted with
# `register_wizard` in the entity-scoped org portal (§3 / §5.2). Proves:
#
# - the wizard launches at `/org/:org/configure/:step` (no URL :id — the anchor is
#   the tenant resolved via `current_scoped_entity`), advances → finalizes, and
#   `execute` mutates THAT organization (the via-resolved anchor);
# - concurrency (§4.2): a `concurrency_key { anchor }` keeps a single in-progress
#   row per org — a second GET resumes rather than forking;
# - one-time (§4.3): on finish the completed row is retained, and re-entry bounces
#   out rather than re-running.
class OrgPortal::ViaAnchoredWizardTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!(name: "Acme")
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    login_as(@user, portal: :user)
    Plutonium::Wizard::Session.delete_all
  end

  def base = "/org/#{@org.to_param}/configure"

  test "GET the first step renders the via-anchored wizard's step form" do
    get "#{base}/rename"
    assert_response :success
    assert_includes response.body, %(name="wizard[name]")
  end

  test "advance then finish mutates the via-resolved anchor (the tenant org)" do
    post "#{base}/rename", params: {wizard: {name: "Renamed Org"}, _direction: "next"}
    assert_response :redirect
    follow_redirect! # → review
    post "#{base}/review", params: {_direction: "next"} # finalize
    assert_response :redirect

    assert_equal "Renamed Org", @org.reload.name
  end

  test "concurrency_key { anchor }: a second GET resumes the same row, not forks" do
    post "#{base}/rename", params: {wizard: {name: "Draft"}, _direction: "next"}
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count

    get "#{base}/rename"
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count,
      "a second launch with the same concurrency key resumes, never forks"
  end

  test "one_time: the completed row is retained and re-entry shows the completed page" do
    post "#{base}/rename", params: {wizard: {name: "Final"}, _direction: "next"}
    follow_redirect!
    post "#{base}/review", params: {_direction: "next"} # finalize

    # The completed marker is retained (one_time), not deleted.
    assert_equal 1, Plutonium::Wizard::Session.where(status: "completed").count

    # Re-entering the finished one-time wizard renders the completed page (no
    # re-run, no review). ConfigureOrgWizard declares a custom `completed` block,
    # which replaces the default body entirely.
    get "#{base}/rename"
    assert_response :success
    assert_includes response.body, "pu-wizard-completed"
    assert_includes response.body, %(data-wizard-completed="custom")
    assert_includes response.body, "already configured"
    # The custom block replaced the default body — no default Continue button.
    refute_includes response.body, %(data-wizard-completed="exit")
    # And not the step form.
    refute_includes response.body, %(name="wizard[name]")
  end
end
