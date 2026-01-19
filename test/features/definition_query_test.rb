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

    # Filters - includes symbol syntax filters
    assert Blogging::PostDefinition.defined_filters.key?(:title)
    assert_equal :contains, Blogging::PostDefinition.defined_filters[:title][:options][:predicate]
    assert_equal :text, Blogging::PostDefinition.defined_filters[:title][:options][:with]

    assert Blogging::PostDefinition.defined_filters.key?(:published)
    assert_equal :boolean, Blogging::PostDefinition.defined_filters[:published][:options][:with]

    assert Blogging::PostDefinition.defined_filters.key?(:user)
    assert_equal :association, Blogging::PostDefinition.defined_filters[:user][:options][:with]

    # Sorts
    assert Blogging::PostDefinition.defined_sorts.key?(:title)
    assert Blogging::PostDefinition.defined_sorts.key?(:created_at)
    assert Blogging::PostDefinition.defined_sorts.key?(:published)

    # Default sort
    assert_equal [:created_at, :desc], instance.default_sort
  end

  def test_filter_with_symbol_type
    definition_class = Class.new(Plutonium::Resource::Definition) do
      filter :status, with: :text, predicate: :eq
      filter :active, with: :boolean
      filter :category, with: :select, choices: %w[tech business sports]
    end

    assert_equal 3, definition_class.defined_filters.size
    assert_equal :text, definition_class.defined_filters[:status][:options][:with]
    assert_equal :boolean, definition_class.defined_filters[:active][:options][:with]
    assert_equal :select, definition_class.defined_filters[:category][:options][:with]
  end

  def test_filter_lookup_resolves_symbols_to_classes
    assert_equal Plutonium::Query::Filters::Text, Plutonium::Query::Filter.lookup(:text)
    assert_equal Plutonium::Query::Filters::Boolean, Plutonium::Query::Filter.lookup(:boolean)
    assert_equal Plutonium::Query::Filters::Select, Plutonium::Query::Filter.lookup(:select)
    assert_equal Plutonium::Query::Filters::Date, Plutonium::Query::Filter.lookup(:date)
    assert_equal Plutonium::Query::Filters::DateRange, Plutonium::Query::Filter.lookup(:date_range)
    assert_equal Plutonium::Query::Filters::Association, Plutonium::Query::Filter.lookup(:association)
  end

  def test_filter_lookup_passes_through_classes
    assert_equal Plutonium::Query::Filters::Text, Plutonium::Query::Filter.lookup(Plutonium::Query::Filters::Text)
  end

  def test_filter_lookup_raises_for_unknown_type
    assert_raises(ArgumentError) do
      Plutonium::Query::Filter.lookup(:unknown_filter_type)
    end
  end

  # ============================================
  # Text Filter Tests
  # ============================================

  def test_text_filter_default_predicate
    filter = Plutonium::Query::Filters::Text.new(key: :title)
    scope = Blogging::Post.all

    result = filter.apply(scope, query: "Hello")
    assert_includes result.to_sql, %("blogging_posts"."title" = 'Hello')
  end

  def test_text_filter_contains_predicate
    filter = Plutonium::Query::Filters::Text.new(key: :title, predicate: :contains)
    scope = Blogging::Post.all

    result = filter.apply(scope, query: "Hello")
    assert_includes result.to_sql, "LIKE '%Hello%'"
  end

  def test_text_filter_starts_with_predicate
    filter = Plutonium::Query::Filters::Text.new(key: :title, predicate: :starts_with)
    scope = Blogging::Post.all

    result = filter.apply(scope, query: "Hello")
    assert_includes result.to_sql, "LIKE 'Hello%'"
  end

  def test_text_filter_ends_with_predicate
    filter = Plutonium::Query::Filters::Text.new(key: :title, predicate: :ends_with)
    scope = Blogging::Post.all

    result = filter.apply(scope, query: "Hello")
    assert_includes result.to_sql, "LIKE '%Hello'"
  end

  def test_text_filter_invalid_predicate_raises
    assert_raises(ArgumentError) do
      Plutonium::Query::Filters::Text.new(key: :title, predicate: :invalid)
    end
  end

  # ============================================
  # Boolean Filter Tests
  # ============================================

  def test_boolean_filter_defaults
    filter = Plutonium::Query::Filters::Boolean.new(key: :published)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "true")
    assert_includes result.to_sql, %("blogging_posts"."published" = 1)

    result = filter.apply(scope, value: "false")
    assert_includes result.to_sql, %("blogging_posts"."published" = 0)
  end

  def test_boolean_filter_blank_value_returns_unmodified_scope
    filter = Plutonium::Query::Filters::Boolean.new(key: :published)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "")
    assert_equal scope.to_sql, result.to_sql
  end

  def test_boolean_filter_custom_labels
    filter = Plutonium::Query::Filters::Boolean.new(key: :published, true_label: "Published", false_label: "Draft")

    # Test that it still applies correctly
    scope = Blogging::Post.all
    result = filter.apply(scope, value: "true")
    assert_includes result.to_sql, %("blogging_posts"."published" = 1)
  end

  # ============================================
  # Select Filter Tests
  # ============================================

  def test_select_filter_with_array_choices
    filter = Plutonium::Query::Filters::Select.new(key: :title, choices: %w[draft published archived])
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "published")
    assert_includes result.to_sql, %("blogging_posts"."title" = 'published')
  end

  def test_select_filter_blank_value_returns_unmodified_scope
    filter = Plutonium::Query::Filters::Select.new(key: :title, choices: %w[draft published])
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "")
    assert_equal scope.to_sql, result.to_sql
  end

  def test_select_filter_multiple
    filter = Plutonium::Query::Filters::Select.new(key: :title, choices: %w[draft published archived], multiple: true)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: ["draft", "published", ""])
    assert_includes result.to_sql, %("blogging_posts"."title" IN ('draft', 'published'))
  end

  def test_select_filter_with_proc_choices
    choices_proc = -> { %w[a b c] }
    filter = Plutonium::Query::Filters::Select.new(key: :title, choices: choices_proc)

    # The proc is stored for lazy evaluation
    assert filter.instance_variable_get(:@choices).is_a?(Proc)
  end

  # ============================================
  # Date Filter Tests
  # ============================================

  def test_date_filter_default_predicate_eq
    filter = Plutonium::Query::Filters::Date.new(key: :created_at)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "2024-01-15")
    sql = result.to_sql
    # eq predicate uses all_day range
    assert_includes sql, "created_at"
    assert_includes sql, "BETWEEN"
  end

  def test_date_filter_gteq_predicate
    filter = Plutonium::Query::Filters::Date.new(key: :created_at, predicate: :gteq)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "2024-01-15")
    assert_includes result.to_sql, ">="
  end

  def test_date_filter_lt_predicate
    filter = Plutonium::Query::Filters::Date.new(key: :created_at, predicate: :lt)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "2024-01-15")
    assert_includes result.to_sql, "<"
  end

  def test_date_filter_blank_value_returns_unmodified_scope
    filter = Plutonium::Query::Filters::Date.new(key: :created_at)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "")
    assert_equal scope.to_sql, result.to_sql
  end

  def test_date_filter_invalid_predicate_raises
    assert_raises(ArgumentError) do
      Plutonium::Query::Filters::Date.new(key: :created_at, predicate: :invalid)
    end
  end

  # ============================================
  # DateRange Filter Tests
  # ============================================

  def test_date_range_filter_both_dates
    filter = Plutonium::Query::Filters::DateRange.new(key: :created_at)
    scope = Blogging::Post.all

    result = filter.apply(scope, from: "2024-01-01", to: "2024-01-31")
    sql = result.to_sql
    assert_includes sql, "created_at"
    assert_includes sql, "BETWEEN"
  end

  def test_date_range_filter_from_only
    filter = Plutonium::Query::Filters::DateRange.new(key: :created_at)
    scope = Blogging::Post.all

    result = filter.apply(scope, from: "2024-01-01", to: nil)
    assert_includes result.to_sql, ">="
  end

  def test_date_range_filter_to_only
    filter = Plutonium::Query::Filters::DateRange.new(key: :created_at)
    scope = Blogging::Post.all

    result = filter.apply(scope, from: nil, to: "2024-01-31")
    assert_includes result.to_sql, "<="
  end

  def test_date_range_filter_no_dates_returns_unmodified_scope
    filter = Plutonium::Query::Filters::DateRange.new(key: :created_at)
    scope = Blogging::Post.all

    result = filter.apply(scope, from: nil, to: nil)
    assert_equal scope.to_sql, result.to_sql
  end

  # ============================================
  # Association Filter Tests
  # ============================================

  def test_association_filter_with_class
    filter = Plutonium::Query::Filters::Association.new(key: :user, class: User)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "123")
    assert_includes result.to_sql, %("blogging_posts"."user_id" = 123)
  end

  def test_association_filter_detects_class_from_reflection
    filter = Plutonium::Query::Filters::Association.new(key: :user, resource_class: Blogging::Post)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "456")
    assert_includes result.to_sql, %("blogging_posts"."user_id" = 456)
  end

  def test_association_filter_multiple
    filter = Plutonium::Query::Filters::Association.new(key: :user, class: User, multiple: true)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: ["1", "2", ""])
    assert_includes result.to_sql, %("blogging_posts"."user_id" IN (1, 2))
  end

  def test_association_filter_blank_value_returns_unmodified_scope
    filter = Plutonium::Query::Filters::Association.new(key: :user, class: User)
    scope = Blogging::Post.all

    result = filter.apply(scope, value: "")
    assert_equal scope.to_sql, result.to_sql
  end

  def test_association_filter_requires_class_or_reflection
    assert_raises(ArgumentError) do
      # No class and no resource_class to detect from
      Plutonium::Query::Filters::Association.new(key: :unknown_assoc)
    end
  end

  def test_association_filter_with_scope_proc
    filter = Plutonium::Query::Filters::Association.new(
      key: :user,
      class: User,
      scope: ->(scope) { scope.verified }
    )

    # The scope proc is stored
    assert filter.instance_variable_get(:@scope_proc).is_a?(Proc)
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
