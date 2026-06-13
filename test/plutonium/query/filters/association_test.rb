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

        # Mocks a resource_class whose association key does NOT match the target
        # class name (e.g. belongs_to :related_user, class_name: "User"). Only the
        # reflection knows the real class; key-inference would constantize the wrong
        # name and raise.
        class MockReflection
          def klass = MockCategory
        end

        class MockResourceWithReflection
          def self.reflect_on_association(_key) = MockReflection.new
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

        # ==================== Class Resolution Tests ====================

        def test_resolves_class_from_reflection_when_key_mismatches_class_name
          # No class_name given; key (:related_user) would constantize to a
          # nonexistent "RelatedUser". The reflection off resource_class is the
          # only thing that resolves it. Regression: the bridge must thread
          # resource_class through for this to work.
          filter = Association.new(key: :related_user, resource_class: MockResourceWithReflection)

          assert_equal MockCategory, filter.send(:association_class)
        end

        def test_explicit_class_name_takes_precedence_over_reflection
          filter = Association.new(
            key: :related_user,
            class_name: MockCategory,
            resource_class: MockResourceWithReflection
          )

          assert_equal MockCategory, filter.send(:association_class)
        end

        # ==================== Apply Tests - Single Value ====================

        def test_apply_with_single_value
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: "1")

          assert_equal [[:where, [], {category_id: ["1"]}]], scope.calls
        end

        def test_apply_with_integer_value
          filter = Association.new(key: :category, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: 42)

          assert_equal [[:where, [], {category_id: [42]}]], scope.calls
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

        def test_apply_with_all_blank_array_returns_scope
          filter = Association.new(key: :category, class_name: MockCategory, multiple: true)
          scope = MockScope.new

          result = filter.apply(scope, value: ["", ""])

          # All-blank array filters down to empty ids — skip the where
          # rather than emit `WHERE column IN ()` (invalid SQL).
          assert_equal scope, result
          assert_empty scope.calls
        end

        # ==================== Foreign Key Tests ====================

        def test_uses_correct_foreign_key
          filter = Association.new(key: :author, class_name: MockCategory)
          scope = MockScope.new

          filter.apply(scope, value: "5")

          assert_equal [[:where, [], {author_id: ["5"]}]], scope.calls
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
          filter = Association.new(key: :category, class_name: MockCategory, multiple: false)
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
