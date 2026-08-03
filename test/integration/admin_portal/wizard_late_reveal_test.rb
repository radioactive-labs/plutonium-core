# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Regression: a wizard whose later steps are gated on an answer from its FIRST
# step. Every `condition:` is evaluated against `data`, so at the moment that
# first step is POSTed the steps it reveals are still hidden — the visible path
# is just `[details]`.
#
# The driving layer used to decide advance-vs-finalize from that pre-submission
# path: it read `details` as terminal and finalized, which found `details`
# unsubmitted and PRG'd back to it. The revealed steps were unreachable and no
# run was ever written. See `Plutonium::Wizard::Runner#submit`.
class AdminPortal::WizardLateRevealTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    Plutonium::Wizard::Session.delete_all
  end

  def base = "/admin/late-reveal"

  # Launch and return the tokened run base URL.
  def launch
    get base
    assert_response :redirect
    token = URI(response.location).path[%r{/late-reveal/([^/]+)/}, 1]
    assert token, "launch redirects into a tokened run URL (#{response.location})"
    "#{base}/#{token}"
  end

  test "the first POST advances into the step its own answer reveals" do
    run = launch

    post "#{run}/details", params: {wizard: {template: "pro"}, _direction: "next"}
    assert_response :redirect
    assert_match %r{/setup\z}, URI(response.location).path,
      "the revealed step must be reachable, not a bounce back to :details"

    follow_redirect!
    assert_response :success
    assert_includes response.body, %(name="wizard[note]")

    session = Plutonium::Wizard::Session.where(status: "in_progress").first
    assert session, "the advance must have written the run"
    assert_equal "pro", session.data.dig("details", "template"),
      "the submission that revealed the step must itself be staged"
  end

  test "the first POST finalizes when its answer reveals nothing after it" do
    run = launch

    post "#{run}/details", params: {wizard: {template: "basic"}, _direction: "next"}
    assert_response :redirect
    refute_match %r{/details\z}, URI(response.location).path,
      "with nothing left to collect the flow completes instead of bouncing"

    assert_equal 0, Plutonium::Wizard::Session.where(status: "in_progress").count,
      "a repeatable wizard clears its run on completion"
  end

  test "an invalid first POST re-renders the step instead of finalizing" do
    run = launch

    post "#{run}/details", params: {wizard: {template: ""}, _direction: "next"}
    assert_response :unprocessable_content
    assert_includes response.body, %(name="wizard[template]")
  end
end
