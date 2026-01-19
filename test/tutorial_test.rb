# frozen_string_literal: true

require "test_helper"

class TutorialTest < Minitest::Test
  def setup
    # Create a user for the posts (User is a Rodauth account, uses email/password)
    @user = User.create!(email: "test@example.com", password: "password123", status: "verified")
  end

  def teardown
    Blogging::Comment.delete_all
    Blogging::Post.delete_all
    User.delete_all
  end

  # Chapter 2: First Resource
  def test_post_creation
    post = Blogging::Post.create!(
      title: "Hello World",
      body: "This is my first post",
      published: false,
      user: @user
    )

    assert post.persisted?
    assert_equal "Hello World", post.title
    assert_equal @user, post.user
    refute post.published?
  end

  # Chapter 6: Nested Resources
  def test_comment_belongs_to_post
    post = Blogging::Post.create!(title: "Post", body: "Body", published: false, user: @user)
    comment = Blogging::Comment.create!(body: "Great post!", post: post, user: @user)

    assert comment.persisted?
    assert_equal post, comment.post
    assert_includes post.comments, comment
  end

  def test_deleting_post_deletes_comments
    post = Blogging::Post.create!(title: "Post", body: "Body", published: false, user: @user)
    Blogging::Comment.create!(body: "Comment 1", post: post, user: @user)
    Blogging::Comment.create!(body: "Comment 2", post: post, user: @user)

    assert_equal 2, Blogging::Comment.count
    post.destroy
    assert_equal 0, Blogging::Comment.count
  end

  # Chapter 5: Custom Actions
  def test_publish_post_interaction
    post = Blogging::Post.create!(title: "Draft Post", body: "Body", published: false, user: @user)
    refute post.published?

    result = Blogging::PublishPost.call(resource: post, view_context: nil)

    assert result.success?
    post.reload
    assert post.published?
  end

  def test_publish_post_interaction_fails_for_already_published
    post = Blogging::Post.create!(
      title: "Already Published",
      body: "Body",
      user: @user,
      published: true
    )

    result = Blogging::PublishPost.call(resource: post, view_context: nil)

    refute result.success?
  end

  # Chapter 7: Author Portal - Portal-specific policies
  def test_author_portal_policy_scopes_posts_to_user
    # Create posts for different users
    other_user = User.create!(email: "other@example.com", password: "password123", status: "verified")
    my_post = Blogging::Post.create!(title: "My Post", body: "Body", published: false, user: @user)
    other_post = Blogging::Post.create!(title: "Other Post", body: "Body", published: false, user: other_user)

    # Author portal policy should only show user's own posts
    policy = AuthorPortal::Blogging::PostPolicy.new(record: my_post, user: @user, entity_scope: nil)
    scoped = policy.relation_scope(Blogging::Post.all)

    assert_includes scoped, my_post
    refute_includes scoped, other_post
  end

  def test_author_portal_policy_allows_create
    post = Blogging::Post.new(title: "New Post", body: "Body", user: @user)
    policy = AuthorPortal::Blogging::PostPolicy.new(record: post, user: @user, entity_scope: nil)

    assert policy.create?
  end

  def test_author_portal_policy_hides_user_id_from_create_form
    post = Blogging::Post.new
    policy = AuthorPortal::Blogging::PostPolicy.new(record: post, user: @user, entity_scope: nil)

    permitted = policy.permitted_attributes_for_create
    refute_includes permitted, :user_id
    assert_includes permitted, :title
    assert_includes permitted, :body
  end

  # Chapter 8: Customizing UI - Definition tests
  def test_post_definition_has_publish_action
    actions = Blogging::PostDefinition.defined_actions

    assert actions.key?(:publish), "Expected :publish action to be defined"
  end

  def test_post_definition_has_sorting
    definition = Blogging::PostDefinition.new
    sorts = definition.defined_sorts

    assert sorts.key?(:title), "Expected :title sort"
    assert sorts.key?(:created_at), "Expected :created_at sort"
    assert sorts.key?(:published), "Expected :published sort"
  end

  def test_post_definition_has_body_field
    definition = Blogging::PostDefinition.new
    fields = definition.defined_fields

    assert fields.key?(:body), "Expected :body field to be defined"
  end
end
