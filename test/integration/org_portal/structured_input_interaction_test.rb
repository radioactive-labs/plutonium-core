# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Verifies the full collect_spec interaction round-trip: structured-input params
# (single address + repeater contacts) are extracted, cleaned, and passed to
# execute, whose flash message reflects the cleaned contacts count.
class OrgPortal::StructuredInputInteractionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @category = create_category!
    @product = create_product!(category: @category, user: @user, organization: @org, status: :draft)
    login_as(@user, portal: :user)
  end

  def prefix = "/org/#{@org.to_param}"

  test "GET collect_spec renders structured input fields for address and contacts" do
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/collect_spec",
      headers: {"Turbo-Frame" => "remote_modal"}
    assert_response :success
    assert_includes response.body, %(name="interaction[address][street]")
    assert_includes response.body, %(name="interaction[address][city]")
    assert_includes response.body, %(name="interaction[contacts][NEW_RECORD][label]")
    assert_includes response.body, %(name="interaction[contacts][NEW_RECORD][phone_number]")
  end

  test "POST collect_spec commits interaction and flash reflects cleaned contacts count" do
    post "#{prefix}/catalog/products/#{@product.id}/record_actions/collect_spec",
      params: {
        interaction: {
          address: {street: "123 Main St", city: "Springfield"},
          contacts: {
            "0" => {label: "Alice", phone_number: "555-1234"},
            "1" => {label: "", phone_number: ""}
          }
        }
      }
    # Successful interaction redirects (html format)
    assert_response :redirect
    follow_redirect!
    assert_match "Collected 1 contacts", flash[:notice]
  end
end
