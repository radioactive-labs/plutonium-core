require "test_helper"

module Plutonium
  module Definition
    class DefineablePropsTest < Minitest::Test
      class TestClass
        include DefineableProps

        defineable_prop :field
        defineable_prop :input
        defineable_prop :filter

        field :name, as: :string
        input :email, as: :email
        filter :status, type: :select

        def customize_fields
          field :custom_field, as: :integer
        end

        def customize_inputs
          input :custom_input, as: :boolean
        end

        def customize_filters
          filter :custom_filter, type: :text
        end
      end

      def setup
        @instance = TestClass.new
      end

      def test_class_level_property_definition
        assert_equal({name: {options: {as: :string}}}, TestClass.defined_fields)
        assert_equal({email: {options: {as: :email}}}, TestClass.defined_inputs)
        assert_equal({status: {options: {type: :select}}}, TestClass.defined_filters)
      end

      def test_instance_level_property_access
        assert_equal({name: {options: {as: :string}}, custom_field: {options: {as: :integer}}}, @instance.defined_fields)
        assert_equal({email: {options: {as: :email}}, custom_input: {options: {as: :boolean}}}, @instance.defined_inputs)
        assert_equal({status: {options: {type: :select}}, custom_filter: {options: {type: :text}}}, @instance.defined_filters)
      end

      def test_inheritance
        subclass = Class.new(TestClass) do
          field :subclass_field, as: :date
          input :subclass_input, as: :password
          filter :subclass_filter, type: :date_range

          def customize_fields
            super
            field :another_custom_field, as: :string
          end
        end

        instance = subclass.new

        assert_equal({
          name: {options: {as: :string}},
          subclass_field: {options: {as: :date}},
          custom_field: {options: {as: :integer}},
          another_custom_field: {options: {as: :string}}
        }, instance.defined_fields)

        assert_equal({
          email: {options: {as: :email}},
          subclass_input: {options: {as: :password}},
          custom_input: {options: {as: :boolean}}
        }, instance.defined_inputs)

        assert_equal({
          status: {options: {type: :select}},
          subclass_filter: {options: {type: :date_range}},
          custom_filter: {options: {type: :text}}
        }, instance.defined_filters)
      end

      def test_instance_level_property_definition
        @instance.field(:instance_field, as: :boolean)
        @instance.input(:instance_input, as: :text)
        @instance.filter(:instance_filter, type: :range)

        assert_includes @instance.defined_fields, :instance_field
        assert_includes @instance.defined_inputs, :instance_input
        assert_includes @instance.defined_filters, :instance_filter
      end

      def test_customize_definitions
        assert_includes @instance.defined_fields, :custom_field
        assert_includes @instance.defined_inputs, :custom_input
        assert_includes @instance.defined_filters, :custom_filter
      end

      def test_defineable_properties_list
        assert_equal [:fields, :inputs, :filters], TestClass._defineable_props_store
      end

      def test_property_method_generation
        assert TestClass.respond_to?(:field)
        assert TestClass.respond_to?(:input)
        assert TestClass.respond_to?(:filter)
        assert @instance.respond_to?(:field)
        assert @instance.respond_to?(:input)
        assert @instance.respond_to?(:filter)
      end

      def test_property_override_in_subclass
        subclass = Class.new(TestClass) do
          field :name, as: :text
          input :email, as: :string
          filter :status, type: :checkbox
        end

        instance = subclass.new

        assert_equal({as: :text}, instance.defined_fields[:name][:options])
        assert_equal({as: :string}, instance.defined_inputs[:email][:options])
        assert_equal({type: :checkbox}, instance.defined_filters[:status][:options])
      end

      def test_multiple_inheritance_levels
        subclass1 = Class.new(TestClass) do
          field :subclass1_field, as: :integer
        end

        subclass2 = Class.new(subclass1) do
          field :subclass2_field, as: :boolean
        end

        instance = subclass2.new

        assert_includes instance.defined_fields, :name
        assert_includes instance.defined_fields, :custom_field
        assert_includes instance.defined_fields, :subclass1_field
        assert_includes instance.defined_fields, :subclass2_field
      end

      def test_redefining_existing_property
        test_class = Class.new do
          include DefineableProps

          defineable_prop :field
        end

        test_class.field :existing_field, as: :string

        test_class.field :existing_field, as: :integer
        assert_equal({as: :integer}, test_class.defined_fields[:existing_field][:options])

        test_class.field :existing_field
        assert_equal({}, test_class.defined_fields[:existing_field][:options])
      end

      def test_defineable_property_with_non_standard_plural
        test_class = Class.new do
          include DefineableProps
        end

        test_class.defineable_prop :category

        assert_includes test_class._defineable_props_store, :categories
        assert test_class.respond_to?(:category)
        assert test_class.respond_to?(:defined_categories)
        assert test_class.new.respond_to?(:category)
        assert test_class.new.respond_to?(:defined_categories)
      end

      def test_property_with_block
        test_class = Class.new do
          include DefineableProps

          defineable_prop :field

          field :with_block, as: :string do
            "Block content"
          end
        end

        instance = test_class.new
        assert_equal "Block content", instance.defined_fields[:with_block][:block].call
      end

      def test_property_block_inheritance
        parent_class = Class.new do
          include DefineableProps

          defineable_prop :field

          field :parent_field, as: :string do
            "Parent block"
          end
        end

        child_class = Class.new(parent_class) do
          field :child_field, as: :string do
            "Child block"
          end
        end

        instance = child_class.new
        assert_equal "Parent block", instance.defined_fields[:parent_field][:block].call
        assert_equal "Child block", instance.defined_fields[:child_field][:block].call
      end

      def test_property_block_override
        parent_class = Class.new do
          include DefineableProps

          defineable_prop :field

          field :overridden_field, as: :string do
            "Parent block"
          end
        end

        child_class = Class.new(parent_class) do
          field :overridden_field, as: :integer do
            "Child block"
          end
        end

        instance = child_class.new
        assert_equal "Child block", instance.defined_fields[:overridden_field][:block].call
        assert_equal({as: :integer}, instance.defined_fields[:overridden_field][:options])
      end

      def test_property_without_block
        test_class = Class.new do
          include DefineableProps

          defineable_prop :field

          field :without_block, as: :string
        end

        instance = test_class.new
        assert_nil instance.defined_fields[:without_block][:block]
      end

      def test_instance_level_property_with_block
        test_class = Class.new do
          include DefineableProps

          defineable_prop :field
        end

        instance = test_class.new
        instance.field :instance_field, as: :string do
          "Instance block"
        end

        assert_equal "Instance block", instance.defined_fields[:instance_field][:block].call
      end

      def test_property_block_inheritance_without_child_block
        parent_class = Class.new do
          include DefineableProps

          defineable_prop :field

          field :inherited_field, as: :string do
            "Parent block"
          end
        end

        child_class = Class.new(parent_class) do
          field :inherited_field, as: :integer
        end

        parent_instance = parent_class.new
        child_instance = child_class.new

        assert_equal "Parent block", parent_instance.defined_fields[:inherited_field][:block].call
        assert_equal({as: :string}, parent_instance.defined_fields[:inherited_field][:options])

        assert_nil child_instance.defined_fields[:inherited_field][:block]
        assert_equal({as: :integer}, child_instance.defined_fields[:inherited_field][:options])
      end
    end
  end
end
