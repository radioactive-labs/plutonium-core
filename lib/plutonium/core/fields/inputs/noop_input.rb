module Plutonium
  module Core
    module Fields
      module Inputs
        class NoopInput
          def initialize(*)
          end

          def render(view_context, f, record, **)
          end

          def collect(params)
            {}
          end
        end
      end
    end
  end
end
