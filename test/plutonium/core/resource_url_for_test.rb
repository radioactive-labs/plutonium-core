# frozen_string_literal: true

require "test_helper"

class Plutonium::Core::ResourceUrlForTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    @user = create_user!
    @org = create_organization!(name: "Test Org")
    @membership = create_membership!(organization: @org, user: @user)

    @post = Blogging::Post.create!(
      user: @user, author: @user, title: "Test Post", body: "Body content",
      organization: @org, status: :draft
    )
    @comment = Comment.create!(commentable: @post, user: @user, body: "Test comment")
    @post_detail = Blogging::PostDetail.create!(post: @post, seo_title: "SEO Title")
    @category = Catalog::Category.create!(name: "Test Category")
    @product = Catalog::Product.create!(
      name: "Test Product", category: @category, user: @user,
      organization: @org, price_cents: 999
    )
    @product_metadata = Catalog::ProductMetadata.create!(product: @product, meta_title: "SEO Title")
  end

  # Top-level resources

  test "top-level: class" do
    login_as_admin
    get "/admin/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post)
    assert_match %r{/admin/blogging/posts$}, url
  end

  test "top-level: instance" do
    login_as_admin
    get "/admin/blogging/posts"
    url = controller.send(:resource_url_for, @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}$}, url
  end

  test "top-level: instance + action :edit" do
    login_as_admin
    get "/admin/blogging/posts"
    url = controller.send(:resource_url_for, @post, action: :edit)
    assert_match %r{/admin/blogging/posts/#{@post.id}/edit$}, url
  end

  # Nested has_many: class

  test "has_many: class + parent" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  test "has_many: class + parent + association" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post, association: :comments)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  test "has_many: class + parent + action :new" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post, action: :new)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/new$}, url
  end

  test "has_many: class + parent + action :create" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post, action: :create)
    # :create uses collection path (HTTP POST determines create vs index)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  # Nested has_many: instance

  test "has_many: instance + parent + association" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
  end

  test "has_many: instance + parent (no association)" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
  end

  test "has_many: instance + parent + action :edit" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments, action: :edit)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}/edit$}, url
  end

  test "has_many: new instance + parent + action :create" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    new_comment = Comment.new(commentable: @post)
    url = controller.send(:resource_url_for, new_comment, parent: @post, association: :comments, action: :create)
    # :create with new record uses collection path (no ID)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  test "has_many: instance + parent + action :update" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments, action: :update)
    # :update uses member path (HTTP PATCH/PUT determines update)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
  end

  # Nested has_many: symbol

  test "has_many: symbol + parent" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, :comments, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  # Nested has_one: class (defaults to :new)

  test "has_one: class + parent + association" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostDetail, parent: @post, association: :post_detail)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail/new$}, url
    refute_match %r{/post_detail/\d+}, url
  end

  test "has_one: class + parent (no association)" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostDetail, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail/new$}, url
    refute_match %r{/post_detail/\d+}, url
  end

  test "has_one: class + parent + action :show" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostDetail, parent: @post, association: :post_detail, action: :show)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail$}, url
    refute_match %r{/new}, url
    refute_match %r{/post_detail/\d+}, url
  end

  test "has_one: class + parent + action :new" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::PostDetail, parent: @post, association: :post_detail, action: :new)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail/new$}, url
    refute_match %r{/post_detail/\d+}, url
  end

  # Nested has_one: nil (defaults to :new)

  test "has_one: nil + parent + association" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, nil, parent: @post, association: :post_detail)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail/new$}, url
    refute_match %r{/post_detail/\d+}, url
  end

  # Nested has_one: instance

  test "has_one: instance + parent + association" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_detail, parent: @post, association: :post_detail)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail$}, url
    refute_match %r{/post_detail/\d+}, url
    refute_match %r{/#{@post_detail.id}($|\?)}, url
  end

  test "has_one: instance + parent (no association)" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_detail, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail$}, url
    refute_match %r{/post_detail/\d+}, url
    refute_match %r{/#{@post_detail.id}($|\?)}, url
  end

  test "has_one: instance + parent + action :edit" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_detail, parent: @post, association: :post_detail, action: :edit)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail/edit$}, url
    refute_match %r{/post_detail/\d+}, url
  end

  # Nested has_one: symbol (defaults to :new)

  test "has_one: symbol + parent" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, :post_detail, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail/new$}, url
    refute_match %r{/post_detail/\d+}, url
  end

  test "has_one: symbol + parent + action :show" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, :post_detail, parent: @post, action: :show)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail$}, url
    refute_match %r{/new}, url
  end

  # Nested has_one (uncountable): class auto-resolution
  # "metadata" is uncountable — plural == singular, so auto-resolution works via plural candidate

  test "has_one uncountable: class + parent (no association)" do
    login_as_admin
    get "/admin/catalog/products/#{@product.id}"
    url = controller.send(:resource_url_for, Catalog::ProductMetadata, parent: @product)
    assert_match %r{/admin/catalog/products/#{@product.id}/nested_product_metadata/new$}, url
  end

  test "has_one uncountable: instance + parent (no association)" do
    login_as_admin
    get "/admin/catalog/products/#{@product.id}"
    url = controller.send(:resource_url_for, @product_metadata, parent: @product)
    assert_match %r{/admin/catalog/products/#{@product.id}/nested_product_metadata$}, url
    refute_match %r{/#{@product_metadata.id}($|\?)}, url
  end

  test "has_one uncountable: instance + parent + action :edit" do
    login_as_admin
    get "/admin/catalog/products/#{@product.id}"
    url = controller.send(:resource_url_for, @product_metadata, parent: @product, action: :edit)
    assert_match %r{/admin/catalog/products/#{@product.id}/nested_product_metadata/edit$}, url
  end

  test "has_one uncountable: symbol + parent" do
    login_as_admin
    get "/admin/catalog/products/#{@product.id}"
    url = controller.send(:resource_url_for, :product_metadata, parent: @product)
    assert_match %r{/admin/catalog/products/#{@product.id}/nested_product_metadata/new$}, url
  end

  # Singular parent + has_many nested routes (unscoped)
  # LocusPortal registers User as singular: true, and User has_many :authored_posts

  test "singular parent: has_many class + parent" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts)
    assert_match %r{/locus/user/nested_authored_posts$}, url
    refute_match %r{/user/\d+/}, url
  end

  test "singular parent: has_many instance + parent" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts)
    assert_match %r{/locus/user/nested_authored_posts/#{@post.id}$}, url
    refute_match %r{/user/\d+/nested}, url
  end

  test "singular parent: has_many instance + parent (no association)" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts)
    assert_match %r{/locus/user/nested_authored_posts/#{@post.id}$}, url
  end

  test "singular parent: has_many instance + parent + action :edit" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :edit)
    assert_match %r{/locus/user/nested_authored_posts/#{@post.id}/edit$}, url
  end

  test "singular parent: has_many class + parent + action :new" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :new)
    assert_match %r{/locus/user/nested_authored_posts/new$}, url
  end

  test "singular parent: has_many class + parent + action :create" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :create)
    assert_match %r{/locus/user/nested_authored_posts$}, url
  end

  test "singular parent: has_many instance + parent + action :update" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :update)
    assert_match %r{/locus/user/nested_authored_posts/#{@post.id}$}, url
  end

  test "singular parent: has_many new instance + parent + action :create" do
    login_as_user
    get "/locus/blogging/posts"
    new_post = Blogging::Post.new
    url = controller.send(:resource_url_for, new_post, parent: @user, association: :authored_posts, action: :create)
    assert_match %r{/locus/user/nested_authored_posts$}, url
  end

  test "singular parent: has_many symbol + parent" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, :authored_posts, parent: @user)
    assert_match %r{/locus/user/nested_authored_posts$}, url
  end

  test "singular parent: has_many instance + action :interactive_record_action" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :interactive_record_action, interactive_action: :archive)
    assert_match %r{/locus/user/nested_authored_posts/#{@post.id}/record_actions/archive$}, url
  end

  test "singular parent: has_many class + action :interactive_bulk_action" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/locus/user/nested_authored_posts/bulk_actions/bulk_delete$}, url
  end

  test "singular parent: has_many class + action :interactive_resource_action" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :interactive_resource_action, interactive_action: :import)
    assert_match %r{/locus/user/nested_authored_posts/resource_actions/import$}, url
  end

  # Commit actions on singular parent

  test "singular parent: has_many instance + action :commit_interactive_record_action" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :commit_interactive_record_action, interactive_action: :archive)
    assert_match %r{/locus/user/nested_authored_posts/#{@post.id}/record_actions/archive$}, url
  end

  test "singular parent: has_many class + action :commit_interactive_bulk_action" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :commit_interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/locus/user/nested_authored_posts/bulk_actions/bulk_delete$}, url
  end

  test "singular parent: has_many class + action :commit_interactive_resource_action" do
    login_as_user
    get "/locus/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :commit_interactive_resource_action, interactive_action: :import)
    assert_match %r{/locus/user/nested_authored_posts/resource_actions/import$}, url
  end

  test "singular parent: route config" do
    config = LocusPortal::Engine.routes.resource_route_config_for("users")[0]
    assert_equal :resource, config[:route_type]

    nested_config = LocusPortal::Engine.routes.resource_route_config_for("users/authored_posts")[0]
    assert_equal :resources, nested_config[:route_type]
    assert_equal :authored_posts, nested_config[:association_name]
  end

  # Singular parent + has_one nested routes
  # OrgPortal registers User as singular: true, and User has_one :user_profile

  test "singular parent + has_one: class + parent defaults to :new" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, UserProfile, parent: @user, association: :user_profile)
    assert_match %r{/org/#{@org.to_param}/user/nested_user_profile/new$}, url
    refute_match %r{/user/\d+/}, url
  end

  test "singular parent + has_one: instance + parent" do
    @profile = UserProfile.create!(user: @user, display_name: "Test")
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, @profile, parent: @user, association: :user_profile)
    assert_match %r{/org/#{@org.to_param}/user/nested_user_profile$}, url
    refute_match %r{/nested_user_profile/\d+}, url
  end

  test "singular parent + has_one: instance + parent + action :edit" do
    @profile = UserProfile.create!(user: @user, display_name: "Test")
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, @profile, parent: @user, association: :user_profile, action: :edit)
    assert_match %r{/org/#{@org.to_param}/user/nested_user_profile/edit$}, url
    refute_match %r{/nested_user_profile/\d+}, url
  end

  test "singular parent + has_one: class + parent + action :show" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, UserProfile, parent: @user, association: :user_profile, action: :show)
    assert_match %r{/org/#{@org.to_param}/user/nested_user_profile$}, url
    refute_match %r{/new}, url
  end

  test "singular parent + has_one: nil + parent + association" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, nil, parent: @user, association: :user_profile)
    assert_match %r{/org/#{@org.to_param}/user/nested_user_profile/new$}, url
    refute_match %r{/user/\d+/}, url
  end

  test "singular parent + has_one: symbol + parent" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, :user_profile, parent: @user)
    assert_match %r{/org/#{@org.to_param}/user/nested_user_profile/new$}, url
    refute_match %r{/user/\d+/}, url
  end

  test "singular parent + has_one: symbol + parent + action :show" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, :user_profile, parent: @user, action: :show)
    assert_match %r{/org/#{@org.to_param}/user/nested_user_profile$}, url
    refute_match %r{/new}, url
  end

  # Route config

  test "route config: has_many is :resources" do
    config = AdminPortal::Engine.routes.resource_route_config_for("blogging_posts/comments")[0]
    assert_equal :resources, config[:route_type]
    assert_equal :comments, config[:association_name]
  end

  test "route config: has_one is :resource" do
    config = AdminPortal::Engine.routes.resource_route_config_for("blogging_posts/post_detail")[0]
    assert_equal :resource, config[:route_type]
    assert_equal :post_detail, config[:association_name]
  end

  # Package option

  test "package: generates URL for different package" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    # From AdminPortal context, generate URL for LocusPortal
    url = controller.send(:resource_url_for, @post, package: LocusPortal)
    assert_match %r{/locus/blogging/posts/#{@post.id}$}, url
    refute_match %r{/admin/}, url
  end

  test "package: nested resource with different package" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    # From AdminPortal context, generate nested URL for LocusPortal
    url = controller.send(:resource_url_for, @comment, parent: @post, package: LocusPortal)
    assert_match %r{/locus/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
    refute_match %r{/admin/}, url
  end

  test "package: has_one with different package" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    # From AdminPortal context, generate has_one URL for LocusPortal
    url = controller.send(:resource_url_for, @post_detail, parent: @post, package: LocusPortal)
    assert_match %r{/locus/blogging/posts/#{@post.id}/nested_post_detail$}, url
    refute_match %r{/admin/}, url
  end

  # Interactive actions on nested resources

  test "has_many: instance + parent + action :interactive_record_action" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, action: :interactive_record_action, interactive_action: :archive)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}/record_actions/archive$}, url
  end

  test "has_many: class + parent + action :interactive_bulk_action" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post, action: :interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/bulk_actions/bulk_delete$}, url
  end

  test "has_many: class + parent + action :interactive_resource_action" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post, action: :interactive_resource_action, interactive_action: :import)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/resource_actions/import$}, url
  end

  test "has_one: instance + parent + action :interactive_record_action" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_detail, parent: @post, action: :interactive_record_action, interactive_action: :refresh)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_post_detail/record_actions/refresh$}, url
    # has_one uses singular path: /nested_post_detail/record_actions/refresh (no id segment)
    refute_match %r{/nested_post_detail/\d+/}, url
  end

  # Top-level interactive actions

  test "top-level: instance + action :interactive_record_action" do
    login_as_admin
    get "/admin/blogging/posts"
    url = controller.send(:resource_url_for, @post, action: :interactive_record_action, interactive_action: :publish)
    assert_match %r{/admin/blogging/posts/#{@post.id}/record_actions/publish$}, url
  end

  test "top-level: class + action :interactive_bulk_action" do
    login_as_admin
    get "/admin/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, action: :interactive_bulk_action, interactive_action: :bulk_publish)
    assert_match %r{/admin/blogging/posts/bulk_actions/bulk_publish$}, url
  end

  test "top-level: class + action :interactive_resource_action" do
    login_as_admin
    get "/admin/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, action: :interactive_resource_action, interactive_action: :export)
    assert_match %r{/admin/blogging/posts/resource_actions/export$}, url
  end

  # Commit actions (POST) use same path as GET actions

  test "has_many: instance + parent + action :commit_interactive_record_action" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, action: :commit_interactive_record_action, interactive_action: :archive)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}/record_actions/archive$}, url
  end

  test "has_many: class + parent + action :commit_interactive_bulk_action" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post, action: :commit_interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/bulk_actions/bulk_delete$}, url
  end

  test "has_many: class + parent + action :commit_interactive_resource_action" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Comment, parent: @post, action: :commit_interactive_resource_action, interactive_action: :import)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/resource_actions/import$}, url
  end

  # Singular resource default actions

  test "top-level: class for plural resources defaults to :index action" do
    login_as_admin
    get "/admin/blogging/posts"
    # Verify route config is :resources
    config = AdminPortal::Engine.routes.resource_route_config_for("blogging_posts")[0]
    assert_equal :resources, config[:route_type]

    url = controller.send(:resource_url_for, Blogging::Post)
    # Should generate index URL (no /show suffix, just the collection)
    assert_match %r{/admin/blogging/posts$}, url
  end

  # Note: singular_resource_route? logic for defaulting to :show is tested in nested_routes_test.rb
  # Testing top-level singular resources here would require actual route setup

  # to_param encoding

  test "instance with custom to_param is properly encoded in URL" do
    login_as_admin
    get "/admin/blogging/posts"

    # Override to_param on the instance
    @post.define_singleton_method(:to_param) { "#{id}-#{title.parameterize}" }

    url = controller.send(:resource_url_for, @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}-test-post$}, url
  end

  test "nested instance with custom to_param is properly encoded" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"

    @comment.define_singleton_method(:to_param) { "comment-#{id}" }

    url = controller.send(:resource_url_for, @comment, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}/nested_comments/comment-#{@comment.id}$}, url
  end

  test "parent with custom to_param is properly encoded in nested URL" do
    login_as_admin
    get "/admin/blogging/posts/#{@post.id}"

    @post.define_singleton_method(:to_param) { "#{id}-#{title.parameterize}" }

    url = controller.send(:resource_url_for, @comment, parent: @post)
    assert_match %r{/admin/blogging/posts/#{@post.id}-test-post/nested_comments/#{@comment.id}$}, url
  end

  # Note: scoped entity to_param encoding is tested via the parent to_param test above.
  # The implementation (url_args[scoped_entity_param_key] = current_scoped_entity.to_param)
  # uses the same to_param pattern that is tested for parents and instances.

  # Entity-scoped (path strategy) + singular parent resource
  # OrgPortal scopes to Organization with :path strategy and registers User as singular

  test "entity-scoped + singular parent: has_many class + parent" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts$}, url
  end

  test "entity-scoped + singular parent: has_many instance + parent" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts/#{@post.id}$}, url
  end

  test "entity-scoped + singular parent: has_many instance + parent + action :edit" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :edit)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts/#{@post.id}/edit$}, url
  end

  test "entity-scoped + singular parent: has_many class + parent + action :new" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :new)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts/new$}, url
  end

  test "entity-scoped + singular parent: has_many class + parent + action :create" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :create)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts$}, url
  end

  test "entity-scoped + singular parent: has_many instance + parent + action :update" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :update)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts/#{@post.id}$}, url
  end

  test "entity-scoped + singular parent: has_many instance + action :interactive_record_action" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :interactive_record_action, interactive_action: :archive)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts/#{@post.id}/record_actions/archive$}, url
  end

  test "entity-scoped + singular parent: has_many class + action :interactive_bulk_action" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts/bulk_actions/bulk_delete$}, url
  end

  test "entity-scoped + singular parent: has_many class + action :interactive_resource_action" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :interactive_resource_action, interactive_action: :import)
    assert_match %r{/org/#{@org.to_param}/user/nested_authored_posts/resource_actions/import$}, url
  end

  test "entity-scoped + plural parent: has_many instance + parent" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments)
    assert_match %r{/org/#{@org.to_param}/blogging/posts/#{@post.to_param}/nested_comments/#{@comment.id}$}, url
  end

  test "entity-scoped + plural parent: has_many class + parent + action :new" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, Comment, parent: @post, association: :comments, action: :new)
    assert_match %r{/org/#{@org.to_param}/blogging/posts/#{@post.to_param}/nested_comments/new$}, url
  end

  test "entity-scoped + plural parent: has_many class + parent + action :create" do
    login_as_user
    get "/org/#{@org.to_param}"
    url = controller.send(:resource_url_for, Comment, parent: @post, association: :comments, action: :create)
    assert_match %r{/org/#{@org.to_param}/blogging/posts/#{@post.to_param}/nested_comments$}, url
  end
end
