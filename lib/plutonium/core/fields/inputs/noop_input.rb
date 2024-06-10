module Plutonium
  module Core
    module Fields
      module Inputs
        class NoopInput
          def render
          end

          def collect(params)
            {}
          end
        end
      end
    end
  end
end
