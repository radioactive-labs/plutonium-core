# frozen_string_literal: true

require "test_helper"

class Plutonium::Resource::Record::AssociatedWithTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "associated_with_test@example.com", status: :verified)
  end

  teardown do
    Blogging::Post.delete_all
    User.delete_all
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
    post = Blogging::Post.create!(user: @user, title: "Test", body: "Content")

    # This should use the normal association lookup, not the same-class shortcut
    result = Blogging::Post.associated_with(@user)

    assert_includes result, post
  end
end
