require "test_helper"

module Plutonium
  module Definition
    class BaseTest < Minitest::Test
      class TestDefinition < Base
        class Form < Form
          def self.marco = "polo"
        end
      end

      def setup
        @definition = TestDefinition.new
      end

      def test_form_class
        assert_equal "polo", TestDefinition::Form.marco
        assert_equal TestDefinition::Form, @definition.send(:form_class)
        assert_kind_of Base::Form, TestDefinition::Form.new(:record)
        assert_kind_of Phlexi::Form::Base, TestDefinition::Form.new(:record)
      end

      def test_defineable_properties_inheritance
        assert_includes TestDefinition.defineable_properties, :fields
        assert_includes TestDefinition.defineable_properties, :inputs
        assert_includes TestDefinition.defineable_properties, :filters
        assert_includes TestDefinition.defineable_properties, :scopes
        assert_includes TestDefinition.defineable_properties, :sorters
      end
    end
  end
end
