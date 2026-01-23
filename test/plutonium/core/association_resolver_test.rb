# frozen_string_literal: true

require "test_helper"

class Plutonium::Core::AssociationResolverTest < Minitest::Test
  def setup
    @resolver = Object.new.extend(Plutonium::Core::Controllers::AssociationResolver)
    @user = User.create!(email: "resolver_test@example.com", status: :verified)
    @post = Blogging::Post.create!(user: @user, title: "Test Post", body: "Body content")
  end

  def teardown
    Blogging::Post.delete_all
    User.delete_all
  end

  # Symbol passthrough

  def test_resolve_association_returns_symbol_unchanged
    result = @resolver.resolve_association(:comments, @post)
    assert_equal :comments, result
  end

  def test_resolve_association_with_any_symbol_passes_through
    result = @resolver.resolve_association(:anything, @post)
    assert_equal :anything, result
  end

  # Class-based resolution

  def test_resolve_association_finds_association_by_class
    result = @resolver.resolve_association(Blogging::Comment, @post)
    assert_equal :comments, result
  end

  def test_resolve_association_finds_namespaced_association
    # Blogging::Post has comments association that points to Blogging::Comment
    result = @resolver.resolve_association(Blogging::Comment, @post)
    assert_equal :comments, result
  end

  # Instance-based resolution

  def test_resolve_association_works_with_instance
    comment = Blogging::Comment.create!(user: @user, post: @post, body: "Test")
    result = @resolver.resolve_association(comment, @post)
    assert_equal :comments, result
  ensure
    Blogging::Comment.delete_all
  end

  # Error cases

  def test_resolve_association_raises_for_unknown_association
    # User doesn't have a direct association to Admin
    error = assert_raises(ArgumentError) do
      @resolver.resolve_association(Admin, @user)
    end

    assert_match(/No association found/, error.message)
  end

  def test_resolve_association_error_includes_tried_candidates
    error = assert_raises(ArgumentError) do
      @resolver.resolve_association(Admin, @user)
    end

    # Should mention what it tried
    assert_match(/admins/, error.message)
  end

  # Candidate generation

  def test_association_candidates_for_namespaced_class
    candidates = @resolver.send(:association_candidates_for, Blogging::Comment)

    # Should try both namespaced and demodulized versions
    assert_includes candidates, :blogging_comments
    assert_includes candidates, :comments
  end

  def test_association_candidates_for_non_namespaced_class
    candidates = @resolver.send(:association_candidates_for, User)

    assert_includes candidates, :users
    assert_equal 1, candidates.size # Only one candidate for non-namespaced
  end

  def test_association_candidates_returns_unique_values
    # For a class where namespaced == demodulized, should only return once
    candidates = @resolver.send(:association_candidates_for, User)
    assert_equal candidates.uniq, candidates
  end

  # Note: STI subclasses require explicit association names
  # because candidate generation is based on class name, not class hierarchy.
  # Use: resolve_association(:comments, @post) instead of resolve_association(StiComment, @post)
end
