module Plutonium
  module UI
    module Concerns
      module DefinesInputs
        def self.included(base)
          base.send :attr_reader, :model_class
        end

        def with_inputs(*names)
          names.flatten.each do |name|
            define_input(Pu::UI::Input.for_attribute(model_class, name)) unless input_defined?(name)
            @enabled_inputs[name] = true
          end
          self
        end

        def define_input(definition)
          @input_definitions[definition.name] = definition
          self
        end

        def only_inputs!(*names)
          @enabled_inputs.slice!(*names.flatten)
          self
        end

        def except_inputs!(*names)
          @enabled_inputs.except!(*names.flatten)
          self
        end

        def inputs
          @input_definitions.slice(*@enabled_inputs.keys)
        end

        def input?(name)
          @enabled_inputs.key? name
        end

        def input_defined?(name)
          @input_definitions.key? name
        end

        private

        def initialize_inputs_definer(model_class)
          @model_class = model_class
          @enabled_inputs = {} # using hash since keys act as an ordered set
          @input_definitions = {}
        end
      end
    end
  end
end
