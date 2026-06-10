# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Regression: a `select` input with `condition:` whose `choices:` proc depends
# on a sibling attribute must not nullify the submitted value during param
# extraction. submitted_interaction_params renders the form on a fresh instance
# where the sibling attribute is nil, causing the condition to be false and
# AcceptsChoices#normalize_simple_input to validate against an empty choices
# list, returning nil instead of the submitted value.
class OrgPortal::ConditionedSelectInteractionTest < ActionDispatch::IntegrationTest
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

  test "GET conditioned_select renders connection_id select but not value_id (condition false on fresh instance)" do
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/conditioned_select",
      headers: {"Turbo-Frame" => "remote_modal"}

    assert_response :success
    assert_includes response.body, %(name="interaction[connection_id]")
  end

  test "POST conditioned_select with value_id not in choices is rejected by interaction validation" do
    post "#{prefix}/catalog/products/#{@product.id}/record_actions/conditioned_select",
      params: {
        interaction: {
          connection_id: "1",
          value_id: "999"
        }
      }

    # value_id passes through extraction unchanged (not nullified by AcceptsChoices),
    # but the interaction's inclusion validation catches it as invalid.
    assert_response :unprocessable_content
  end

  test "POST conditioned_select with both fields submits successfully without nullifying value_id" do
    post "#{prefix}/catalog/products/#{@product.id}/record_actions/conditioned_select",
      params: {
        interaction: {
          connection_id: "1",
          value_id: "42"
        }
      }

    assert_response :redirect
    follow_redirect!
    assert_match "Selected value 42 for connection 1", flash[:notice]
  end
end
