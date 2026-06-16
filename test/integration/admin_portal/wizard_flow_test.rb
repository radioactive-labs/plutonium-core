# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Drives the portal-hosted wizard controller + register_wizard routing end to end
# through the admin portal (non-entity-scoped). Mirrors the interactive-action
# integration tests for request shape and login, and exercises the real step-form
# UI (Task 6): typed inputs, the stepper, `using:` imports, repeater rehydration
# on GET, and the review auto-summary with a gated finish.
class AdminPortal::WizardFlowTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    Plutonium::Wizard::Session.delete_all
  end

  def base = "/admin/onboarding"

  # Advance the linear flow up to (but not including) the named step, staging
  # valid data for each step in between.
  def advance_through(*steps)
    payloads = {
      "identity" => {name: "Acme Inc", plan: "pro"},
      "details" => {note: "hello"},
      "profile" => {description: "a great org", tier: "1"},
      "members" => {invites: [{email: "a@example.com", role: "admin"}]}
    }
    steps.each do |step|
      post "#{base}/#{step}", params: {wizard: payloads.fetch(step), _direction: "next"}
      follow_redirect!
    end
  end

  test "GET first step renders the step form fields" do
    get "#{base}/identity"
    assert_response :success
    assert_includes response.body, %(name="wizard[name]")
    assert_includes response.body, %(name="_direction")
  end

  # --- typed inputs (not plain text) -----------------------------------------

  test "the step form renders real typed inputs, not plain text" do
    get "#{base}/identity"
    assert_response :success
    # plan declared `as: :select` → a <select>, not a text input.
    assert_match(/<select[^>]*name="wizard\[plan\]"/, response.body)
    # inline form_layout section heading renders.
    assert_includes response.body, "The basics"
  end

  test "a textarea input renders as a textarea" do
    advance_through("identity")
    # now on details
    assert_match(/<textarea[^>]*name="wizard\[note\]"/, response.body)
    assert_includes response.body, "textarea-autogrow"
  end

  # --- using: imported fields render with their styling ----------------------

  test "a using: step renders imported fields with their input styling" do
    advance_through("identity", "details")
    # now on profile (imports KitchenSink :description + :tier)
    assert_includes response.body, %(name="wizard[description]")
    # tier is `as: :select` in KitchenSinkDefinition → a slim-select <select>.
    assert_match(/<select[^>]*name="wizard\[tier\]"/, response.body)
    assert_includes response.body, "slim-select"
  end

  # --- stepper ----------------------------------------------------------------

  test "the stepper renders step states and links visited steps" do
    get "#{base}/identity"
    assert_response :success
    assert_includes response.body, "pu-wizard-stepper"
    # The current step is marked current; later steps are upcoming.
    assert_includes response.body, %(data-wizard-stepper-state="current")
    assert_includes response.body, %(data-wizard-stepper-state="upcoming")

    # After advancing, the visited step links back; the new current is marked.
    advance_through("identity")
    assert_match(%r{<a href="/admin/onboarding/identity"[^>]*>Identity</a>}, response.body)
  end

  # --- repeater rehydration on GET (resume) ----------------------------------

  test "a structured_input repeat: step rehydrates N rows from staged data on GET" do
    advance_through("identity", "details", "profile")
    # now on members — stage two invite rows
    post "#{base}/members", params: {
      wizard: {invites: [
        {email: "a@example.com", role: "admin"},
        {email: "b@example.com", role: "member"}
      ]},
      _direction: "next"
    }
    follow_redirect! # advances to review

    # Navigate back to members via a direct GET (stepper jump / resume).
    get "#{base}/members"
    assert_response :success
    assert_includes response.body, %(data-controller="nested-resource-form-fields")
    # Both rows render, seeded with their staged values (not just one blank row).
    assert_includes response.body, %(name="wizard[invites][0][email]")
    assert_includes response.body, %(name="wizard[invites][1][email]")
    assert_includes response.body, %(value="a@example.com")
    assert_includes response.body, %(value="b@example.com")
  end

  # --- review: auto-summary + gated finish + jump links ----------------------

  test "the review step renders an auto-summary, a custom block, and a finish" do
    advance_through("identity", "details", "profile", "members")
    # now on review (all steps complete)
    assert_includes response.body, %(data-wizard-review-step="identity")
    assert_includes response.body, "Acme Inc"          # summarized value
    assert_includes response.body, "Ready to onboard Acme Inc" # custom block
    assert_match(/data-wizard-nav="finish"/, response.body)
    # All steps complete → Finish is NOT disabled.
    finish_btn = response.body[/<button[^>]*data-wizard-nav="finish"[^>]*>/]
    refute_includes finish_btn, "disabled"
  end

  test "review lists outstanding steps as fix-this links and disables finish" do
    advance_through("identity") # only the first step is complete
    # Jump to review via direct GET — it surfaces outstanding steps + gated finish.
    get "#{base}/review"
    assert_response :success
    assert_includes response.body, "wizard-review-outstanding"
    assert_includes response.body, %(data-wizard-review-fix="details")
    finish_btn = response.body[/<button[^>]*data-wizard-nav="finish"[^>]*>/]
    assert_includes finish_btn, "disabled"
  end

  test "finalize is blocked while a step is incomplete (bounces, no record)" do
    advance_through("identity")
    assert_no_difference -> { Organization.count } do
      post "#{base}/review", params: {_direction: "next"}
    end
    # Bounced to the first incomplete step.
    assert_response :redirect
  end

  # --- full happy path --------------------------------------------------------

  test "full flow: advance through every step then finish creates the record (PRG)" do
    advance_through("identity", "details", "profile", "members")
    assert_includes response.body, "Review"

    assert_difference -> { Organization.count }, 1 do
      post "#{base}/review", params: {_direction: "next"}
    end
    assert_response :redirect
    assert Organization.exists?(name: "Acme Inc")
  end

  test "advance with invalid input re-renders with errors and does not advance" do
    post "#{base}/identity", params: {wizard: {name: ""}, _direction: "next"}
    assert_response :unprocessable_content
    assert_includes response.body, "name"
    assert_equal 0, Organization.count
  end

  test "back direction moves to the previous step without validating" do
    advance_through("identity")
    post "#{base}/details", params: {_direction: "back"}
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, %(name="wizard[name]")
  end

  test "cancel clears the wizard session and redirects out" do
    advance_through("identity")
    assert_operator Plutonium::Wizard::Session.count, :>=, 1

    post "#{base}/identity", params: {_direction: "cancel"}
    assert_response :redirect
    assert_equal 0, Plutonium::Wizard::Session.where(status: "in_progress").count
  end

  # §4: the documented default is a SINGLETON per (user, wizard). For an
  # authenticated non-anchored wizard the engine mints NO token — the principal is
  # the owner GID — so a second visit resumes the SAME session row, and the row
  # carries no token (two tabs/devices share one draft).
  test "authenticated non-anchored wizard is a singleton with no token" do
    advance_through("identity")
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count

    row = Plutonium::Wizard::Session.where(status: "in_progress").sole
    assert_nil row.token, "authenticated wizard must not mint a token (singleton-per-user)"
    assert_equal @admin.to_global_id.to_s, row.owner.to_global_id.to_s

    # Resuming (a fresh GET) does not spawn a second row — same instance key.
    get "#{base}/identity"
    assert_response :success
    assert_equal 1, Plutonium::Wizard::Session.where(status: "in_progress").count
  end
end
