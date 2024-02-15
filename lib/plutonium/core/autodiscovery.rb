module Plutonium
  module Core
    module Autodiscovery
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Discoverer
        autoload :InputDiscoverer
        autoload :RendererDiscoverer
      end
    end
  end
end
