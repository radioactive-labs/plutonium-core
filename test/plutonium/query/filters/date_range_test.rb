# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    module Filters
      class DateRangeTest < Minitest::Test
        class MockScope
          attr_reader :calls

          def initialize
            @calls = []
          end

          def where(*args, **kwargs)
            @calls << [:where, [], kwargs]
            self
          end
        end

        # ==================== Initialization Tests ====================

        def test_initialization_with_defaults
          filter = DateRange.new(key: :created_at)

          assert_equal :created_at, filter.key
        end

        def test_initialization_with_custom_labels
          filter = DateRange.new(key: :created_at, from_label: "From Date", to_label: "To Date")

          assert_equal :created_at, filter.key
        end

        # ==================== Apply Tests - Both Dates ====================

        def test_apply_with_both_from_and_to
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: "2024-01-01", to: "2024-01-31")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
          refute_nil range.begin
          refute_nil range.end
        end

        def test_apply_with_date_objects
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: ::Date.new(2024, 1, 1), to: ::Date.new(2024, 1, 31))

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
        end

        # ==================== Apply Tests - From Date Only ====================

        def test_apply_with_from_only
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: "2024-01-01", to: nil)

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
          refute_nil range.begin
          assert_nil range.end
        end

        def test_apply_with_from_only_blank_to
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: "2024-01-01", to: "")

          assert_equal 1, scope.calls.size
          range = scope.calls[0][2][:created_at]
          assert_nil range.end
        end

        # ==================== Apply Tests - To Date Only ====================

        def test_apply_with_to_only
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: nil, to: "2024-01-31")

          assert_equal 1, scope.calls.size
          assert_equal :where, scope.calls[0][0]
          range = scope.calls[0][2][:created_at]
          assert_kind_of Range, range
          assert_nil range.begin
          refute_nil range.end
        end

        def test_apply_with_to_only_blank_from
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: "", to: "2024-01-31")

          assert_equal 1, scope.calls.size
          range = scope.calls[0][2][:created_at]
          assert_nil range.begin
        end

        # ==================== Apply Tests - No Dates ====================

        def test_apply_with_no_dates_returns_scope
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          result = filter.apply(scope, from: nil, to: nil)

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_blank_dates_returns_scope
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          result = filter.apply(scope, from: "", to: "")

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Apply Tests - Invalid Dates ====================

        def test_apply_with_invalid_from_date
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: "not-a-date", to: "2024-01-31")

          # Should still apply the valid to date
          assert_equal 1, scope.calls.size
          range = scope.calls[0][2][:created_at]
          assert_nil range.begin
          refute_nil range.end
        end

        def test_apply_with_invalid_to_date
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          filter.apply(scope, from: "2024-01-01", to: "not-a-date")

          # Should still apply the valid from date
          assert_equal 1, scope.calls.size
          range = scope.calls[0][2][:created_at]
          refute_nil range.begin
          assert_nil range.end
        end

        def test_apply_with_both_invalid_dates_returns_scope
          filter = DateRange.new(key: :created_at)
          scope = MockScope.new

          result = filter.apply(scope, from: "invalid", to: "also-invalid")

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Input Definition Tests ====================

        def test_customize_inputs_defines_from_input
          filter = DateRange.new(key: :created_at)

          assert filter.defined_inputs.key?(:from)
        end

        def test_customize_inputs_defines_to_input
          filter = DateRange.new(key: :created_at)

          assert filter.defined_inputs.key?(:to)
        end

        def test_customize_inputs_sets_date_type_for_from
          filter = DateRange.new(key: :created_at)
          input_options = filter.defined_inputs[:from][:options]

          assert_equal :date, input_options[:as]
        end

        def test_customize_inputs_sets_date_type_for_to
          filter = DateRange.new(key: :created_at)
          input_options = filter.defined_inputs[:to][:options]

          assert_equal :date, input_options[:as]
        end
      end
    end
  end
end
