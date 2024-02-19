module Plutonium
  module Core
    module Fields
      module Inputs
        extend ActiveSupport::Autoload

        eager_autoload do
          autoload :AssociationInput
          autoload :AttachmentInput
          autoload :BasicInput
          autoload :BelongsToInput
          autoload :Factory
          autoload :HasManyInput
          autoload :NoopInput
        end
      end
    end
  end
end
