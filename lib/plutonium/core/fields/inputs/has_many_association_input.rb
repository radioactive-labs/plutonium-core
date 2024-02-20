module Plutonium
  module Core
    module Fields
      module Inputs
        class HasManyAssociationInput < SimpleFormAssociationInput
          private

          def param
            :"#{reflection.name.to_s.singularize}_ids"
          end
        end
      end
    end
  end
end
