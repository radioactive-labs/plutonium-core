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
        assert_includes TestDefinition._defineable_props_store, :exports
      end

      def test_export_defineable_prop_captures_label_and_block
        definition_class = Class.new(Plutonium::Definition::Base) do
          export :author, label: "Author email" do |record|
            record.author_email
          end
        end

        entry = definition_class.new.defined_exports[:author]
        assert_equal "Author email", entry[:options][:label]
        record = Struct.new(:author_email).new("a@example.com")
        assert_equal "a@example.com", entry[:block].call(record)
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
