# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class OrgPortal::CatalogProductsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Catalog::Product, portal: :org

  setup do
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    @category = create_category!
    # Ensure category is visible via associated_with_organization scope
    create_product!(category: @category, user: @user, organization: @org)
    login_as(@user, portal: :user)
  end

  def current_path_prefix
    "/org/#{@org.to_param}"
  end

  def create_resource!
    create_product!(user: @user, organization: @org, category: @category)
  end

  def valid_create_params
    {name: "New Product",
     category: @category.to_sgid.to_s,
     user: @user.to_sgid.to_s,
     organization: @org.to_sgid.to_s,
     price_cents: 1999}
  end

  def valid_update_params
    {name: "Updated Product"}
  end

  # Nested resources
  test "lists variants for a product (has_many)" do
    product = create_resource!
    create_variant!(product: product)
    get "#{current_path_prefix}/catalog/products/#{product.id}/nested_variants"
    assert_response :success
  end

  test "lists reviews for a product (has_many)" do
    product = create_resource!
    create_review!(product: product)
    get "#{current_path_prefix}/catalog/products/#{product.id}/nested_reviews"
    assert_response :success
  end

  test "shows product detail (has_one)" do
    product = create_resource!
    create_product_detail!(product: product)
    get "#{current_path_prefix}/catalog/products/#{product.id}/nested_product_detail"
    assert_response :success
  end

  test "lists comments on a product (polymorphic)" do
    product = create_resource!
    create_comment!(commentable: product)
    get "#{current_path_prefix}/catalog/products/#{product.id}/nested_comments"
    assert_response :success
  end

  # Categories
  test "lists categories" do
    create_category!
    get "#{current_path_prefix}/catalog/categories"
    assert_response :success
  end

  test "shows a category (self-referential)" do
    parent = create_category!(name: "Parent")
    create_category!(name: "Child", parent: parent)
    create_product!(category: parent, user: @user, organization: @org)
    get "#{current_path_prefix}/catalog/categories/#{parent.id}"
    assert_response :success
  end

  # Reviews
  test "lists reviews" do
    product = create_resource!
    create_review!(product: product)
    get "#{current_path_prefix}/catalog/reviews"
    assert_response :success
  end

  # Tenant scoping
  test "scoping: only shows products from current organization" do
    my_product = create_resource!
    other_org = create_organization!
    other_product = create_product!(organization: other_org)

    get "#{current_path_prefix}/catalog/products"
    assert_response :success
    assert_match my_product.name, response.body
    refute_match other_product.name, response.body
  end
end
