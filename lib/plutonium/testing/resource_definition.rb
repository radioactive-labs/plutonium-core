# frozen_string_literal: true

require "plutonium/testing/dsl"

module Plutonium
  module Testing
    module ResourceDefinition
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_definition_tests!
        end

        def install_definition_tests!
          test "definition: class is constantize-able" do
            assert definition_class, "Expected #{resource_class}Definition to exist"
          end

          test "definition: every defineable prop dictionary is queryable" do
            klass = definition_class
            klass._defineable_props_store.each do |prop_plural|
              dict = klass.public_send("defined_#{prop_plural}")
              assert dict.is_a?(Hash), "defined_#{prop_plural} must be Hash, got #{dict.class}"
            end
          end

          test "definition: declared fields exist on the model" do
            klass = definition_class
            return unless klass.respond_to?(:defined_fields)
            klass.defined_fields.each_key do |field_name|
              next if field_name == :id
              assert resource_class.column_names.include?(field_name.to_s) ||
                     resource_class.method_defined?(field_name) ||
                     resource_class.reflect_on_association(field_name),
                "Field :#{field_name} declared in #{klass} but not defined on #{resource_class}"
            end
          end
        end

        def resource_class
          resource_tests_config.fetch(:resource)
        end

        def definition_class
          @definition_class ||= "#{resource_class.name}Definition".constantize
        end
      end

      def resource_class
        self.class.resource_class
      end

      def definition_class
        self.class.definition_class
      end
    end
  end
end
