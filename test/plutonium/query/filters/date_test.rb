# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    module Filters
      class DateTest < Minitest::Test
        class MockScope
          attr_reader :calls

          def initialize
            @calls = []
          end

          def where(*args, **kwargs)
            @calls << [:where, [], kwargs]
            WhereChain.new(self)
          end

          class WhereChain
            def initialize(scope)
              @scope = scope
            end

            def not(*args, **kwargs)
              @scope.calls << [:where_not, [], kwargs]
              @scope
            end
          end
        end

        # ==================== Initialization Tests ====================

        def test_initialization_with_default_predicate
          filter = Date.new(key: :created_at)

          assert_equal :created_at, filter.key
        end

        def test_initialization_with_valid_predicates
          Date::VALID_PREDICATES.each do |predicate|
            filter = Date.new(key: :created_at, predicate: predicate)
            assert_equal :created_at, filter.key
          end
        end

        def test_initialization_with_invalid_predicate
          assert_raises(ArgumentError) do
            Date.new(key: :created_at, predicate: :invalid)
          end
        end

        # ==================== Apply Tests - :eq Predicate ====================

        def test_apply_eq_predicate_with_string_date
          filter = Date.new(key: :created_at, predicate: :eq)
          scope = MockScope.new

          filter.apply(scope, value: "2024-01-15")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          # Should use all_day range
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
        end

        def test_apply_eq_predicate_with_date_object
          filter = Date.new(key: :created_at, predicate: :eq)
          scope = MockScope.new

          filter.apply(scope, value: ::Date.new(2024, 1, 15))

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
        end

        # ==================== Apply Tests - :not_eq Predicate ====================

        def test_apply_not_eq_predicate
          filter = Date.new(key: :created_at, predicate: :not_eq)
          scope = MockScope.new

          filter.apply(scope, value: "2024-01-15")

          assert_equal 2, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          assert_equal :where_not, scope.calls[1][0]
        end

        # ==================== Apply Tests - :lt Predicate ====================

        def test_apply_lt_predicate
          filter = Date.new(key: :created_at, predicate: :lt)
          scope = MockScope.new

          filter.apply(scope, value: "2024-01-15")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          # Should use beginless range
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
          assert_nil range.begin
        end

        # ==================== Apply Tests - :lteq Predicate ====================

        def test_apply_lteq_predicate
          filter = Date.new(key: :created_at, predicate: :lteq)
          scope = MockScope.new

          filter.apply(scope, value: "2024-01-15")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
        end

        # ==================== Apply Tests - :gt Predicate ====================

        def test_apply_gt_predicate
          filter = Date.new(key: :created_at, predicate: :gt)
          scope = MockScope.new

          filter.apply(scope, value: "2024-01-15")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          # Should use endless range
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
          assert_nil range.end
        end

        # ==================== Apply Tests - :gteq Predicate ====================

        def test_apply_gteq_predicate
          filter = Date.new(key: :created_at, predicate: :gteq)
          scope = MockScope.new

          filter.apply(scope, value: "2024-01-15")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
          assert_nil range.end
        end

        # ==================== Apply Tests - Blank Values ====================

        def test_apply_with_blank_value_returns_scope
          filter = Date.new(key: :created_at)
          scope = MockScope.new

          result = filter.apply(scope, value: "")

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_nil_value_returns_scope
          filter = Date.new(key: :created_at)
          scope = MockScope.new

          result = filter.apply(scope, value: nil)

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_invalid_date_string_returns_scope
          filter = Date.new(key: :created_at)
          scope = MockScope.new

          result = filter.apply(scope, value: "not-a-date")

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Input Definition Tests ====================

        def test_customize_inputs_defines_value_input
          filter = Date.new(key: :created_at)

          assert filter.defined_inputs.key?(:value)
        end

        def test_customize_inputs_sets_date_type
          filter = Date.new(key: :created_at)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal :date, input_options[:as]
        end
      end
    end
  end
end
