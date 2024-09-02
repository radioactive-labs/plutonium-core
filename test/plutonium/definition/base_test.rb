require "test_helper"

class TestDefinition < Plutonium::Definition::Base
  class Form < Form
    def self.marco = "polo"
  end
end

module Plutonium
  module Definition
    class BaseTest < Minitest::Test
      def setup
        @definition = TestDefinition.new
        @form = TestDefinition::Form.new(:record, resource_fields: [])
      end

      def test_form_class
        assert_equal "polo", TestDefinition::Form.marco
        assert_equal TestDefinition::Form, @definition.send(:form_class)
        assert_kind_of Base::Form, @form
        assert_kind_of Phlexi::Form::Base, @form
      end

      def test_defineable_properties_inheritance
        assert_includes TestDefinition._defineable_props_store, :fields
        assert_includes TestDefinition._defineable_props_store, :inputs
        assert_includes TestDefinition._defineable_props_store, :filters
        assert_includes TestDefinition._defineable_props_store, :scopes
        assert_includes TestDefinition._defineable_props_store, :sorters
      end
    end
  end
end
