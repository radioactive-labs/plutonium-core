module Plutonium
  module Core
    module Fields
      module Renderers
        extend ActiveSupport::Autoload

        eager_autoload do
          autoload :AssociationRenderer
          autoload :AttachmentRenderer
          autoload :BasicRenderer
          autoload :Factory
        end
      end
    end
  end
end
