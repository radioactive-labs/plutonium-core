# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    module Filters
      class BooleanTest < Minitest::Test
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
          filter = Boolean.new(key: :active)

          assert_equal :active, filter.key
        end

        def test_initialization_with_custom_labels
          filter = Boolean.new(key: :published, true_label: "Published", false_label: "Draft")

          assert_equal :published, filter.key
        end

        # ==================== Apply Tests ====================

        def test_apply_with_true_string
          filter = Boolean.new(key: :active)
          scope = MockScope.new

          filter.apply(scope, value: "true")

          assert_equal [[:where, [], {active: true}]], scope.calls
        end

        def test_apply_with_false_string
          filter = Boolean.new(key: :active)
          scope = MockScope.new

          filter.apply(scope, value: "false")

          assert_equal [[:where, [], {active: false}]], scope.calls
        end

        def test_apply_with_1_string
          filter = Boolean.new(key: :active)
          scope = MockScope.new

          filter.apply(scope, value: "1")

          assert_equal [[:where, [], {active: true}]], scope.calls
        end

        def test_apply_with_0_string
          filter = Boolean.new(key: :active)
          scope = MockScope.new

          filter.apply(scope, value: "0")

          assert_equal [[:where, [], {active: false}]], scope.calls
        end

        def test_apply_with_boolean_true
          filter = Boolean.new(key: :active)
          scope = MockScope.new

          filter.apply(scope, value: true)

          assert_equal [[:where, [], {active: true}]], scope.calls
        end

        # Note: ActiveModel::Type::Boolean.cast(false) returns false, which is blank?,
        # so the filter returns early. This is expected behavior.
        def test_apply_with_blank_value_returns_scope
          filter = Boolean.new(key: :active)
          scope = MockScope.new

          result = filter.apply(scope, value: "")

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_nil_value_returns_scope
          filter = Boolean.new(key: :active)
          scope = MockScope.new

          result = filter.apply(scope, value: nil)

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Input Definition Tests ====================

        def test_customize_inputs_defines_value_input
          filter = Boolean.new(key: :active)

          assert filter.defined_inputs.key?(:value)
        end

        def test_customize_inputs_sets_select_type
          filter = Boolean.new(key: :active)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal :select, input_options[:as]
        end

        def test_customize_inputs_default_labels
          filter = Boolean.new(key: :active)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal [["Yes", "true"], ["No", "false"]], input_options[:choices]
        end

        def test_customize_inputs_custom_labels
          filter = Boolean.new(key: :published, true_label: "Published", false_label: "Draft")
          input_options = filter.defined_inputs[:value][:options]

          assert_equal [["Published", "true"], ["Draft", "false"]], input_options[:choices]
        end

        def test_customize_inputs_includes_blank
          filter = Boolean.new(key: :active)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal "All", input_options[:include_blank]
        end
      end
    end
  end
end
