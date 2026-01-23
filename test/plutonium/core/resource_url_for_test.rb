# frozen_string_literal: true

require "test_helper"

class Plutonium::Core::ResourceUrlForTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com", status: :verified)
    @post = Blogging::Post.create!(user: @user, title: "Test Post", body: "Body content")
    @comment = Blogging::Comment.create!(user: @user, post: @post, body: "Test comment")
    @post_metadata = Blogging::PostMetadata.create!(post: @post, seo_title: "SEO Title")
  end

  teardown do
    Blogging::PostMetadata.delete_all
    Blogging::Comment.delete_all
    Blogging::Post.delete_all
    User.delete_all
  end

  # Top-level resources

  test "top-level: class" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post)
    assert_match %r{/demo/blogging/posts$}, url
  end

  test "top-level: instance" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}$}, url
  end

  test "top-level: instance + action :edit" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @post, action: :edit)
    assert_match %r{/demo/blogging/posts/#{@post.id}/edit$}, url
  end

  # Nested has_many: class

  test "has_many: class + parent" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  test "has_many: class + parent + association" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, association: :comments)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  test "has_many: class + parent + action :new" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, action: :new)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/new$}, url
  end

  # Nested has_many: instance

  test "has_many: instance + parent + association" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
  end

  test "has_many: instance + parent (no association)" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
  end

  test "has_many: instance + parent + action :edit" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments, action: :edit)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}/edit$}, url
  end

  # Nested has_many: symbol

  test "has_many: symbol + parent" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, :comments, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  # Nested has_one: class (defaults to :new)

  test "has_one: class + parent + association" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostMetadata, parent: @post, association: :post_metadata)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata/new$}, url
    refute_match %r{/post_metadata/\d+}, url
  end

  test "has_one: class + parent (no association)" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostMetadata, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata/new$}, url
    refute_match %r{/post_metadata/\d+}, url
  end

  test "has_one: class + parent + action :show" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostMetadata, parent: @post, association: :post_metadata, action: :show)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata$}, url
    refute_match %r{/new}, url
    refute_match %r{/post_metadata/\d+}, url
  end

  test "has_one: class + parent + action :new" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostMetadata, parent: @post, association: :post_metadata, action: :new)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata/new$}, url
    refute_match %r{/post_metadata/\d+}, url
  end

  # Nested has_one: nil (defaults to :new)

  test "has_one: nil + parent + association" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, nil, parent: @post, association: :post_metadata)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata/new$}, url
    refute_match %r{/post_metadata/\d+}, url
  end

  # Nested has_one: instance

  test "has_one: instance + parent + association" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_metadata, parent: @post, association: :post_metadata)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata$}, url
    refute_match %r{/post_metadata/\d+}, url
    refute_match %r{/#{@post_metadata.id}($|\?)}, url
  end

  test "has_one: instance + parent (no association)" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_metadata, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata$}, url
    refute_match %r{/post_metadata/\d+}, url
    refute_match %r{/#{@post_metadata.id}($|\?)}, url
  end

  test "has_one: instance + parent + action :edit" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_metadata, parent: @post, association: :post_metadata, action: :edit)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata/edit$}, url
    refute_match %r{/post_metadata/\d+}, url
  end

  # Nested has_one: symbol (defaults to :new)

  test "has_one: symbol + parent" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, :post_metadata, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata/new$}, url
    refute_match %r{/post_metadata/\d+}, url
  end

  test "has_one: symbol + parent + action :show" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, :post_metadata, parent: @post, action: :show)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata$}, url
    refute_match %r{/new}, url
  end

  # Route config

  test "route config: has_many is :resources" do
    config = DemoPortal::Engine.routes.resource_route_config_for("blogging_posts/comments")[0]
    assert_equal :resources, config[:route_type]
    assert_equal :comments, config[:association_name]
  end

  test "route config: has_one is :resource" do
    config = DemoPortal::Engine.routes.resource_route_config_for("blogging_posts/post_metadata")[0]
    assert_equal :resource, config[:route_type]
    assert_equal :post_metadata, config[:association_name]
  end

  # Package option

  test "package: generates URL for different package" do
    get "/demo/blogging/posts/#{@post.id}"
    # From DemoPortal context, generate URL for AdminPortal
    url = controller.send(:resource_url_for, @post, package: AdminPortal)
    assert_match %r{/admin/blogging/posts/#{@post.id}$}, url
    refute_match %r{/demo/}, url
  end

  test "package: nested resource with different package" do
    get "/demo/blogging/posts/#{@post.id}"
    # From DemoPortal context, generate nested URL for AdminPortal
    url = controller.send(:resource_url_for, @comment, parent: @post, package: AdminPortal)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
    refute_match %r{/demo/}, url
  end

  test "package: has_one with different package" do
    get "/demo/blogging/posts/#{@post.id}"
    # From DemoPortal context, generate has_one URL for AdminPortal
    url = controller.send(:resource_url_for, @post_metadata, parent: @post, package: AdminPortal)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_metadata$}, url
    refute_match %r{/demo/}, url
  end
end
