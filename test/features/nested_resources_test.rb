# frozen_string_literal: true

require "test_helper"

class NestedResourcesTest < Minitest::Test
  # Test nested resources behavior as documented

  def setup
    @user = User.create!(email: "test@example.com", password: "password123", status: "verified")
    @post = Blogging::Post.create!(title: "Test Post", body: "Content", user: @user)
  end

  def teardown
    Blogging::PostMetadata.delete_all
    Blogging::Comment.delete_all
    Blogging::Post.delete_all
    User.delete_all
  end

  # Test associated_with scope - the core of nested resource scoping

  def test_associated_with_scope_via_belongs_to
    # Comment belongs_to :post, so associated_with(post) should work
    comment1 = Blogging::Comment.create!(body: "Comment 1", post: @post, user: @user)
    comment2 = Blogging::Comment.create!(body: "Comment 2", post: @post, user: @user)

    other_post = Blogging::Post.create!(title: "Other", body: "Content", user: @user)
    comment3 = Blogging::Comment.create!(body: "Comment 3", post: other_post, user: @user)

    scoped = Blogging::Comment.associated_with(@post)

    assert_includes scoped, comment1
    assert_includes scoped, comment2
    refute_includes scoped, comment3
  end

  def test_associated_with_scope_via_has_many
    # Post has_many :comments, so associated_with(comment) should work
    # This tests the reverse association lookup
    comment = Blogging::Comment.create!(body: "Test", post: @post, user: @user)

    other_post = Blogging::Post.create!(title: "Other", body: "Content", user: @user)

    # Posts associated with the comment (should find the parent post)
    scoped = Blogging::Post.associated_with(comment)

    assert_includes scoped, @post
    refute_includes scoped, other_post
  end

  def test_associated_with_custom_scope
    # Test that custom associated_with_* scopes take precedence
    # Our User model has posts through the user association on Post

    # Posts associated with user
    scoped = Blogging::Post.associated_with(@user)

    assert_includes scoped, @post
  end

  def test_has_many_association_routes
    # Test that model correctly identifies routable has_many associations
    # Returns pluralized model names (e.g., "blogging_comments")
    routes = Blogging::Post.has_many_association_routes

    assert_includes routes, "blogging_comments"
  end

  def test_nested_resource_query_scoping
    # Simulate what happens in a nested resource context
    # When accessing /posts/1/comments, comments should be scoped to post

    comment1 = Blogging::Comment.create!(body: "On target post", post: @post, user: @user)

    other_post = Blogging::Post.create!(title: "Other", body: "Content", user: @user)
    comment2 = Blogging::Comment.create!(body: "On other post", post: other_post, user: @user)

    # This is what the controller does internally
    parent = @post
    scoped_comments = Blogging::Comment.associated_with(parent)

    assert_equal 1, scoped_comments.count
    assert_includes scoped_comments, comment1
    refute_includes scoped_comments, comment2
  end

  def test_parent_assignment_to_new_record
    # When creating a nested resource, parent should be automatically assigned
    # This tests the model behavior, not controller

    new_comment = Blogging::Comment.new(body: "New comment", user: @user)
    new_comment.post = @post  # This is what the controller does

    assert new_comment.valid?
    new_comment.save!

    assert_equal @post, new_comment.post
    assert_includes @post.comments.reload, new_comment
  end

  def test_scoped_uniqueness_validation
    # Test uniqueness scoped to parent (common pattern in nested resources)
    # Not built into Plutonium but a common use case

    # Create a model that has scoped uniqueness
    post1 = Blogging::Post.create!(title: "Post 1", body: "Content", user: @user)
    post2 = Blogging::Post.create!(title: "Post 2", body: "Content", user: @user)

    # Same body should be allowed on different posts (if we had such validation)
    comment1 = Blogging::Comment.create!(body: "Same body", post: post1, user: @user)
    comment2 = Blogging::Comment.new(body: "Same body", post: post2, user: @user)

    # Both should be valid (different parents)
    assert comment1.valid?
    assert comment2.valid?
  end

  def test_destroy_cascades_to_nested_resources
    # Test that destroying parent cascades to children (via dependent: :destroy)
    comment1 = Blogging::Comment.create!(body: "Comment 1", post: @post, user: @user)
    comment2 = Blogging::Comment.create!(body: "Comment 2", post: @post, user: @user)

    comment_ids = [comment1.id, comment2.id]

    @post.destroy!

    # Comments should be deleted
    assert_empty Blogging::Comment.where(id: comment_ids)
  end

  def test_belongs_to_association_exists
    # Verify the belongs_to association is set up correctly
    comment = Blogging::Comment.new(body: "Test", post: @post, user: @user)

    assert_respond_to comment, :post
    assert_respond_to comment, :post=
    assert_equal @post, comment.post

    # The association reflection should exist
    assoc = Blogging::Comment.reflect_on_association(:post)
    assert assoc
    assert_equal :belongs_to, assoc.macro
  end

  def test_multiple_levels_of_association_lookup
    # Test that associated_with can traverse associations
    comment = Blogging::Comment.create!(body: "Test", post: @post, user: @user)

    # User -> Post (via user association on Post)
    user_posts = Blogging::Post.associated_with(@user)
    assert_includes user_posts, @post

    # Post -> Comments (via post association on Comment)
    post_comments = Blogging::Comment.associated_with(@post)
    assert_includes post_comments, comment
  end

  # has_one nested resource tests

  def test_has_one_association_routes
    # Test that model correctly identifies routable has_one associations
    routes = Blogging::Post.has_one_association_routes

    # "metadata" is uncountable so plural is still "metadata"
    assert_includes routes, "blogging_post_metadata"
  end

  def test_has_one_associated_with_scope
    # PostMetadata belongs_to :post, so associated_with(post) should work
    metadata = Blogging::PostMetadata.create!(
      post: @post,
      seo_title: "Test SEO Title",
      seo_description: "Test description"
    )

    other_post = Blogging::Post.create!(title: "Other", body: "Content", user: @user)
    other_metadata = Blogging::PostMetadata.create!(
      post: other_post,
      seo_title: "Other SEO Title"
    )

    scoped = Blogging::PostMetadata.associated_with(@post)

    assert_includes scoped, metadata
    refute_includes scoped, other_metadata
  end

  def test_has_one_route_config_registered_with_composite_key
    # Test that has_one nested routes are registered with composite key using association name
    # Force routes to load
    AdminPortal::Engine.routes.routes

    # Key uses association name (:post_metadata), not class plural (blogging_post_metadata)
    route_key = "blogging_posts/post_metadata"
    config = AdminPortal::Engine.routes.resource_route_config_for(route_key)[0]

    assert config, "Expected nested route config for #{route_key}"
    assert_equal :resource, config[:route_type], "has_one nested route should have :resource type"
    assert_equal :post_metadata, config[:association_name], "Config should store association name"
  end

  def test_has_many_route_config_registered_with_composite_key
    # Test that has_many nested routes are registered with composite key using association name
    # Force routes to load
    AdminPortal::Engine.routes.routes

    # Key uses association name (:comments), not class plural (blogging_comments)
    route_key = "blogging_posts/comments"
    config = AdminPortal::Engine.routes.resource_route_config_for(route_key)[0]

    assert config, "Expected nested route config for #{route_key}"
    assert_equal :resources, config[:route_type], "has_many nested route should have :resources type"
    assert_equal :comments, config[:association_name], "Config should store association name"
  end

  def test_top_level_route_config_has_resources_type
    # Top-level PostMetadata should have :resources type
    # Force routes to load
    AdminPortal::Engine.routes.routes

    route_key = "blogging_post_metadata"
    config = AdminPortal::Engine.routes.resource_route_config_for(route_key)[0]

    assert config, "Expected top-level route config for #{route_key}"
    assert_equal :resources, config[:route_type], "Top-level route should have :resources type"
  end

  def test_has_one_destroy_cascades
    # Test that destroying post cascades to metadata (via dependent: :destroy)
    metadata = Blogging::PostMetadata.create!(
      post: @post,
      seo_title: "Test SEO Title"
    )
    metadata_id = metadata.id

    @post.destroy!

    assert_nil Blogging::PostMetadata.find_by(id: metadata_id)
  end

  # Multiple associations to same class tests

  def test_user_has_multiple_associations_to_post
    # Verify the associations exist
    assert User.reflect_on_association(:authored_posts), "User should have authored_posts association"
    assert User.reflect_on_association(:edited_posts), "User should have edited_posts association"

    # Both point to Blogging::Post
    assert_equal Blogging::Post, User.reflect_on_association(:authored_posts).klass
    assert_equal Blogging::Post, User.reflect_on_association(:edited_posts).klass
  end

  def test_post_has_multiple_belongs_to_user
    # Verify the belongs_to associations exist
    assert Blogging::Post.reflect_on_association(:author), "Post should have author association"
    assert Blogging::Post.reflect_on_association(:editor), "Post should have editor association"

    # Both point to User
    assert_equal User, Blogging::Post.reflect_on_association(:author).klass
    assert_equal User, Blogging::Post.reflect_on_association(:editor).klass
  end

  def test_multiple_associations_route_configs_registered
    # Force routes to load
    AdminPortal::Engine.routes.routes

    # Both associations should have their own route configs
    authored_config = AdminPortal::Engine.routes.resource_route_config_for("users/authored_posts")[0]
    edited_config = AdminPortal::Engine.routes.resource_route_config_for("users/edited_posts")[0]

    assert authored_config, "Expected route config for users/authored_posts"
    assert edited_config, "Expected route config for users/edited_posts"

    assert_equal :authored_posts, authored_config[:association_name]
    assert_equal :edited_posts, edited_config[:association_name]
  end

  def test_association_resolver_with_explicit_symbol
    # Using explicit symbol should work without ambiguity
    resolver = Object.new.extend(Plutonium::Core::Controllers::AssociationResolver)

    result = resolver.resolve_association(:authored_posts, @user)
    assert_equal :authored_posts, result

    result = resolver.resolve_association(:edited_posts, @user)
    assert_equal :edited_posts, result
  end

  def test_association_resolver_raises_when_no_matching_association
    # Association names (authored_posts, edited_posts) don't match class name pattern
    # (blogging_posts, posts), so resolver can't auto-detect
    resolver = Object.new.extend(Plutonium::Core::Controllers::AssociationResolver)

    error = assert_raises(ArgumentError) do
      resolver.resolve_association(Blogging::Post, @user)
    end

    assert_match(/No association found/, error.message)
    assert_match(/blogging_posts/, error.message)
  end

  def test_association_resolver_raises_on_truly_ambiguous_class
    # Create a scenario with ambiguous associations that match class name pattern
    # For this test, we'll use a mock since we can't easily modify User
    parent_class = Class.new do
      def self.reflect_on_association(name)
        case name
        when :blogging_posts
          Struct.new(:klass).new(Blogging::Post)
        when :posts
          Struct.new(:klass).new(Blogging::Post)
        end
      end
    end
    parent = parent_class.new

    resolver = Object.new.extend(Plutonium::Core::Controllers::AssociationResolver)

    error = assert_raises(Plutonium::Core::Controllers::AssociationResolver::AmbiguousAssociationError) do
      resolver.resolve_association(Blogging::Post, parent)
    end

    assert_match(/Multiple associations/, error.message)
  end

  def test_inverse_of_properly_configured
    # Verify inverse_of is set up correctly for resolution
    authored_assoc = User.reflect_on_association(:authored_posts)
    edited_assoc = User.reflect_on_association(:edited_posts)

    assert_equal :author, authored_assoc.inverse_of&.name
    assert_equal :editor, edited_assoc.inverse_of&.name
  end
end
