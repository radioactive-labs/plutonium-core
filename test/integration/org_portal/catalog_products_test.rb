# frozen_string_literal: true

require "test_helper"

class OrgPortal::CatalogProductsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include SharedTests::CatalogProductTests

  setup do
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    login_as_user(@user)
  end

  def path_prefix
    "/org/#{@org.to_param}"
  end

  test "scoping: only shows products from current organization" do
    my_product = create_product!(organization: @org)
    other_org = create_organization!
    other_product = create_product!(organization: other_org)

    get "#{path_prefix}/catalog/products"
    assert_response :success
    assert_match my_product.name, response.body
    refute_match other_product.name, response.body
  end
end
