# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::PolicyTest < Minitest::Test
  def setup
    @org = Organization.create!(name: "Policy Test Org #{SecureRandom.hex(4)}")
    @user = User.create!(email: "policy_test_#{SecureRandom.hex(4)}@example.com", status: :verified)
    @other_user = User.create!(email: "other_#{SecureRandom.hex(4)}@example.com", status: :verified)
    @post = Blogging::Post.create!(user: @user, organization: @org, title: "Test Post", body: "Body content")
    @other_post = Blogging::Post.create!(user: @other_user, organization: @org, title: "Other Post", body: "Other body")
    @comment = Comment.create!(user: @user, commentable: @post, body: "Test comment")
    @other_comment = Comment.create!(user: @other_user, commentable: @other_post, body: "Other comment")
    @post_detail = Blogging::PostDetail.create!(post: @post, seo_title: "SEO Title")
  end

  def teardown
    Blogging::PostDetail.delete_all
    Comment.delete_all
    Blogging::Post.delete_all
    Organization.delete_all
    User.delete_all
  end

  # Parent scoping tests (nested routes)

  def test_relation_scope_with_has_many_parent_scopes_to_parent_association
    policy = CommentPolicy.new(
      record: Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: nil
    )

    scoped = policy.apply_scope(Comment.all, type: :active_record_relation)

    assert_includes scoped.to_a, @comment
    refute_includes scoped.to_a, @other_comment
  end

  def test_relation_scope_with_has_one_parent_scopes_by_foreign_key
    policy = Blogging::PostDetailPolicy.new(
      record: Blogging::PostDetail,
      user: @user,
      parent: @post,
      parent_association: :post_detail,
      entity_scope: nil
    )

    scoped = policy.apply_scope(Blogging::PostDetail.all, type: :active_record_relation)

    assert_includes scoped.to_a, @post_detail
    assert_equal 1, scoped.count
  end

  def test_relation_scope_requires_both_parent_and_parent_association
    policy = CommentPolicy.new(
      record: Comment,
      user: @user,
      parent: @post,
      parent_association: nil,
      entity_scope: nil
    )

    assert_raises(ArgumentError) do
      policy.apply_scope(Comment.all, type: :active_record_relation)
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
    policy = CommentPolicy.new(
      record: Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: @other_user # This should be ignored
    )

    scoped = policy.apply_scope(Comment.all, type: :active_record_relation)

    # Should scope to parent's comments, not entity's
    assert_includes scoped.to_a, @comment
    refute_includes scoped.to_a, @other_comment
  end

  # Direct default_relation_scope tests

  def test_default_relation_scope_can_be_called_directly
    policy = CommentPolicy.new(
      record: Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: nil
    )

    # Call the method directly instead of through apply_scope
    scoped = policy.default_relation_scope(Comment.all)

    assert_includes scoped.to_a, @comment
    refute_includes scoped.to_a, @other_comment
  end

  def test_sti_subclass_relation_still_uses_parent_scoping
    # Parent association is :authored_posts (klass = Blogging::Post). The
    # relation is Blogging::Article (an STI subclass of Post). The relation's
    # class is more specific than the association's class, so parent scoping
    # should still apply — narrowing to "this user's articles".
    @user.authored_posts << @post
    @article = Blogging::Article.create!(
      user: @user, author: @user, organization: @org,
      title: "User's article", body: "..."
    )
    Blogging::Article.create!(
      user: @other_user, author: @other_user, organization: @org,
      title: "Other user's article", body: "..."
    )

    policy = Blogging::PostPolicy.new(
      record: Blogging::Article,
      user: @user,
      parent: @user,
      parent_association: :authored_posts,
      entity_scope: nil
    )

    scoped = policy.default_relation_scope(Blogging::Article.all)

    assert_includes scoped.to_a, @article
    assert_equal 1, scoped.count
  end

  def test_sti_superclass_relation_falls_back_to_entity_scope
    # Parent association is :authored_articles (klass = Blogging::Article, an
    # STI subclass). The relation is Blogging::Post (the STI parent). The
    # relation is broader than the association produces, so we treat this as
    # a sibling-style lookup and fall back to entity scoping. This matches
    # the SecureAssociation use case: a form on a nested-articles route with
    # a `belongs_to :related_post` field wants all org posts, not the narrow
    # set of articles owned by the parent user.
    Blogging::Article.create!(
      user: @user, author: @user, organization: @org,
      title: "User's article", body: "..."
    )

    policy = Blogging::PostPolicy.new(
      record: Blogging::Post,
      user: @user,
      parent: @user,
      parent_association: :authored_articles,
      entity_scope: @org
    )

    scoped = policy.default_relation_scope(Blogging::Post.all)

    # Entity-scoped to the org — includes both posts plus the article.
    assert_includes scoped.to_a, @post
    assert_includes scoped.to_a, @other_post
  end

  def test_sibling_lookup_on_nested_route_falls_back_to_entity_scope
    # Reproduces the SecureAssociation sibling-lookup bug: a request running
    # under a nested route (parent=@post, parent_association=:comments) sets
    # the parent context on the policy. When a form on that page builds a
    # SecureAssociation against an unrelated sibling resource, the same policy
    # context is reused — but the parent's named association doesn't apply to
    # the sibling's relation. We must skip parent scoping (which would produce
    # an incoherent empty merge) and fall back to entity scoping.
    policy = Blogging::PostPolicy.new(
      record: Blogging::Post,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: @org
    )

    scoped = policy.default_relation_scope(Blogging::Post.all)

    # Entity-scoped (org), not parent-scoped (which would be empty/incoherent).
    assert_includes scoped.to_a, @post
    assert_includes scoped.to_a, @other_post
  end

  def test_sibling_lookup_on_nested_route_without_entity_scope_returns_relation
    # Same sibling-lookup case as above but without an entity scope.
    # The parent association doesn't apply, so we fall through to the
    # unscoped relation rather than producing the incoherent merge.
    policy = Blogging::PostPolicy.new(
      record: Blogging::Post,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: nil
    )

    scoped = policy.default_relation_scope(Blogging::Post.all)

    assert_includes scoped.to_a, @post
    assert_includes scoped.to_a, @other_post
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
    policy = CommentPolicy.new(
      record: Comment,
      user: @user,
      parent: @post,
      parent_association: :comments,
      entity_scope: nil
    )

    # Should not raise - the base class calls default_relation_scope
    scoped = policy.apply_scope(Comment.all, type: :active_record_relation)
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
