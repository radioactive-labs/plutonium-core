module Plutonium
  module Core
    module Fields
      module Inputs
        class SimpleFormAssociationInput < Base
          attr_reader :reflection

          def initialize(name, reflection:, **user_options)
            @reflection = reflection
            super(name, **user_options)
          end

          def render(view_context, f, record, **opts)
            opts = options.deep_merge opts
            f.association name, **opts
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
