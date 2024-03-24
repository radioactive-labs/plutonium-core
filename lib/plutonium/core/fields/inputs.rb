module Plutonium
  module Core
    module Fields
      module Inputs
        extend ActiveSupport::Autoload

        eager_autoload do
          autoload :AttachmentInput
          autoload :Base
          autoload :BelongsToAssociationInput
          autoload :DateTimeInput
          autoload :Factory
          autoload :HasManyAssociationInput
          autoload :NoopInput
          autoload :SimpleFormAssociationInput
          autoload :SimpleFormInput
        end
      end
    end
  end
end
