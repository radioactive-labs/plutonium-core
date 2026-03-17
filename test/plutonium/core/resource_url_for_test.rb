# frozen_string_literal: true

require "test_helper"

class Plutonium::Core::ResourceUrlForTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "test@example.com", status: :verified)
    @post = Blogging::Post.create!(user: @user, title: "Test Post", body: "Body content")
    @comment = Blogging::Comment.create!(user: @user, post: @post, body: "Test comment")
    @post_metadata = Blogging::PostMetadata.create!(post: @post, seo_title: "SEO Title")
    @category = DemoFeatures::Category.create!(name: "Test Category")
    @organization = Organization.create!(name: "Test Org")
  end

  teardown do
    DemoFeatures::MorphDemo.delete_all
    DemoFeatures::Product.delete_all
    DemoFeatures::Category.delete_all
    Organization.delete_all
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

  test "has_many: class + parent + action :create" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, action: :create)
    # :create uses collection path (HTTP POST determines create vs index)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments$}, url
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

  test "has_many: new instance + parent + action :create" do
    get "/demo/blogging/posts/#{@post.id}"
    new_comment = Blogging::Comment.new(post: @post)
    url = controller.send(:resource_url_for, new_comment, parent: @post, association: :comments, action: :create)
    # :create with new record uses collection path (no ID)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments$}, url
  end

  test "has_many: instance + parent + action :update" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments, action: :update)
    # :update uses member path (HTTP PATCH/PUT determines update)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}$}, url
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

  # Interactive actions on nested resources

  test "has_many: instance + parent + action :interactive_record_action" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, action: :interactive_record_action, interactive_action: :archive)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}/record_actions/archive$}, url
  end

  test "has_many: class + parent + action :interactive_bulk_action" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, action: :interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/bulk_actions/bulk_delete$}, url
  end

  test "has_many: class + parent + action :interactive_resource_action" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, action: :interactive_resource_action, interactive_action: :import)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/resource_actions/import$}, url
  end

  test "has_one: instance + parent + action :interactive_record_action" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @post_metadata, parent: @post, action: :interactive_record_action, interactive_action: :refresh)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_post_metadata/record_actions/refresh$}, url
    # has_one uses singular path: /nested_post_metadata/record_actions/refresh (no id segment)
    refute_match %r{/nested_post_metadata/\d+/}, url
  end

  # Top-level interactive actions

  test "top-level: instance + action :interactive_record_action" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @post, action: :interactive_record_action, interactive_action: :publish)
    assert_match %r{/demo/blogging/posts/#{@post.id}/record_actions/publish$}, url
  end

  test "top-level: class + action :interactive_bulk_action" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, action: :interactive_bulk_action, interactive_action: :bulk_publish)
    assert_match %r{/demo/blogging/posts/bulk_actions/bulk_publish$}, url
  end

  test "top-level: class + action :interactive_resource_action" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, Blogging::Post, action: :interactive_resource_action, interactive_action: :export)
    assert_match %r{/demo/blogging/posts/resource_actions/export$}, url
  end

  # Commit actions (POST) use same path as GET actions

  test "has_many: instance + parent + action :commit_interactive_record_action" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, @comment, parent: @post, action: :commit_interactive_record_action, interactive_action: :archive)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/#{@comment.id}/record_actions/archive$}, url
  end

  test "has_many: class + parent + action :commit_interactive_bulk_action" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, action: :commit_interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/bulk_actions/bulk_delete$}, url
  end

  test "has_many: class + parent + action :commit_interactive_resource_action" do
    get "/demo/blogging/posts/#{@post.id}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, action: :commit_interactive_resource_action, interactive_action: :import)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/resource_actions/import$}, url
  end

  # Singular resource default actions

  test "top-level: class for plural resources defaults to :index action" do
    get "/demo/blogging/posts"
    # Verify route config is :resources
    config = DemoPortal::Engine.routes.resource_route_config_for("blogging_posts")[0]
    assert_equal :resources, config[:route_type]

    url = controller.send(:resource_url_for, Blogging::Post)
    # Should generate index URL (no /show suffix, just the collection)
    assert_match %r{/demo/blogging/posts$}, url
  end

  # Note: singular_resource_route? logic for defaulting to :show is tested in nested_routes_test.rb
  # Testing top-level singular resources here would require actual route setup

  # to_param encoding

  test "instance with custom to_param is properly encoded in URL" do
    get "/demo/blogging/posts"

    # Override to_param on the instance
    @post.define_singleton_method(:to_param) { "#{id}-#{title.parameterize}" }

    url = controller.send(:resource_url_for, @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}-test-post$}, url
  end

  test "nested instance with custom to_param is properly encoded" do
    get "/demo/blogging/posts/#{@post.id}"

    @comment.define_singleton_method(:to_param) { "comment-#{id}" }

    url = controller.send(:resource_url_for, @comment, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}/nested_comments/comment-#{@comment.id}$}, url
  end

  test "parent with custom to_param is properly encoded in nested URL" do
    get "/demo/blogging/posts/#{@post.id}"

    @post.define_singleton_method(:to_param) { "#{id}-#{title.parameterize}" }

    url = controller.send(:resource_url_for, @comment, parent: @post)
    assert_match %r{/demo/blogging/posts/#{@post.id}-test-post/nested_comments/#{@comment.id}$}, url
  end

  # Note: scoped entity to_param encoding is tested via the parent to_param test above.
  # The implementation (url_args[scoped_entity_param_key] = current_scoped_entity.to_param)
  # uses the same to_param pattern that is tested for parents and instances.

  # Singular parent resource nested routes
  # DemoPortal registers Category as singular: true, and Category has_many :products

  test "singular parent: has_many class + parent" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products)
    assert_match %r{/demo/demo_features_category/nested_products$}, url
    refute_match %r{/demo_features_category/\d+/}, url
  end

  test "singular parent: has_many instance + parent" do
    @product = create_product!(sku: "WDG-001", category: @category)
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @product, parent: @category, association: :products)
    assert_match %r{/demo/demo_features_category/nested_products/#{@product.id}$}, url
    refute_match %r{/demo_features_category/\d+/nested}, url
  end

  test "singular parent: has_many instance + parent (no association)" do
    @product = create_product!(sku: "WDG-001B", category: @category)
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @product, parent: @category)
    assert_match %r{/demo/demo_features_category/nested_products/#{@product.id}$}, url
  end

  test "singular parent: has_many instance + parent + action :edit" do
    @product = create_product!(sku: "WDG-002", category: @category)
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @product, parent: @category, association: :products, action: :edit)
    assert_match %r{/demo/demo_features_category/nested_products/#{@product.id}/edit$}, url
  end

  test "singular parent: has_many class + parent + action :new" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products, action: :new)
    assert_match %r{/demo/demo_features_category/nested_products/new$}, url
  end

  test "singular parent: has_many class + parent + action :create" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products, action: :create)
    assert_match %r{/demo/demo_features_category/nested_products$}, url
  end

  test "singular parent: has_many instance + parent + action :update" do
    @product = create_product!(sku: "WDG-003", category: @category)
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @product, parent: @category, association: :products, action: :update)
    assert_match %r{/demo/demo_features_category/nested_products/#{@product.id}$}, url
  end

  test "singular parent: has_many new instance + parent + action :create" do
    get "/demo/blogging/posts"
    new_product = DemoFeatures::Product.new(category: @category)
    url = controller.send(:resource_url_for, new_product, parent: @category, association: :products, action: :create)
    assert_match %r{/demo/demo_features_category/nested_products$}, url
  end

  test "singular parent: has_many symbol + parent" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, :products, parent: @category)
    assert_match %r{/demo/demo_features_category/nested_products$}, url
  end

  test "singular parent: has_many instance + action :interactive_record_action" do
    @product = create_product!(sku: "WDG-004", category: @category)
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @product, parent: @category, association: :products, action: :interactive_record_action, interactive_action: :archive)
    assert_match %r{/demo/demo_features_category/nested_products/#{@product.id}/record_actions/archive$}, url
  end

  test "singular parent: has_many class + action :interactive_bulk_action" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products, action: :interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/demo/demo_features_category/nested_products/bulk_actions/bulk_delete$}, url
  end

  test "singular parent: has_many class + action :interactive_resource_action" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products, action: :interactive_resource_action, interactive_action: :import)
    assert_match %r{/demo/demo_features_category/nested_products/resource_actions/import$}, url
  end

  # Commit actions on singular parent

  test "singular parent: has_many instance + action :commit_interactive_record_action" do
    @product = create_product!(sku: "WDG-005", category: @category)
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @product, parent: @category, association: :products, action: :commit_interactive_record_action, interactive_action: :archive)
    assert_match %r{/demo/demo_features_category/nested_products/#{@product.id}/record_actions/archive$}, url
  end

  test "singular parent: has_many class + action :commit_interactive_bulk_action" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products, action: :commit_interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/demo/demo_features_category/nested_products/bulk_actions/bulk_delete$}, url
  end

  test "singular parent: has_many class + action :commit_interactive_resource_action" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products, action: :commit_interactive_resource_action, interactive_action: :import)
    assert_match %r{/demo/demo_features_category/nested_products/resource_actions/import$}, url
  end

  # Singular parent + has_one nested routes
  # DemoPortal registers Category as singular: true, and Category has_one :morph_demo

  test "singular parent + has_one: class + parent defaults to :new" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::MorphDemo, parent: @category, association: :morph_demo)
    assert_match %r{/demo/demo_features_category/nested_morph_demo/new$}, url
    refute_match %r{/demo_features_category/\d+/}, url
  end

  test "singular parent + has_one: instance + parent" do
    @morph = DemoFeatures::MorphDemo.create!(category: @category, name: "Test", record_type: :simple, status: "active")
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @morph, parent: @category, association: :morph_demo)
    assert_match %r{/demo/demo_features_category/nested_morph_demo$}, url
    refute_match %r{/nested_morph_demo/\d+}, url
  end

  test "singular parent + has_one: instance + parent + action :edit" do
    @morph = DemoFeatures::MorphDemo.create!(category: @category, name: "Test", record_type: :simple, status: "active")
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @morph, parent: @category, association: :morph_demo, action: :edit)
    assert_match %r{/demo/demo_features_category/nested_morph_demo/edit$}, url
    refute_match %r{/nested_morph_demo/\d+}, url
  end

  test "singular parent + has_one: class + parent + action :show" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::MorphDemo, parent: @category, association: :morph_demo, action: :show)
    assert_match %r{/demo/demo_features_category/nested_morph_demo$}, url
    refute_match %r{/new}, url
  end

  test "singular parent + has_one: nil + parent + association" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, nil, parent: @category, association: :morph_demo)
    assert_match %r{/demo/demo_features_category/nested_morph_demo/new$}, url
    refute_match %r{/demo_features_category/\d+/}, url
  end

  test "singular parent + has_one: symbol + parent" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, :morph_demo, parent: @category)
    assert_match %r{/demo/demo_features_category/nested_morph_demo/new$}, url
    refute_match %r{/demo_features_category/\d+/}, url
  end

  test "singular parent + has_one: symbol + parent + action :show" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, :morph_demo, parent: @category, action: :show)
    assert_match %r{/demo/demo_features_category/nested_morph_demo$}, url
    refute_match %r{/new}, url
  end

  # Entity-scoped (path strategy) + singular parent resource
  # OrgPortal scopes to Organization with :path strategy and registers User as singular

  test "entity-scoped + singular parent: has_many class + parent" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts$}, url
  end

  test "entity-scoped + singular parent: has_many instance + parent" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts/#{@post.id}$}, url
  end

  test "entity-scoped + singular parent: has_many instance + parent + action :edit" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :edit)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts/#{@post.id}/edit$}, url
  end

  test "entity-scoped + singular parent: has_many class + parent + action :new" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :new)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts/new$}, url
  end

  test "entity-scoped + singular parent: has_many class + parent + action :create" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :create)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts$}, url
  end

  test "entity-scoped + singular parent: has_many instance + parent + action :update" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :update)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts/#{@post.id}$}, url
  end

  test "entity-scoped + singular parent: has_many instance + action :interactive_record_action" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, @post, parent: @user, association: :authored_posts, action: :interactive_record_action, interactive_action: :archive)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts/#{@post.id}/record_actions/archive$}, url
  end

  test "entity-scoped + singular parent: has_many class + action :interactive_bulk_action" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :interactive_bulk_action, interactive_action: :bulk_delete)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts/bulk_actions/bulk_delete$}, url
  end

  test "entity-scoped + singular parent: has_many class + action :interactive_resource_action" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, Blogging::Post, parent: @user, association: :authored_posts, action: :interactive_resource_action, interactive_action: :import)
    assert_match %r{/org/#{@organization.to_param}/user/nested_authored_posts/resource_actions/import$}, url
  end

  test "entity-scoped + plural parent: has_many instance + parent" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, @comment, parent: @post, association: :comments)
    assert_match %r{/org/#{@organization.to_param}/blogging/posts/#{@post.to_param}/nested_comments/#{@comment.id}$}, url
  end

  test "entity-scoped + plural parent: has_many class + parent + action :new" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, association: :comments, action: :new)
    assert_match %r{/org/#{@organization.to_param}/blogging/posts/#{@post.to_param}/nested_comments/new$}, url
  end

  test "entity-scoped + plural parent: has_many class + parent + action :create" do
    get "/org/#{@organization.to_param}"
    url = controller.send(:resource_url_for, Blogging::Comment, parent: @post, association: :comments, action: :create)
    assert_match %r{/org/#{@organization.to_param}/blogging/posts/#{@post.to_param}/nested_comments$}, url
  end

  # Package option with singular parent

  test "package: singular parent nested resource with different package" do
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, DemoFeatures::Product, parent: @category, association: :products, package: AdminPortal)
    assert_match %r{/admin/demo_features_category/nested_products$}, url
    refute_match %r{/demo/}, url
  end

  test "package: singular parent nested instance with different package" do
    @product = create_product!(sku: "WDG-PKG-001", category: @category)
    get "/demo/blogging/posts"
    url = controller.send(:resource_url_for, @product, parent: @category, association: :products, package: AdminPortal)
    assert_match %r{/admin/demo_features_category/nested_products/#{@product.id}$}, url
    refute_match %r{/demo/}, url
  end

  test "singular parent: route config" do
    config = DemoPortal::Engine.routes.resource_route_config_for("demo_features_categories")[0]
    assert_equal :resource, config[:route_type]

    nested_config = DemoPortal::Engine.routes.resource_route_config_for("demo_features_categories/products")[0]
    assert_equal :resources, nested_config[:route_type]
    assert_equal :products, nested_config[:association_name]
  end

  private

  def create_product!(sku:, category:)
    DemoFeatures::Product.create!(
      name: "Widget", sku: sku, category: category, stock_count: 10,
      price: 9.99, compare_at_price: 0, weight: 1.0, description: "Test",
      notes: "", slug: sku.parameterize, specifications: {}, metadata: {},
      release_date: Date.today, discontinue_date: Date.today + 1.year,
      available_from_time: "09:00", available_until_time: "17:00",
      published_at: Time.current, last_restocked_at: Time.current,
      active: true, featured: false, taxable: false
    )
  end
end
