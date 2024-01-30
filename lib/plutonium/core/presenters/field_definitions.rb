module Plutonium
  module Core
    module Presenters
      module FieldDefinitions
        extend ActiveSupport::Concern

        class_methods do
          private

          def autodiscover_field_cache = @autodiscover_field_cache ||= {}
        end

        def field_inputs_for(names)
          (names - input_definitions.keys).each do |name|
            define_field_input(name, input: autodiscover_field(name)[:input])
          end
          input_definitions.slice(*names)
        end

        def field_renderers_for(names)
          (names - renderer_definitions.keys).each do |name|
            define_field_renderer(name, renderer: autodiscover_field(name)[:renderer])
          end
          renderer_definitions.slice(*names)
        end

        private

        def input_definitions = @input_definitions ||= {}

        def renderer_definitions = @renderer_definitions ||= {}

        def define_field(name, type: nil, input: nil, renderer: nil, input_options: {}, renderer_options: {})
          define_field_input(name, type:, input:, **input_options)
          define_field_renderer(name, type:, renderer:, **renderer_options)
        end

        def define_field_input(name, input: nil, type: nil, **options)
          input_definitions[name] = if input.present?
            input
          elsif type.present? || options.present?
            Plutonium::Core::Fields::Input.for_resource_attribute(context.resource_class, name, type:, **options)
          else
            autodiscover_field(name)[:input]
          end
        end

        def define_field_renderer(name, renderer: nil, type: nil, **options)
          renderer_definitions[name] = if renderer.present?
            renderer
          elsif type.present? || options.present?
            Plutonium::Core::Fields::Renderer.for_resource_attribute(context.resource_class, name, type:, **options)
          else
            autodiscover_field(name)[:renderer]
          end
        end

        def field_input_defined?(name)
          input_definitions.key? name
        end

        def field_renderer_defined?(name)
          renderer_definitions.key? name
        end

        def autodiscover_field(name)
          autodiscover_field_cache[name] ||= {
            input: Plutonium::Core::Fields::Input.for_resource_attribute(context.resource_class, name),
            renderer: Plutonium::Core::Fields::Renderer.for_resource_attribute(context.resource_class, name)
          }
        end

        # If cache_discovery is enabled, use the class level cache that persists
        # between requests, otherwise use the instance one.
        def autodiscover_field_cache
          if Plutonium.cache_discovery
            self.class.autodiscover_field_cache
          else
            @autodiscover_field_cache ||= {}
          end
        end
      end
    end
  end
end
