module Plutonium
  module Core
    module Fields
      module Inputs
        class CheckboxInput < SimpleFormInput
          private

          def input_options = {wrapper: :resource_checkbox}
        end
      end
    end
  end
end
