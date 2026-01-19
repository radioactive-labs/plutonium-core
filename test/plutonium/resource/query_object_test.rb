# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Resource
    class QueryObjectTest < Minitest::Test
      # Mock resource class for testing
      class MockResource
        def self.respond_to?(method, include_private = false)
          [:search, :published, :draft, :featured, :primary_key, :content_column_field_names].include?(method) || super
        end

        def self.search(query)
          "searched: #{query}"
        end

        def self.published
          "published_scope"
        end

        def self.draft
          "draft_scope"
        end

        def self.featured
          "featured_scope"
        end

        def self.primary_key
          "id"
        end

        def self.content_column_field_names
          [:title, :created_at, :status]
        end

        def self.belongs_to_association_field_names
          []
        end

        def self.column_names
          %w[id title created_at status]
        end
      end

      # Mock scope that tracks calls
      class MockScope
        attr_reader :calls

        def initialize
          @calls = []
        end

        def where(*args, **kwargs)
          @calls << [:where, args, kwargs]
          self
        end

        def order(*args, **kwargs)
          @calls << [:order, args, kwargs]
          self
        end

        def public_send(method, **kwargs)
          @calls << [:public_send, method, kwargs]
          self
        end
      end

      def setup
        @request_path = "/posts"
      end

      # ==================== Initialization Tests ====================

      def test_initialization_with_empty_params
        query_object = QueryObject.new(MockResource, {}, @request_path)

        assert_empty query_object.scope_definitions
        assert_empty query_object.filter_definitions
        assert_empty query_object.sort_definitions
        assert_nil query_object.search_query
        assert_nil query_object.default_scope_name
      end

      def test_initialization_with_block
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published
          qo.define_scope :draft
        end

        assert_equal 2, query_object.scope_definitions.size
        assert query_object.scope_definitions.key?(:published)
        assert query_object.scope_definitions.key?(:draft)
      end

      def test_initialization_extracts_search_query
        query_object = QueryObject.new(MockResource, {search: "hello"}, @request_path)

        assert_equal "hello", query_object.search_query
      end

      def test_initialization_defines_search_for_searchable_resource
        query_object = QueryObject.new(MockResource, {}, @request_path)

        refute_nil query_object.search_filter
      end

      # ==================== Scope Definition Tests ====================

      def test_define_scope_with_symbol
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published
        end

        assert query_object.scope_definitions.key?(:published)
        assert_kind_of Plutonium::Query::ModelScope, query_object.scope_definitions[:published]
      end

      def test_define_scope_with_proc
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :recent, ->(scope) { scope.where("created_at > ?", 1.week.ago) }
        end

        assert query_object.scope_definitions.key?(:recent)
        assert_kind_of Plutonium::Query::AdhocBlock, query_object.scope_definitions[:recent]
      end

      def test_define_scope_with_default_option
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published, default: true
          qo.define_scope :draft
        end

        assert_equal "published", query_object.default_scope_name
      end

      def test_define_scope_last_default_wins
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published, default: true
          qo.define_scope :draft, default: true
        end

        assert_equal "draft", query_object.default_scope_name
      end

      def test_define_scope_raises_for_missing_model_scope
        error = assert_raises(RuntimeError) do
          QueryObject.new(MockResource, {}, @request_path) do |qo|
            qo.define_scope :nonexistent
          end
        end

        assert_match(/Cannot find scope :nonexistent/, error.message)
      end

      # ==================== Default Scope Selection Tests ====================

      def test_selected_scope_uses_default_when_no_params
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published, default: true
          qo.define_scope :draft
        end

        assert_equal "published", query_object.selected_scope
        refute query_object.all_scope_selected?
      end

      def test_selected_scope_uses_explicit_param_over_default
        query_object = QueryObject.new(MockResource, {scope: "draft"}, @request_path) do |qo|
          qo.define_scope :published, default: true
          qo.define_scope :draft
        end

        assert_equal "draft", query_object.selected_scope
        refute query_object.all_scope_selected?
      end

      def test_all_scope_selected_when_empty_scope_param
        query_object = QueryObject.new(MockResource, {scope: ""}, @request_path) do |qo|
          qo.define_scope :published, default: true
          qo.define_scope :draft
        end

        assert_nil query_object.selected_scope
        assert query_object.all_scope_selected?
      end

      def test_selected_scope_nil_when_no_default_and_no_params
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published
          qo.define_scope :draft
        end

        assert_nil query_object.selected_scope
        refute query_object.all_scope_selected?
      end

      # ==================== Filter Definition Tests ====================

      def test_define_filter_with_proc
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_filter(:status, ->(scope, value:) { scope.where(status: value) })
        end

        assert query_object.filter_definitions.key?(:status)
      end

      def test_define_filter_with_filter_class
        filter = Plutonium::Query::Filters::Text.new(key: :title, predicate: :contains)

        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_filter(:title, filter)
        end

        assert_equal filter, query_object.filter_definitions[:title]
      end

      # ==================== Sorter Definition Tests ====================

      def test_define_sorter_with_symbol
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_sorter :title
        end

        assert query_object.sort_definitions.key?(:title)
      end

      def test_define_sorter_with_custom_field
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_sorter :date, using: :created_at
        end

        assert query_object.sort_definitions.key?(:date)
      end

      def test_define_sorter_with_proc
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_sorter :custom, ->(scope, direction:) { scope.order(name: direction) }
        end

        assert query_object.sort_definitions.key?(:custom)
      end

      # ==================== Search Definition Tests ====================

      def test_define_search_with_proc
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_search(->(scope, search:) { scope.where("title LIKE ?", "%#{search}%") })
        end

        refute_nil query_object.search_filter
      end

      # ==================== Apply Method Tests ====================

      def test_apply_without_any_filters
        query_object = QueryObject.new(MockResource, {}, @request_path)
        scope = MockScope.new

        result = query_object.apply(scope, {})

        assert_equal scope, result
        assert_empty scope.calls
      end

      def test_apply_with_search
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_search(->(scope, search:) { scope.where(title: search) })
        end
        scope = MockScope.new

        query_object.apply(scope, {search: "hello"})

        assert_equal [[:where, [], {title: "hello"}]], scope.calls
      end

      def test_apply_with_model_scope
        query_object = QueryObject.new(MockResource, {scope: "published"}, @request_path) do |qo|
          qo.define_scope :published
        end
        scope = MockScope.new

        query_object.apply(scope, {})

        assert_equal [[:public_send, :published, {}]], scope.calls
      end

      def test_apply_with_default_scope
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published, default: true
        end
        scope = MockScope.new

        query_object.apply(scope, {})

        assert_equal [[:public_send, :published, {}]], scope.calls
      end

      def test_apply_without_scope_when_all_selected
        query_object = QueryObject.new(MockResource, {scope: ""}, @request_path) do |qo|
          qo.define_scope :published, default: true
        end
        scope = MockScope.new

        query_object.apply(scope, {})

        assert_empty scope.calls
      end

      def test_apply_with_adhoc_scope
        query_object = QueryObject.new(MockResource, {scope: "recent"}, @request_path) do |qo|
          qo.define_scope :recent, ->(scope) { scope.where(recent: true) }
        end
        scope = MockScope.new

        query_object.apply(scope, {})

        assert_equal [[:where, [], {recent: true}]], scope.calls
      end

      def test_apply_with_adhoc_scope_and_context
        context_value = nil
        mock_context = Object.new
        mock_context.define_singleton_method(:current_user) { "user123" }

        query_object = QueryObject.new(MockResource, {scope: "mine"}, @request_path) do |qo|
          qo.define_scope :mine, ->(scope) {
            context_value = current_user
            scope.where(user: current_user)
          }
        end
        scope = MockScope.new

        query_object.apply(scope, {}, context: mock_context)

        assert_equal "user123", context_value
        assert_equal [[:where, [], {user: "user123"}]], scope.calls
      end

      def test_apply_with_sorter
        query_object = QueryObject.new(MockResource, {sort_fields: ["title"], sort_directions: {title: "DESC"}}, @request_path) do |qo|
          qo.define_sorter :title
        end
        scope = MockScope.new

        query_object.apply(scope, {sort_fields: ["title"], sort_directions: {title: "DESC"}})

        assert_equal [[:order, [], {title: "DESC"}]], scope.calls
      end

      def test_apply_with_default_sort_array
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_sorter :created_at
        end
        query_object.default_sort_config = [:created_at, :desc]
        scope = MockScope.new

        query_object.apply(scope, {})

        assert_equal [[:order, [], {created_at: :desc}]], scope.calls
      end

      def test_apply_with_default_sort_proc
        query_object = QueryObject.new(MockResource, {}, @request_path)
        query_object.default_sort_config = ->(scope) { scope.order(id: :desc) }
        scope = MockScope.new

        query_object.apply(scope, {})

        assert_equal [[:order, [], {id: :desc}]], scope.calls
      end

      def test_apply_with_filter
        query_object = QueryObject.new(MockResource, {status: {query: "active"}}, @request_path) do |qo|
          qo.define_filter(:status, ->(scope, query:) { scope.where(status: query) })
        end
        scope = MockScope.new

        query_object.apply(scope, {status: {query: "active"}})

        assert_equal [[:where, [], {status: "active"}]], scope.calls
      end

      # ==================== URL Building Tests ====================

      def test_build_url_basic
        query_object = QueryObject.new(MockResource, {}, @request_path)

        url = query_object.build_url

        assert_equal "/posts?", url
      end

      def test_build_url_with_search
        query_object = QueryObject.new(MockResource, {search: "hello"}, @request_path)

        url = query_object.build_url

        assert_includes url, "q%5Bsearch%5D=hello"
      end

      def test_build_url_with_scope
        query_object = QueryObject.new(MockResource, {scope: "published"}, @request_path) do |qo|
          qo.define_scope :published
        end

        url = query_object.build_url

        assert_includes url, "q%5Bscope%5D=published"
      end

      def test_build_url_with_scope_option
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_scope :published
          qo.define_scope :draft
        end

        url = query_object.build_url(scope: :draft)

        assert_includes url, "q%5Bscope%5D=draft"
      end

      def test_build_url_with_all_scope_option
        query_object = QueryObject.new(MockResource, {scope: "published"}, @request_path) do |qo|
          qo.define_scope :published, default: true
        end

        url = query_object.build_url(scope: nil)

        assert_includes url, "q%5Bscope%5D="
      end

      def test_build_url_preserves_existing_params
        query_object = QueryObject.new(MockResource, {search: "test", scope: "published"}, @request_path) do |qo|
          qo.define_scope :published
        end

        url = query_object.build_url

        assert_includes url, "q%5Bsearch%5D=test"
        assert_includes url, "q%5Bscope%5D=published"
      end

      def test_build_url_with_sort
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_sorter :title
        end

        url = query_object.build_url(sort: :title)

        assert_includes url, "sort_fields"
        assert_includes url, "title"
      end

      # ==================== Sort Params Tests ====================

      def test_sort_params_for_undefined_sorter
        query_object = QueryObject.new(MockResource, {}, @request_path)

        result = query_object.sort_params_for(:undefined)

        assert_nil result
      end

      def test_sort_params_for_defined_sorter
        query_object = QueryObject.new(MockResource, {}, @request_path) do |qo|
          qo.define_sorter :title
        end

        result = query_object.sort_params_for(:title)

        assert_kind_of Hash, result
        assert result.key?(:url)
        assert result.key?(:reset_url)
        assert result.key?(:position)
        assert result.key?(:direction)
      end

      def test_sort_params_for_active_sorter
        query_object = QueryObject.new(MockResource, {sort_fields: ["title"], sort_directions: {title: "ASC"}}, @request_path) do |qo|
          qo.define_sorter :title
        end

        result = query_object.sort_params_for(:title)

        assert_equal 0, result[:position]
        assert_equal "ASC", result[:direction]
      end

      # ==================== Edge Cases ====================

      def test_scope_definitions_with_indifferent_access
        query_object = QueryObject.new(MockResource, {scope: "published"}, @request_path) do |qo|
          qo.define_scope :published
        end

        assert query_object.scope_definitions[:published]
        assert query_object.scope_definitions["published"]
      end

      def test_params_with_symbol_keys
        query_object = QueryObject.new(MockResource, {scope: "published", search: "test"}, @request_path) do |qo|
          qo.define_scope :published
        end

        assert_equal "test", query_object.search_query
        assert_equal "published", query_object.selected_scope
      end

      def test_blank_search_is_ignored
        query_object = QueryObject.new(MockResource, {search: ""}, @request_path)

        assert_nil query_object.search_query
      end

      def test_whitespace_search_is_ignored
        query_object = QueryObject.new(MockResource, {search: "   "}, @request_path)

        assert_nil query_object.search_query
      end

      def test_search_query_strips_whitespace
        query_object = QueryObject.new(MockResource, {search: "  hello world  "}, @request_path)

        assert_equal "hello world", query_object.search_query
      end

      def test_search_query_strips_leading_whitespace
        query_object = QueryObject.new(MockResource, {search: "  hello"}, @request_path)

        assert_equal "hello", query_object.search_query
      end

      def test_search_query_strips_trailing_whitespace
        query_object = QueryObject.new(MockResource, {search: "hello  "}, @request_path)

        assert_equal "hello", query_object.search_query
      end
    end
  end
end
