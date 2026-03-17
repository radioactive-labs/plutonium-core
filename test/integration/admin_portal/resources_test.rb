# frozen_string_literal: true

require "test_helper"

class AdminPortal::ResourcesTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    login_as_admin(@admin)
  end

  # User CRUD
  test "admin: lists users" do
    get "/admin/users"
    assert_response :success
  end

  test "admin: shows a user" do
    get "/admin/users/#{@user.id}"
    assert_response :success
  end

  # Organization CRUD
  test "admin: lists organizations" do
    get "/admin/organizations"
    assert_response :success
  end

  test "admin: shows an organization" do
    get "/admin/organizations/#{@org.id}"
    assert_response :success
  end

  # Blog Posts
  test "admin: lists blog posts" do
    create_post!
    get "/admin/blogging/posts"
    assert_response :success
  end

  test "admin: shows a blog post" do
    post_record = create_post!
    get "/admin/blogging/posts/#{post_record.id}"
    assert_response :success
  end

  test "admin: renders new blog post form" do
    get "/admin/blogging/posts/new"
    assert_response :success
  end

  # STI
  test "admin: lists articles" do
    create_article!
    get "/admin/blogging/articles"
    assert_response :success
  end

  test "admin: lists tutorials" do
    create_tutorial!
    get "/admin/blogging/tutorials"
    assert_response :success
  end

  # Catalog
  test "admin: lists categories" do
    create_category!
    get "/admin/catalog/categories"
    assert_response :success
  end

  test "admin: lists products" do
    create_product!
    get "/admin/catalog/products"
    assert_response :success
  end

  test "admin: shows a product with has_cents" do
    product = create_product!(price_cents: 4999)
    get "/admin/catalog/products/#{product.id}"
    assert_response :success
  end

  test "admin: lists variants for a product" do
    product = create_product!
    create_variant!(product: product)
    get "/admin/catalog/products/#{product.id}/nested_variants"
    assert_response :success
  end

  test "admin: lists reviews" do
    product = create_product!
    create_review!(product: product)
    get "/admin/catalog/reviews"
    assert_response :success
  end

  # Tags
  test "admin: lists tags" do
    create_tag!
    get "/admin/blogging/tags"
    assert_response :success
  end

  # Comments (polymorphic)
  test "admin: lists comments" do
    post_record = create_post!
    create_comment!(commentable: post_record)
    get "/admin/comments"
    assert_response :success
  end
end
