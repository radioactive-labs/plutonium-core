# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        class Color < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          # Hex, a named color, or a plain rgb()/hsl() call. The value is
          # interpolated into `style:`, so anything else (a `;` or `url(`)
          # would let a stored string inject arbitrary CSS.
          CSS_COLOR = /\A(?:#\h{3,8}|[a-z]+|(?:rgb|hsl)a?\([\d\s.,%\/]+\))\z/i

          def render_value(value)
            div(**attributes) do
              div(class: themed(:color_indicator), style: swatch_style(value))
              span(class: themed(:color_label)) { value }
            end
          end

          private

          def swatch_style(value)
            "background-color: #{value};" if CSS_COLOR.match?(value)
          end
        end
      end
    end
  end
end
