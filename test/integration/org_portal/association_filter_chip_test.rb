# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Catalog::ReviewDefinition declares `filter :product, with: :association`.
# Products belong to an organization, so in the org portal a crafted
# `?q[product][value]=<another tenant's product id>` must not render that
# product's name in the active-filter chip.
class OrgPortal::AssociationFilterChipTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @own_product = create_product!(name: "Our Widget", organization: @org)
    @foreign_product = create_product!(name: "Rival Secret Widget", organization: create_organization!)
    login_as(@user, portal: :user)
  end

  def chips
    Nokogiri::HTML(response.body).css("[data-bulk-actions-target='filterPills'] span").map(&:text).join(" ")
  end

  test "the chip does not name another tenant's record" do
    get "/org/#{@org.to_param}/catalog/reviews", params: {q: {product: {value: @foreign_product.id}}}

    assert_response :success
    refute_includes response.body, "Rival Secret Widget"
  end

  test "the chip names the current tenant's record" do
    get "/org/#{@org.to_param}/catalog/reviews", params: {q: {product: {value: @own_product.id}}}

    assert_response :success
    assert_includes chips, "Our Widget"
  end
end
