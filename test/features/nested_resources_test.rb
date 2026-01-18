# frozen_string_literal: true

require "test_helper"

class NestedResourcesTest < Minitest::Test
  # Test nested resources behavior as documented

  def setup
    @user = User.create!(email: "test@example.com", password: "password123", status: "verified")
    @post = Blogging::Post.create!(title: "Test Post", body: "Content", user: @user)
  end

  def teardown
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
end
