module Plutonium
  module Core
    module Presenters
      module FieldDefinitions
        extend ActiveSupport::Concern
        include InputDefinitions
        include RendererDefinitions

        class_methods do
          private

          def autodiscover_field_cache = @autodiscover_field_cache ||= {}
        end

        private

        def define_field(name, type: nil, input: nil, renderer: nil, input_options: {}, renderer_options: {})
          define_input(name, type:, input:, **input_options)
          define_renderer(name, type:, renderer:, **renderer_options)
        end

        def autodiscover_field(name)
          autodiscover_field_cache[name] ||= {
            input: Plutonium::Core::Fields::Inputs.infer_for_resource_attribute(context.resource_class, name),
            renderer: Plutonium::Core::Fields::Renderers.infer_for_resource_attribute(context.resource_class, name)
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
