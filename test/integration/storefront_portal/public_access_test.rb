# frozen_string_literal: true

require "test_helper"

class StorefrontPortal::PublicAccessTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @org = create_organization!
    @user = create_user!
    # No login — public access
  end

  test "public: lists posts without auth" do
    create_post!(status: :published)
    get "/storefront/blogging/posts"
    assert_response :success
  end

  test "public: shows a post without auth" do
    post_record = create_post!(status: :published)
    get "/storefront/blogging/posts/#{post_record.id}"
    assert_response :success
  end

  test "public: lists products without auth" do
    create_product!(status: :active)
    get "/storefront/catalog/products"
    assert_response :success
  end

  test "public: shows a product without auth" do
    product = create_product!(status: :active)
    get "/storefront/catalog/products/#{product.id}"
    assert_response :success
  end

  test "public: lists categories without auth" do
    create_category!
    get "/storefront/catalog/categories"
    assert_response :success
  end

  test "public: new post form is denied" do
    get "/storefront/blogging/posts/new"
    assert_response :forbidden
  end

  test "public: creating a post is denied" do
    assert_no_difference -> { Blogging::Post.count } do
      post "/storefront/blogging/posts", params: {blogging_post: {title: "Hack", body: "Nope"}}
    end
    assert_response :forbidden
  end

  test "public: destroying a post is denied" do
    post_record = create_post!(status: :published)
    assert_no_difference -> { Blogging::Post.count } do
      delete "/storefront/blogging/posts/#{post_record.id}"
    end
    assert_response :forbidden
  end
end
