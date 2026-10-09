# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # An array value as a row of chips.
        class List < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          # DisplaysValue renders a multi-valued field once per item; a list
          # is one component for the whole array.
          def view_template
            items = normalize_value(field.value)
            return render(field.placeholder_tag(**@placeholder_attributes)) if items.empty?

            wrapped { render_value(items) }
          end

          def render_value(value)
            ul(**attributes) do
              value.each { |item| li(class: themed(:list_item)) { item.to_s } }
            end
          end

          private

          def normalize_value(value) = Array(value).compact_blank
        end
      end
    end
  end
end
