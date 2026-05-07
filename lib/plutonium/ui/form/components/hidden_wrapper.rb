# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # Wrapper for fields configured as `as: :hidden`. Emits a hidden div
        # containing only the input — no label, no hint, no error chrome.
        # `hidden: true` (HTML5) sets `display: none` so the wrapper is
        # excluded from CSS Grid / Flex layout, not just visually hidden.
        class HiddenWrapper < Phlexi::Form::Components::Base
          def view_template(&block)
            div(hidden: true) do
              yield(field) if block
            end
          end

          # No id needed for a layout-suppressed wrapper.
          def build_attributes
          end
        end
      end
    end
  end
end
