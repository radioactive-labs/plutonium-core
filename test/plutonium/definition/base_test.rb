require "test_helper"

class TestDefinition < Plutonium::Definition::Base
  class Form < Plutonium::UI::Form::Resource
    def self.marco = "polo"
  end
end

module Plutonium
  module Definition
    class BaseTest < Minitest::Test
      def setup
        @definition = TestDefinition.new
      end

      def test_form_class
        assert_equal "polo", TestDefinition::Form.marco
        assert_equal TestDefinition::Form, @definition.send(:form_class)
        assert TestDefinition::Form < Plutonium::UI::Form::Resource
      end

      def test_defineable_properties_inheritance
        assert_includes TestDefinition._defineable_props_store, :fields
        assert_includes TestDefinition._defineable_props_store, :inputs
        assert_includes TestDefinition._defineable_props_store, :filters
        assert_includes TestDefinition._defineable_props_store, :scopes
        assert_includes TestDefinition._defineable_props_store, :sorts
      end

      def test_page_classes
        assert_equal TestDefinition::IndexPage, @definition.index_page_class
        assert_equal TestDefinition::NewPage, @definition.new_page_class
        assert_equal TestDefinition::ShowPage, @definition.show_page_class
        assert_equal TestDefinition::EditPage, @definition.edit_page_class
      end

      def test_collection_class
        assert_equal TestDefinition::Table, @definition.collection_class
      end

      def test_detail_class
        assert_equal TestDefinition::Display, @definition.detail_class
      end
    end
  end
end
