module Plutonium
  module Core
    module Fields
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Inputs
        autoload :Renderers
      end
    end
  end
end
