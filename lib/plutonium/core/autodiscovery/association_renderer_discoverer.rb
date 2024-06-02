module Plutonium
  module Core
    module Autodiscovery
      module AssociationRendererDiscoverer
        extend ActiveSupport::Concern
        include Discoverer

        class_methods do
          def autodiscovery_association_renderer_cache = @autodiscovery_association_renderer_cache ||= {}
        end

        private

        # If cache_discovery is enabled, use the class level cache that persists
        # between requests, otherwise use the instance one.
        def autodiscovery_association_renderer_cache
          if Rails.application.config.plutonium.cache_discovery
            self.class.autodiscovery_association_renderer_cache
          else
            @autodiscovery_association_renderer_cache ||= {}
          end
        end

        def autodiscover_association_renderer(name)
          autodiscovery_association_renderer_cache[name] ||=
            Plutonium::Core::Associations::Renderers::Factory.for_resource_association(resource_class, name)
        end
      end
    end
  end
end
