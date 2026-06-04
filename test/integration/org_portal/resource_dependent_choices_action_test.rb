# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Regression: a record (or bulk) interactive action whose input `choices:` proc
# reads the action's subject used to 500 on every GET/POST. submitted_interaction_params
# built and rendered the interaction form on a throwaway instance that was never
# given the subject, so the proc ran against a nil resource and raised
# NoMethodError before the interaction was ever executed.
class OrgPortal::ResourceDependentChoicesActionTest < ActionDispatch::IntegrationTest
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

  test "GET record action with a resource-dependent select renders the materialized choices" do
    get "#{prefix}/catalog/products/#{@product.id}/record_actions/assign_reviewer",
      headers: {"Turbo-Frame" => "remote_modal"}

    assert_response :success
    assert_includes response.body, %(name="interaction[reviewer_id]")
    # Option built from the bound subject (`resource.user_id`).
    assert_includes response.body, %(value="#{@user.id}")
    assert_includes response.body, "#{@product.name} (owner)"
  end

  test "POST record action with a resource-dependent select extracts params and commits" do
    post "#{prefix}/catalog/products/#{@product.id}/record_actions/assign_reviewer",
      params: {interaction: {reviewer_id: @user.id.to_s}}

    assert_response :redirect
    follow_redirect!
    assert_match "Assigned reviewer", flash[:notice]
  end
end
