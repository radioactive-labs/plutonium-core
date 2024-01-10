module Plutonium
  module UI
    module Concerns
      module DefinesFields
        def self.included(base)
          base.send :attr_reader, :model_class
        end

        def with_fields(*names)
          names.flatten.each do |name|
            define_field(Plutonium::UI::Field.for_attribute(model_class, name)) unless field_defined?(name)
            @enabled_fields[name] = true
          end
          self
        end

        def define_field(definition)
          @field_definitions[definition.name] = definition
          self
        end

        def only_fields!(*names)
          @enabled_fields.slice!(*names.flatten)
          self
        end

        def except_fields!(*names)
          @enabled_fields.except!(*names.flatten)
          self
        end

        def fields
          @field_definitions.slice(*@enabled_fields.keys)
        end

        def field?(name)
          @enabled_fields.key? name
        end

        def field_defined?(name)
          @field_definitions.key? name
        end

        private

        def initialize_fields_definer(model_class)
          @model_class = model_class
          @enabled_fields = {} # using hash since keys act as an ordered set
          @field_definitions = {}
        end
      end
    end
  end
end
