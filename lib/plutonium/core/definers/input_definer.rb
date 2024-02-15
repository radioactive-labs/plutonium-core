module Plutonium
  module Core
    module Definers
      module InputDefiner
        extend ActiveSupport::Concern
        include Plutonium::Core::Autodiscovery::InputDiscoverer

        def defined_inputs_for(names)
          (names - input_definitions.keys).each do |name|
            define_input(name, input: autodiscover_input(name))
          end
          input_definitions.slice(*names)
        end

        private

        def input_definitions = @input_definitions ||= {}

        def define_input(name, input: nil, type: nil, **options)
          input_definitions[name] = if input.present?
            input
          elsif type.present?
            Plutonium::Core::Fields::Inputs.build(name, type:, **options)
          elsif options.present?
            Plutonium::Core::Fields::Inputs::Factory.for_resource_attribute(context.resource_class, name, **options)
          else
            autodiscover_input(name)
          end
        end

        def input_defined?(name)
          input_definitions.key? name
        end
      end
    end
  end
end
