# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        class Color < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            div(**attributes, class: "flex items-center gap-2") do
              div(
                class: "w-6 h-6 rounded border border-[var(--pu-border)]",
                style: "background-color: #{value};"
              )
              span(class: "text-sm text-[var(--pu-text-muted)]") { value }
            end
          end
        end
      end
    end
  end
end
