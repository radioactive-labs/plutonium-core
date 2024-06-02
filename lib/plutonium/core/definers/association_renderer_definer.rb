module Plutonium
  module Core
    module Definers
      module AssociationRendererDefiner
        extend ActiveSupport::Concern
        include Plutonium::Core::Autodiscovery::AssociationRendererDiscoverer

        def defined_association_renderers_for(*names)
          (names - association_renderer_definitions.keys).each do |name|
            define_association_renderer(name, renderer: autodiscover_association_renderer(name))
          end
          association_renderer_definitions.slice(*names)
        end

        private

        def association_renderer_definitions = @association_renderer_definitions ||= {}

        def define_association_renderer(name, renderer: nil, **options)
          association_renderer_definitions[name] = if renderer.present?
            renderer
          else
            autodiscover_association_renderer(name)
          end
        end

        def association_renderer_defined?(name)
          association_renderer_definitions.key? name
        end
      end
    end
  end
end
