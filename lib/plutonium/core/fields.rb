module Plutonium
  module Core
    module Fields
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Input
        autoload :Inputs
        autoload :Renderer
        autoload :Renderers
      end
    end
  end
end
