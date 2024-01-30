module Plutonium
  module Core
    module Fields
      module Renderers
        extend ActiveSupport::Autoload

        eager_autoload do
          autoload :BasicRenderer
        end
      end
    end
  end
end
