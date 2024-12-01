# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        class Easymde < Phlexi::Form::Components::Base
          include Phlexi::Form::Components::Concerns::HandlesInput

          def view_template
            textarea(**attributes, data_controller: "easymde") { normalize_value(field.value) }
          end

          private

          def normalize_value(value)
            if value.respond_to?(:to_plain_text)
              value.to_plain_text
            else
              value.to_s
            end
          end
        end
      end
    end
  end
end
