module Plutonium
  module Core
    module Fields
      module Inputs
        class SimpleFormInput < Base
          def render
            form.input name, **options
          end
        end
      end
    end
  end
end
