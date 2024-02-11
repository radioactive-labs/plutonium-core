module Plutonium
  module Core
    module Fields
      module Renderers
        extend ActiveSupport::Autoload

        eager_autoload do
          autoload :Factory
          autoload :BasicRenderer
          autoload :AssociationRenderer
        end
      end
    end
  end
end
