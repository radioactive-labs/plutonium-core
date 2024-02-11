module Plutonium
  module Core
    module Presenters
      module RendererDefinitions
        extend ActiveSupport::Concern

        def renderers_for(names)
          (names - renderer_definitions.keys).each do |name|
            define_renderer(name, renderer: autodiscover_field(name)[:renderer])
          end
          renderer_definitions.slice(*names)
        end

        private

        def renderer_definitions = @renderer_definitions ||= {}

        def define_renderer(name, renderer: nil, type: nil, **options)
          renderer_definitions[name] = if renderer.present?
            renderer
          elsif type.present? || options.present?
            Plutonium::Core::Fields::Renderers::Factory.for_resource_attribute(context.resource_class, name, type:, **options)
          else
            autodiscover_field(name)[:renderer]
          end
        end

        def renderer_defined?(name)
          renderer_definitions.key? name
        end
      end
    end
  end
end
