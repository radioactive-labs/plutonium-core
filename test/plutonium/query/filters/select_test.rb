# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    module Filters
      class SelectTest < Minitest::Test
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

        def test_initialization_with_array_choices
          filter = Select.new(key: :status, choices: %w[draft published archived])

          assert_equal :status, filter.key
        end

        def test_initialization_with_proc_choices
          filter = Select.new(key: :status, choices: -> { %w[draft published] })

          assert_equal :status, filter.key
        end

        def test_initialization_with_multiple_true
          filter = Select.new(key: :tags, choices: %w[ruby rails js], multiple: true)

          assert_equal :tags, filter.key
        end

        def test_initialization_with_nil_choices
          filter = Select.new(key: :status, choices: nil)

          assert_equal :status, filter.key
        end

        # ==================== Apply Tests - Single Value ====================

        def test_apply_with_single_value
          filter = Select.new(key: :status, choices: %w[draft published])
          scope = MockScope.new

          filter.apply(scope, value: "published")

          assert_equal [[:where, [], {status: "published"}]], scope.calls
        end

        def test_apply_with_blank_value_returns_scope
          filter = Select.new(key: :status, choices: %w[draft published])
          scope = MockScope.new

          result = filter.apply(scope, value: "")

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_nil_value_returns_scope
          filter = Select.new(key: :status, choices: %w[draft published])
          scope = MockScope.new

          result = filter.apply(scope, value: nil)

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Apply Tests - Multiple Values ====================

        def test_apply_with_multiple_values
          filter = Select.new(key: :status, choices: %w[draft published archived], multiple: true)
          scope = MockScope.new

          filter.apply(scope, value: ["draft", "published"])

          assert_equal [[:where, [], {status: ["draft", "published"]}]], scope.calls
        end

        def test_apply_with_multiple_values_filters_blank
          filter = Select.new(key: :status, choices: %w[draft published archived], multiple: true)
          scope = MockScope.new

          filter.apply(scope, value: ["draft", "", "published"])

          assert_equal [[:where, [], {status: ["draft", "published"]}]], scope.calls
        end

        def test_apply_with_empty_array_returns_scope
          filter = Select.new(key: :status, choices: %w[draft published], multiple: true)
          scope = MockScope.new

          result = filter.apply(scope, value: [])

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Input Definition Tests ====================

        def test_customize_inputs_defines_value_input
          filter = Select.new(key: :status, choices: %w[draft published])

          assert filter.defined_inputs.key?(:value)
        end

        def test_customize_inputs_sets_select_type
          filter = Select.new(key: :status, choices: %w[draft published])
          input_options = filter.defined_inputs[:value][:options]

          assert_equal :select, input_options[:as]
        end

        def test_customize_inputs_passes_array_choices
          choices = %w[draft published]
          filter = Select.new(key: :status, choices: choices)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal choices, input_options[:choices]
        end

        def test_customize_inputs_passes_proc_choices
          choices_proc = -> { %w[draft published] }
          filter = Select.new(key: :status, choices: choices_proc)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal choices_proc, input_options[:choices]
        end

        def test_customize_inputs_handles_nil_choices
          filter = Select.new(key: :status, choices: nil)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal [], input_options[:choices]
        end

        def test_customize_inputs_sets_multiple_option
          filter = Select.new(key: :status, choices: %w[draft published], multiple: true)
          input_options = filter.defined_inputs[:value][:options]

          assert input_options[:multiple]
        end

        def test_customize_inputs_sets_include_blank_for_single_select
          filter = Select.new(key: :status, choices: %w[draft published])
          input_options = filter.defined_inputs[:value][:options]

          assert_equal "All", input_options[:include_blank]
        end

        def test_customize_inputs_no_include_blank_for_multiple_select
          filter = Select.new(key: :status, choices: %w[draft published], multiple: true)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal false, input_options[:include_blank]
        end
      end
    end
  end
end
