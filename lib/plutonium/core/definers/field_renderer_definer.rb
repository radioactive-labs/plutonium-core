module Plutonium
  module Core
    module Definers
      module FieldRendererDefiner
        extend ActiveSupport::Concern
        include Plutonium::Core::Autodiscovery::RendererDiscoverer

        def defined_field_renderers_for(*names)
          (names - field_renderer_definitions.keys).each do |name|
            define_field_renderer(name, renderer: autodiscover_renderer(name))
          end
          field_renderer_definitions.slice(*names)
        end

        private

        def field_renderer_definitions = @field_renderer_definitions ||= {}

        def define_field_renderer(name, renderer: nil, type: nil, **options)
          field_renderer_definitions[name] = if renderer.present?
            renderer
          elsif type.present?
            Plutonium::Core::Fields::Renderers::Factory.build(name, type:, **options)
          elsif options.present?
            Plutonium::Core::Fields::Renderers::Factory.for_resource_attribute(resource_class, name, **options)
          else
            autodiscover_renderer(name)
          end
        end

        def field_renderer_defined?(name)
          field_renderer_definitions.key? name
        end
      end
    end
  end
end
