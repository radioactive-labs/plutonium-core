# frozen_string_literal: true

require "test_helper"

class DefinitionQueryTest < Minitest::Test
  # Test search, filters, scopes, and sorting as documented

  def test_search_definition
    definition_class = Class.new(Plutonium::Resource::Definition) do
      search do |scope, query|
        scope.where("title ILIKE ?", "%#{query}%")
      end
    end

    instance = definition_class.new
    assert instance.search_definition
    assert instance.search_definition.is_a?(Proc)
  end

  def test_filter_declaration
    definition_class = Class.new(Plutonium::Resource::Definition) do
      filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq
      filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains
    end

    assert_equal 2, definition_class.defined_filters.size
    assert definition_class.defined_filters.key?(:status)
    assert definition_class.defined_filters.key?(:title)
    assert_equal :eq, definition_class.defined_filters[:status][:options][:predicate]
    assert_equal :contains, definition_class.defined_filters[:title][:options][:predicate]
  end

  def test_filter_with_lambda
    custom_filter = ->(scope, value) { scope.where(active: value == "true") }

    definition_class = Class.new(Plutonium::Resource::Definition) do
      filter :active, with: custom_filter
    end

    assert definition_class.defined_filters.key?(:active)
    assert_equal custom_filter, definition_class.defined_filters[:active][:options][:with]
  end

  def test_scope_declaration
    definition_class = Class.new(Plutonium::Resource::Definition) do
      scope :published
      scope :draft
      scope :featured
    end

    assert_equal 3, definition_class.defined_scopes.size
    assert definition_class.defined_scopes.key?(:published)
    assert definition_class.defined_scopes.key?(:draft)
    assert definition_class.defined_scopes.key?(:featured)
  end

  def test_scope_with_options
    definition_class = Class.new(Plutonium::Resource::Definition) do
      scope :recent
      scope :featured, default: true
    end

    # Scopes should be stored
    assert definition_class.defined_scopes.key?(:recent)
    assert definition_class.defined_scopes.key?(:featured)
  end

  def test_sort_declaration
    definition_class = Class.new(Plutonium::Resource::Definition) do
      sort :title
      sort :created_at
      sort :view_count
    end

    assert_equal 3, definition_class.defined_sorts.size
    assert definition_class.defined_sorts.key?(:title)
    assert definition_class.defined_sorts.key?(:created_at)
    assert definition_class.defined_sorts.key?(:view_count)
  end

  def test_sorts_helper_method
    definition_class = Class.new(Plutonium::Resource::Definition) do
      sorts :title, :created_at, :updated_at
    end

    assert_equal 3, definition_class.defined_sorts.size
    assert definition_class.defined_sorts.key?(:title)
    assert definition_class.defined_sorts.key?(:created_at)
    assert definition_class.defined_sorts.key?(:updated_at)
  end

  def test_default_sort_with_field_and_direction
    definition_class = Class.new(Plutonium::Resource::Definition) do
      default_sort :created_at, :desc
    end

    instance = definition_class.new
    assert_equal [:created_at, :desc], instance.default_sort
  end

  def test_default_sort_with_block
    definition_class = Class.new(Plutonium::Resource::Definition) do
      default_sort { |scope| scope.order(featured: :desc, created_at: :desc) }
    end

    instance = definition_class.new
    assert instance.default_sort.is_a?(Proc)
  end

  def test_default_sort_has_sensible_default
    definition_class = Class.new(Plutonium::Resource::Definition)
    instance = definition_class.new

    # Default should be :id, :desc
    assert_equal [:id, :desc], instance.default_sort
  end

  def test_blogging_post_definition_query_features
    # Test that our tutorial definition has the expected query features
    instance = Blogging::PostDefinition.new

    # Search
    assert instance.search_definition

    # Scopes
    assert Blogging::PostDefinition.defined_scopes.key?(:published)
    assert Blogging::PostDefinition.defined_scopes.key?(:drafts)

    # Filters
    assert Blogging::PostDefinition.defined_filters.key?(:title)
    assert_equal :contains, Blogging::PostDefinition.defined_filters[:title][:options][:predicate]

    # Sorts
    assert Blogging::PostDefinition.defined_sorts.key?(:title)
    assert Blogging::PostDefinition.defined_sorts.key?(:created_at)
    assert Blogging::PostDefinition.defined_sorts.key?(:published)

    # Default sort
    assert_equal [:created_at, :desc], instance.default_sort
  end

  def test_search_definition_can_be_executed
    # Create a definition with SQLite-compatible search
    definition_class = Class.new(Plutonium::Resource::Definition) do
      search do |scope, query|
        scope.where("title LIKE ?", "%#{query}%")
      end
    end

    # Create test data
    user = User.create!(email: "test@example.com", password: "password123", status: "verified")
    post1 = Blogging::Post.create!(title: "Hello World", body: "Content", user: user)
    post2 = Blogging::Post.create!(title: "Goodbye World", body: "Content", user: user)
    post3 = Blogging::Post.create!(title: "Something Else", body: "Content", user: user)

    definition = definition_class.new
    scope = Blogging::Post.all

    # Execute the search
    result = definition.search_definition.call(scope, "Hello")

    assert_includes result, post1
    refute_includes result, post2
    refute_includes result, post3
  ensure
    Blogging::Post.delete_all
    User.delete_all
  end
end
