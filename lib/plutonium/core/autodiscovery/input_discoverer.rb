module Plutonium
  module Core
    module Autodiscovery
      module InputDiscoverer
        extend ActiveSupport::Concern
        include Discoverer

        class_methods do
          def autodiscovery_input_cache = @autodiscovery_input_cache ||= {}
        end

        private

        # If cache_discovery is enabled, use the class level cache that persists
        # between requests, otherwise use the instance one.
        def autodiscovery_input_cache
          if Plutonium::Config.cache_discovery
            self.class.autodiscovery_input_cache
          else
            @autodiscovery_input_cache ||= {}
          end
        end

        def autodiscover_input(name)
          autodiscovery_input_cache[name] ||=
            Plutonium::Core::Fields::Inputs::Factory.for_resource_attribute(resource_class, name)
        end
      end
    end
  end
end
