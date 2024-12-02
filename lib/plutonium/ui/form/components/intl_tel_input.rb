# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class IntlTelInput < Phlexi::Form::Components::Input
          def view_template
            div(data_controller: "intl-tel-input") {
              super
            }
          end

          private

          def build_input_attributes
            super
            attributes[:data_intl_tel_input_target] = tokens(attributes[:data_intl_tel_input_target], :input)
          end
        end
      end
    end
  end
end
