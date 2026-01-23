# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::PolicyTest < Minitest::Test
  def setup
    @user = User.create!(email: "policy_test@example.com", status: :verified)
    @other_user = User.create!(email: "other@example.com", status: :verified)
    @post = Blogging::Post.create!(user: @user, title: "Test Post", body: "Body content")
    @other_post = Blogging::Post.create!(user: @other_user, title: "Other Post", body: "Other body")
    @comment = Blogging::Comment.create!(user: @user, post: @post, body: "Test comment")
    @other_comment = Blogging::Comment.create!(user: @other_user, post: @other_post, body: "Other comment")
    @post_metadata = Blogging::PostMetadata.create!(post: @post, seo_title: "SEO Title")
  end

  def teardown
    Blogging::PostMetadata.delete_all
    Blogging::Comment.delete_all
    Blogging::Post.delete_all
    User.delete_all
  end

  # Parent scoping tests (nested routes)

  def test_relation_scope_with_has_many_parent_scopes_to_parent_association
    policy = Blogging::CommentPolicy.new(
      record: Blogging::Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: nil
    )

    scoped = policy.apply_scope(Blogging::Comment.all, type: :active_record_relation)

    assert_includes scoped.to_a, @comment
    refute_includes scoped.to_a, @other_comment
  end

  def test_relation_scope_with_has_one_parent_scopes_by_foreign_key
    policy = Blogging::PostMetadataPolicy.new(
      record: Blogging::PostMetadata,
      user: @user,
      parent: @post,
      parent_association: :post_metadata,
      entity_scope: nil
    )

    scoped = policy.apply_scope(Blogging::PostMetadata.all, type: :active_record_relation)

    assert_includes scoped.to_a, @post_metadata
    assert_equal 1, scoped.count
  end

  def test_relation_scope_requires_both_parent_and_parent_association
    policy = Blogging::CommentPolicy.new(
      record: Blogging::Comment,
      user: @user,
      parent: @post,
      parent_association: nil,
      entity_scope: nil
    )

    assert_raises(ArgumentError) do
      policy.apply_scope(Blogging::Comment.all, type: :active_record_relation)
    end
  end

  def test_relation_scope_without_parent_uses_entity_scope
    # Create a scoped entity (the user acts as the entity scope)
    policy = Blogging::PostPolicy.new(
      record: Blogging::Post,
      user: @user,
      entity_scope: @user
    )

    scoped = policy.apply_scope(Blogging::Post.all, type: :active_record_relation)

    # Should scope to posts associated with the user (entity scope)
    assert_includes scoped.to_a, @post
  end

  def test_relation_scope_without_parent_or_entity_returns_unscoped
    policy = Blogging::PostPolicy.new(
      record: Blogging::Post,
      user: @user,
      entity_scope: nil
    )

    scoped = policy.apply_scope(Blogging::Post.all, type: :active_record_relation)

    # Without entity scope, should return all records
    assert_includes scoped.to_a, @post
    assert_includes scoped.to_a, @other_post
  end

  def test_parent_scoping_takes_precedence_over_entity_scope
    # When parent is provided, entity_scope should not apply
    # (parent was already entity-scoped during its own authorization)
    policy = Blogging::CommentPolicy.new(
      record: Blogging::Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: @other_user # This should be ignored
    )

    scoped = policy.apply_scope(Blogging::Comment.all, type: :active_record_relation)

    # Should scope to parent's comments, not entity's
    assert_includes scoped.to_a, @comment
    refute_includes scoped.to_a, @other_comment
  end

  # Direct default_relation_scope tests

  def test_default_relation_scope_can_be_called_directly
    policy = Blogging::CommentPolicy.new(
      record: Blogging::Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: nil
    )

    # Call the method directly instead of through apply_scope
    scoped = policy.default_relation_scope(Blogging::Comment.all)

    assert_includes scoped.to_a, @comment
    refute_includes scoped.to_a, @other_comment
  end

  def test_default_relation_scope_returns_unmodified_relation_when_no_context
    policy = Blogging::PostPolicy.new(
      record: Blogging::Post,
      user: @user,
      entity_scope: nil
    )

    relation = Blogging::Post.all
    scoped = policy.default_relation_scope(relation)

    # Should return all records when no parent or entity_scope
    assert_includes scoped.to_a, @post
    assert_includes scoped.to_a, @other_post
  end

  # Verification tests

  def test_raises_error_when_default_relation_scope_not_called
    # Create a policy class that doesn't call default_relation_scope
    bad_policy_class = Class.new(Plutonium::Resource::Policy) do
      relation_scope do |relation|
        relation.where(id: 1) # Doesn't call default_relation_scope!
      end
    end

    policy = bad_policy_class.new(
      record: Blogging::Post,
      user: @user,
      entity_scope: nil
    )

    error = assert_raises(RuntimeError) do
      policy.apply_scope(Blogging::Post.all, type: :active_record_relation)
    end

    assert_match(/did not call.*default_relation_scope/, error.message)
  end

  def test_no_error_when_default_relation_scope_called_via_super
    # Policies that call super should pass verification
    policy = Blogging::CommentPolicy.new(
      record: Blogging::Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: nil
    )

    # Should not raise - the base class calls default_relation_scope
    scoped = policy.apply_scope(Blogging::Comment.all, type: :active_record_relation)
    assert_includes scoped.to_a, @comment
  end

  def test_no_error_when_skip_default_relation_scope_called
    # Create a policy class that explicitly skips default scoping
    skip_policy_class = Class.new(Plutonium::Resource::Policy) do
      relation_scope do |relation|
        skip_default_relation_scope!
        relation  # Return unscoped - no parent/entity filtering
      end
    end

    policy = skip_policy_class.new(
      record: Blogging::Post,
      user: @user,
      entity_scope: @user  # Would normally scope, but skip bypasses it
    )

    # Should not raise - skip was called explicitly
    scoped = policy.apply_scope(Blogging::Post.all, type: :active_record_relation)

    # Returns all posts because scoping was skipped
    assert_includes scoped.to_a, @post
    assert_includes scoped.to_a, @other_post
  end
end
