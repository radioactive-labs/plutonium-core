module Plutonium
  module Core
    module Fields
      module Inputs
        class BelongsToAssociationInput < SimpleFormAssociationInput
          private

          def param
            (reflection.respond_to?(:options) && reflection.options[:foreign_key]) || :"#{reflection.name}_id"
          end
        end
      end
    end
  end
end
