module Plutonium
  module Core
    module Fields
      module Inputs
        class DateTimeInput < SimpleFormInput
          private

          def input_options
            {wrapper: :resource_multi_select, include_blank: true}
          end
        end
      end
    end
  end
end
