module Plutonium
  module Core
    module Autodiscovery
      module RendererDiscoverer
        extend ActiveSupport::Concern
        include Discoverer

        class_methods do
          def autodiscovery_renderer_cache = @autodiscovery_renderer_cache ||= {}
        end

        private

        # If cache_discovery is enabled, use the class level cache that persists
        # between requests, otherwise use the instance one.
        def autodiscovery_renderer_cache
          if Plutonium.configuration.cache_discovery
            self.class.autodiscovery_renderer_cache
          else
            @autodiscovery_renderer_cache ||= {}
          end
        end

        def autodiscover_renderer(name)
          autodiscovery_renderer_cache[name] ||=
            Plutonium::Core::Fields::Renderers::Factory.for_resource_attribute(resource_class, name)
        end
      end
    end
  end
end
