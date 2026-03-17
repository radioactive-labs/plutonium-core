# frozen_string_literal: true

require "test_helper"

class TutorialTest < Minitest::Test
  def setup
    # Create a user for the posts (User is a Rodauth account, uses email/password)
    @user = User.create!(email: "test#{SecureRandom.hex(4)}@example.com", password: "password123", status: "verified")
    @org = Organization.create!(name: "Test Org")
  end

  def teardown
    Comment.delete_all
    Blogging::Post.delete_all
    Organization.delete_all
    User.delete_all
  end

  # Chapter 2: First Resource
  def test_post_creation
    post = Blogging::Post.create!(
      title: "Hello World",
      body: "This is my first post",
      status: :draft,
      user: @user,
      organization: @org
    )

    assert post.persisted?
    assert_equal "Hello World", post.title
    assert_equal @user, post.user
    assert post.draft?
  end

  # Chapter 6: Nested Resources
  def test_comment_belongs_to_post
    post = Blogging::Post.create!(title: "Post", body: "Body", status: :draft, user: @user, organization: @org)
    comment = Comment.create!(body: "Great post!", commentable: post, user: @user)

    assert comment.persisted?
    assert_equal post, comment.commentable
    assert_includes post.comments, comment
  end

  def test_deleting_post_deletes_comments
    post = Blogging::Post.create!(title: "Post", body: "Body", status: :draft, user: @user, organization: @org)
    Comment.create!(body: "Comment 1", commentable: post, user: @user)
    Comment.create!(body: "Comment 2", commentable: post, user: @user)

    assert_equal 2, Comment.count
    post.destroy
    assert_equal 0, Comment.count
  end

  # Chapter 5: Custom Actions
  def test_publish_post_interaction
    post = Blogging::Post.create!(title: "Draft Post", body: "Body", status: :draft, user: @user, organization: @org)
    refute post.published?

    result = Blogging::PublishPost.call(resource: post, view_context: nil)

    assert result.success?
    post.reload
    assert post.published?
  end

  def test_publish_post_interaction_fails_for_non_draft
    post = Blogging::Post.create!(
      title: "Already Published",
      body: "Body",
      user: @user,
      organization: @org,
      status: :published
    )

    result = Blogging::PublishPost.call(resource: post, view_context: nil)

    refute result.success?
  end

  # Chapter 7: Portal-specific policies
  def test_org_portal_policy_permits_create
    post = Blogging::Post.new(title: "New Post", body: "Body", user: @user, organization: @org)
    policy = OrgPortal::Blogging::PostPolicy.new(record: post, user: @user, entity_scope: @org)

    assert policy.create?
  end

  def test_storefront_policy_denies_create
    post = Blogging::Post.new(title: "New Post", body: "Body", user: @user, organization: @org)
    policy = StorefrontPortal::Blogging::PostPolicy.new(record: post, user: "Guest", entity_scope: nil)

    refute policy.create?
  end

  def test_storefront_policy_scopes_to_published
    draft = Blogging::Post.create!(title: "Draft", body: "Body", status: :draft, user: @user, organization: @org)
    published = Blogging::Post.create!(title: "Published", body: "Body", status: :published, user: @user, organization: @org)

    policy = StorefrontPortal::Blogging::PostPolicy.new(record: Blogging::Post, user: "Guest", entity_scope: nil)
    scoped = policy.relation_scope(Blogging::Post.all)

    assert_includes scoped, published
    refute_includes scoped, draft
  end

  # Chapter 8: Customizing UI - Definition tests
  def test_post_definition_has_publish_action
    actions = Blogging::PostDefinition.defined_actions

    assert actions.key?(:publish), "Expected :publish action to be defined"
  end

  def test_post_definition_has_archive_action
    actions = Blogging::PostDefinition.defined_actions

    assert actions.key?(:archive), "Expected :archive action to be defined"
  end

  def test_post_definition_has_sorting
    definition = Blogging::PostDefinition.new
    sorts = definition.defined_sorts

    assert sorts.key?(:title), "Expected :title sort"
    assert sorts.key?(:created_at), "Expected :created_at sort"
    assert sorts.key?(:status), "Expected :status sort"
  end

  def test_post_definition_has_body_field
    definition = Blogging::PostDefinition.new
    fields = definition.defined_fields

    assert fields.key?(:body), "Expected :body field to be defined"
  end
end
