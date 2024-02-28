module Plutonium
  module Core
    module Definers
      module RendererDefiner
        extend ActiveSupport::Concern
        include Plutonium::Core::Autodiscovery::RendererDiscoverer

        def defined_renderers_for(*names)
          (names - renderer_definitions.keys).each do |name|
            define_renderer(name, renderer: autodiscover_renderer(name))
          end
          renderer_definitions.slice(*names)
        end

        private

        def renderer_definitions = @renderer_definitions ||= {}

        def define_renderer(name, renderer: nil, type: nil, **options)
          renderer_definitions[name] = if renderer.present?
            renderer
          elsif type.present?
            Plutonium::Core::Fields::Renderers::Factory.build(name, type:, **options)
          elsif options.present?
            Plutonium::Core::Fields::Renderers::Factory.for_resource_attribute(resource_class, name, **options)
          else
            autodiscover_renderer(name)
          end
        end

        def renderer_defined?(name)
          renderer_definitions.key? name
        end
      end
    end
  end
end
