module Plutonium
  module Core
    module Fields
      module Inputs
        class SimpleFormAssociationInput < Base
          attr_reader :reflection

          def initialize(name, reflection:, **)
            @reflection = reflection
            super(name, **)
          end

          def render
            form.association name, **options
          end

          private

          def param
            raise NotImplementedError, "#{self.class}#param"
          end
        end
      end
    end
  end
end
