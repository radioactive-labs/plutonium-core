# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Drives the portal-hosted wizard controller + register_wizard routing end to end
# through the admin portal (non-entity-scoped). Mirrors the interactive-action
# integration tests for request shape and login.
class AdminPortal::WizardFlowTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @admin = create_admin!
    login_as(@admin, portal: :admin)
    Plutonium::Wizard::Session.delete_all
  end

  def base = "/admin/onboarding"

  test "GET first step renders the step form fields" do
    get "#{base}/identity"
    assert_response :success
    assert_includes response.body, %(name="wizard[name]")
    assert_includes response.body, %(name="_direction")
  end

  test "full flow: advance through steps then finish creates the record (PRG)" do
    # Step 1 → next
    post "#{base}/identity", params: {wizard: {name: "Acme Inc"}, _direction: "next"}
    assert_response :redirect
    follow_redirect!
    assert_response :success
    # We should now be on the details step
    assert_includes response.body, %(name="wizard[note]")

    # Step 2 → next (advances to review)
    post "#{base}/details", params: {wizard: {note: "hello"}, _direction: "next"}
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, "Review"

    # Review step → finish (last visible step → finalize)
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
    assert_no_difference -> { Organization.count } do
      # confirm nothing was created
    end
  end

  test "back direction moves to the previous step without validating" do
    # advance to details first
    post "#{base}/identity", params: {wizard: {name: "Acme"}, _direction: "next"}
    follow_redirect!
    # now go back from details
    post "#{base}/details", params: {_direction: "back"}
    assert_response :redirect
    follow_redirect!
    assert_includes response.body, %(name="wizard[name]")
  end

  test "cancel clears the wizard session and redirects out" do
    post "#{base}/identity", params: {wizard: {name: "Acme"}, _direction: "next"}
    follow_redirect!
    assert_operator Plutonium::Wizard::Session.count, :>=, 1

    post "#{base}/identity", params: {_direction: "cancel"}
    assert_response :redirect
    assert_equal 0, Plutonium::Wizard::Session.where(status: "in_progress").count
  end
end
