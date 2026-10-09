# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A Hash as a two-column list of keys and values: hstore columns, or
        # any hash-valued field declared `as: :key_value`. Nested hashes and
        # arrays stay on one line as compact JSON.
        class KeyValue < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            dl(**attributes) do
              value.each do |key, item|
                dt(class: themed(:key_value_key)) { key.to_s }
                dd(class: themed(:key_value_value)) { format_item(item) }
              end
            end
          end

          private

          def normalize_value(value) = value.to_h

          def format_item(item)
            case item
            when nil then "—"
            when Hash, Array then code(class: themed(:key_value_nested)) { item.to_json }
            else item.to_s
            end
          end
        end
      end
    end
  end
end
