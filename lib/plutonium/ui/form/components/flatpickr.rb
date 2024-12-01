# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class Flatpickr < Phlexi::Form::Components::Input
          private

          def build_input_attributes
            super
            attributes[:data_controller] = tokens(attributes[:data_controller], :flatpickr)
          end
        end
      end
    end
  end
end
