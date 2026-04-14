# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class LocusPortal::BloggingPostsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Blogging::Post, portal: :locus

  setup do
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    login_as(@user, portal: :user)
  end

  def create_resource!
    create_post!(user: @user, organization: @org)
  end

  def valid_create_params
    {title: "New Post", body: "New body", status: :draft,
     user: @user.to_sgid.to_s, organization: @org.to_sgid.to_s}
  end

  def valid_update_params
    {title: "Updated Title"}
  end

  # STI subtypes
  test "lists articles (STI subtype)" do
    create_article!(user: @user, organization: @org)
    get "/locus/blogging/articles"
    assert_response :success
  end

  test "shows an article (STI subtype)" do
    article = create_article!(user: @user, organization: @org)
    get "/locus/blogging/articles/#{article.id}"
    assert_response :success
  end

  test "lists tutorials (STI subtype)" do
    create_tutorial!(user: @user, organization: @org)
    get "/locus/blogging/tutorials"
    assert_response :success
  end

  test "shows a tutorial (STI subtype)" do
    tutorial = create_tutorial!(user: @user, organization: @org)
    get "/locus/blogging/tutorials/#{tutorial.id}"
    assert_response :success
  end

  # Nested resources
  test "lists comments on a post (polymorphic)" do
    post_record = create_post!(user: @user, organization: @org)
    create_comment!(commentable: post_record)
    get "/locus/blogging/posts/#{post_record.id}/nested_comments"
    assert_response :success
  end

  test "shows post detail (has_one)" do
    post_record = create_post!(user: @user, organization: @org)
    create_post_detail!(post: post_record)
    get "/locus/blogging/posts/#{post_record.id}/nested_post_detail"
    assert_response :success
  end

  test "lists post tags (has_many through)" do
    post_record = create_post!(user: @user, organization: @org)
    tag = create_tag!
    create_post_tag!(post: post_record, tag: tag)
    get "/locus/blogging/posts/#{post_record.id}/nested_post_tags"
    assert_response :success
  end

  # Tags
  test "lists tags" do
    create_tag!
    get "/locus/blogging/tags"
    assert_response :success
  end
end
