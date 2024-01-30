module Plutonium
  module Core
    module Fields
      module Inputs
        extend ActiveSupport::Autoload

        eager_autoload do
          autoload :BasicInput
          autoload :AssociationInput
        end
      end
    end
  end
end
