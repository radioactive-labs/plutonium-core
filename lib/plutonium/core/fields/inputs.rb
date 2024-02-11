module Plutonium
  module Core
    module Fields
      module Inputs
        extend ActiveSupport::Autoload

        eager_autoload do
          autoload :Factory
          autoload :AssociationInput
          autoload :BasicInput
          autoload :BelongsToInput
          autoload :HasManyInput
          autoload :NoopInput
        end
      end
    end
  end
end
