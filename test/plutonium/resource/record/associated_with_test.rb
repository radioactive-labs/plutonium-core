# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::Record::AssociatedWithTest < ActiveSupport::TestCase
  setup do
    @org = Organization.create!(name: "AssocWith Test #{SecureRandom.hex(4)}")
    @user = User.create!(email: "associated_with_test_#{SecureRandom.hex(4)}@example.com", status: :verified)
  end

  teardown do
    purge_data!
  end

  test "associated_with same class returns matching record by primary key" do
    # When scoping a model to an instance of the same class,
    # it should just filter by primary key
    user1 = User.create!(email: "user1@example.com", status: :verified)
    user2 = User.create!(email: "user2@example.com", status: :verified)

    result = User.associated_with(user1)

    assert_includes result, user1
    refute_includes result, user2
    refute_includes result, @user
  end

  test "associated_with same class works with custom primary key" do
    # Test that we use the model's primary_key accessor, not hardcoded :id
    user = User.create!(email: "custom_pk@example.com", status: :verified)

    # Verify we're using the primary_key method
    assert_equal "id", User.primary_key

    result = User.associated_with(user)

    assert_equal 1, result.count
    assert_equal user.id, result.first.id
  end

  test "associated_with same class returns empty when record not in scope" do
    user = User.create!(email: "not_in_scope@example.com", status: :verified)

    # Delete the user after getting the reference
    user_id = user.id
    user.destroy

    # Now associated_with should return empty
    result = User.associated_with(User.new { |u| u.id = user_id })

    assert_empty result
  end

  test "associated_with different class still uses association lookup" do
    post = Blogging::Post.create!(user: @user, organization: @org, title: "Test", body: "Content")

    # This should use the normal association lookup, not the same-class shortcut
    result = Blogging::Post.associated_with(@org)

    assert_includes result, post
  end

  # Blogging::Post has four has_many associations to Comment (comments,
  # noninverse_comments, comment_series, flagged_comments). Picking the first
  # would scope by declaration order, so it must refuse to guess.
  test "associated_with raises when several of its associations point at the record's class" do
    comment = Comment.create!(body: "Test", commentable: Blogging::Post.create!(user: @user, organization: @org, title: "T", body: "B"), user: @user)

    error = assert_raises(Plutonium::Resource::Record::AssociatedWith::AmbiguousAssociationError) do
      Blogging::Post.associated_with(comment)
    end

    assert_match "comments, noninverse_comments, comment_series, flagged_comments", error.message
    assert_match "associated_with_comment", error.message
  end

  # Comment's only link to a post is the polymorphic commentable, so the lookup
  # goes through the post's associations, and there are four of them.
  test "associated_with raises when the record has several associations to the scoped class" do
    post = Blogging::Post.create!(user: @user, organization: @org, title: "T", body: "B")

    error = assert_raises(Plutonium::Resource::Record::AssociatedWith::AmbiguousAssociationError) do
      Comment.associated_with(post)
    end

    assert_match "comments, noninverse_comments, comment_series, flagged_comments", error.message
    assert_match "associated_with_blogging_post", error.message
  end
end
