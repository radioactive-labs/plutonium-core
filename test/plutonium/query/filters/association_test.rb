# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Query
    module Filters
      class AssociationTest < Minitest::Test
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

        # Mock class for explicit class_name testing
        class MockCategory
          def self.all
            []
          end
        end

        # ==================== Initialization Tests ====================

        def test_initialization_with_explicit_class
          filter = Association.new(key: :category, class_name: MockCategory)

          assert_equal :category, filter.key
        end

        def test_initialization_with_multiple_true
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)

          assert_equal :category, filter.key
        end

        # ==================== Apply Tests - Single Value ====================

        def test_apply_with_single_value
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: "1")

          assert_equal [[:where, [], {category_id: "1"}]], scope.calls
        end

        def test_apply_with_integer_value
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: 42)

          assert_equal [[:where, [], {category_id: 42}]], scope.calls
        end

        def test_apply_with_blank_value_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          result = filter.apply(scope, value: "")

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_nil_value_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          result = filter.apply(scope, value: nil)

          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Apply Tests - Multiple Values ====================

        def test_apply_with_multiple_values
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          filter.apply(scope, value: ["1", "2", "3"])

          assert_equal [[:where, [], {category_id: ["1", "2", "3"]}]], scope.calls
        end

        def test_apply_with_multiple_values_filters_blank
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          filter.apply(scope, value: ["1", "", "3"])

          assert_equal [[:where, [], {category_id: ["1", "3"]}]], scope.calls
        end

        def test_apply_with_empty_array_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          result = filter.apply(scope, value: [])

          assert_equal scope, result
          assert_empty scope.calls
        end

        def test_apply_with_all_blank_array_filters_to_empty
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          filter.apply(scope, value: ["", ""])

          # Note: Currently the filter doesn't check if filtered array is empty
          # This could be considered a bug - WHERE column IN () is invalid SQL
          assert_equal [[:where, [], {category_id: []}]], scope.calls
        end

        # ==================== Foreign Key Tests ====================

        def test_uses_correct_foreign_key
          filter = Association.new(key: :author, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: "5")

          assert_equal [[:where, [], {author_id: "5"}]], scope.calls
        end

        # ==================== Input Definition Tests ====================

        def test_customize_inputs_defines_value_input
          filter = Association.new(key: :category, class_name: MockCategory)

          assert filter.defined_inputs.key?(:value)
        end

        def test_customize_inputs_sets_resource_select_type
          filter = Association.new(key: :category, class_name: MockCategory)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal :resource_select, input_options[:as]
        end

        def test_customize_inputs_passes_association_class
          filter = Association.new(key: :category, class_name: MockCategory)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal MockCategory, input_options[:association_class]
        end

        def test_customize_inputs_sets_multiple_option
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          input_options = filter.defined_inputs[:value][:options]

          assert input_options[:multiple]
        end

        def test_customize_inputs_sets_include_blank_for_single_select
          filter = Association.new(key: :category, class_name: MockCategory)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal "All", input_options[:include_blank]
        end

        def test_customize_inputs_no_include_blank_for_multiple_select
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          input_options = filter.defined_inputs[:value][:options]

          assert_equal false, input_options[:include_blank]
        end
      end
    end
  end
end
