module Plutonium
  module Core
    module Definers
      module FieldInputDefiner
        extend ActiveSupport::Concern
        include Plutonium::Core::Autodiscovery::InputDiscoverer

        class InputDefinitions
          def initialize(hash)
            @hash = hash
          end

          def []=(key, value)
            hash[key] = value
          end

          def [](key)
            hash[key]
          end

          def slice(*)
            self.class.new(hash.slice(*))
          end

          def collect_all(params)
            hash.values.map { |input| input.collect params }.reduce(:merge) || {}
          end

          def size
            hash.size
          end

          def keys
            hash.keys
          end

          def values
            hash.values
          end

          def blank?
            hash.blank?
          end

          private

          attr_reader :hash
        end

        def defined_field_inputs_for(*names)
          (names - input_definitions.keys).each do |name|
            define_field_input(name, input: autodiscover_input(name))
          end
          input_definitions.slice(*names)
        end

        def define_field_input(name, input: nil, type: nil, **options)
          input_definitions[name] = if input.present?
            input
          elsif type.present?
            Plutonium::Core::Fields::Inputs::Factory.build(name, type:, **options)
          elsif options.present?
            Plutonium::Core::Fields::Inputs::Factory.for_resource_attribute(resource_class, name, **options)
          else
            autodiscover_input(name)
          end
        end

        def input_defined?(name)
          input_definitions.key? name
        end

        def input_definitions = @input_definitions ||= InputDefinitions.new({})
      end
    end
  end
end
