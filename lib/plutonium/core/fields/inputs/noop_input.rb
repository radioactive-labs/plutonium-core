module Plutonium
  module Core
    module Fields
      module Inputs
        class NoopInput
          def render(f, record)
          end

          def collect(params)
            {}
          end
        end
      end
    end
  end
end
