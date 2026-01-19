# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    module Filters
      class TextTest < Minitest::Test
        class MockScope
          attr_reader :calls

          def initialize
            @calls = []
          end

          def where(*args, **kwargs)
            @calls << [:where, args, kwargs]
            WhereChain.new(self)
          end

          class WhereChain
            def initialize(scope)
              @scope = scope
            end

            def not(*args, **kwargs)
              @scope.calls << [:where_not, args, kwargs]
              @scope
            end
          end
        end

        # ==================== Initialization Tests ====================

        def test_initialization_with_default_predicate
          filter = Text.new(key: :title)

          assert_equal :title, filter.key
        end

        def test_initialization_with_valid_predicate
          Text::VALID_PREDICATES.each do |predicate|
            filter = Text.new(key: :title, predicate: predicate)
            assert_equal :title, filter.key
          end
        end

        def test_initialization_with_invalid_predicate
          assert_raises(ArgumentError) do
            Text.new(key: :title, predicate: :invalid)
          end
        end

        # ==================== Apply Tests - :eq Predicate ====================

        def test_apply_eq_predicate
          filter = Text.new(key: :title, predicate: :eq)
          scope = MockScope.new

          filter.apply(scope, query: "hello")

          assert_equal [[:where, [], {title: "hello"}]], scope.calls
        end

        # ==================== Apply Tests - :not_eq Predicate ====================

        def test_apply_not_eq_predicate
          filter = Text.new(key: :title, predicate: :not_eq)
          scope = MockScope.new

          filter.apply(scope, query: "hello")

          assert_equal 2, scope.calls.size
          assert_equal [:where, [], {}], scope.calls[0]
          assert_equal [:where_not, [], {title: "hello"}], scope.calls[1]
        end

        # ==================== Apply Tests - :matches Predicate ====================

        def test_apply_matches_predicate
          filter = Text.new(key: :title, predicate: :matches)
          scope = MockScope.new

          filter.apply(scope, query: "*hello*")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          assert_equal ["title LIKE ?", "%hello%"], scope.calls[0][1]
        end

        # ==================== Apply Tests - :starts_with Predicate ====================

        def test_apply_starts_with_predicate
          filter = Text.new(key: :title, predicate: :starts_with)
          scope = MockScope.new

          filter.apply(scope, query: "hello")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          assert_equal ["title LIKE ?", "hello%"], scope.calls[0][1]
        end

        # ==================== Apply Tests - :ends_with Predicate ====================

        def test_apply_ends_with_predicate
          filter = Text.new(key: :title, predicate: :ends_with)
          scope = MockScope.new

          filter.apply(scope, query: "hello")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          assert_equal ["title LIKE ?", "%hello"], scope.calls[0][1]
        end

        # ==================== Apply Tests - :contains Predicate ====================

        def test_apply_contains_predicate
          filter = Text.new(key: :title, predicate: :contains)
          scope = MockScope.new

          filter.apply(scope, query: "hello")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          assert_equal ["title LIKE ?", "%hello%"], scope.calls[0][1]
        end

        # ==================== Apply Tests - :not_contains Predicate ====================

        def test_apply_not_contains_predicate
          filter = Text.new(key: :title, predicate: :not_contains)
          scope = MockScope.new

          filter.apply(scope, query: "hello")

          assert_equal 2, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          assert scope.calls[1][1].any? { |arg| arg.include?("LIKE") }
        end

        # ==================== LIKE Sanitization Tests ====================

        def test_sanitizes_percent_in_contains
          filter = Text.new(key: :title, predicate: :contains)
          scope = MockScope.new

          filter.apply(scope, query: "100%")

          assert_equal "%100\\%%", scope.calls[0][1][1]
        end

        def test_sanitizes_underscore_in_contains
          filter = Text.new(key: :title, predicate: :contains)
          scope = MockScope.new

          filter.apply(scope, query: "foo_bar")

          assert_equal "%foo\\_bar%", scope.calls[0][1][1]
        end

        def test_sanitizes_backslash_in_contains
          filter = Text.new(key: :title, predicate: :contains)
          scope = MockScope.new

          filter.apply(scope, query: "foo\\bar")

          assert_equal "%foo\\\\bar%", scope.calls[0][1][1]
        end

        # ==================== Input Definition Tests ====================

        def test_customize_inputs_defines_query_input
          filter = Text.new(key: :title, predicate: :contains)

          assert filter.defined_inputs.key?(:query)
        end
      end
    end
  end
end
