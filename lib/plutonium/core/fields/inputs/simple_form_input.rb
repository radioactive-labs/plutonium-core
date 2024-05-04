module Plutonium
  module Core
    module Fields
      module Inputs
        class SimpleFormInput < Base
          def render(view_context, f, record, **opts)
            opts = options.deep_merge opts
            f.input name, **opts
          end
        end
      end
    end
  end
end
