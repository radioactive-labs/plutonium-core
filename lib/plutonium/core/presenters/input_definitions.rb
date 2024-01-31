module Plutonium
  module Core
    module Presenters
      module InputDefinitions
        extend ActiveSupport::Concern

        def inputs_for(names)
          (names - input_definitions.keys).each do |name|
            define_input(name, input: autodiscover_field(name)[:input])
          end
          input_definitions.slice(*names)
        end

        private

        def input_definitions = @input_definitions ||= {}

        def define_input(name, input: nil, type: nil, **options)
          input_definitions[name] = if input.present?
            input
          elsif type.present? || options.present?
            Plutonium::Core::Fields::Input.for_resource_attribute(context.resource_class, name, type:, **options)
          else
            autodiscover_field(name)[:input]
          end
        end

        def input_defined?(name)
          input_definitions.key? name
        end
      end
    end
  end
end
