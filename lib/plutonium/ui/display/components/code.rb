# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A value in monospace with a copy button: IDs, keys, references.
        class Code < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            div(**attributes, data: {controller: "clipboard"}) do
              code(class: themed(:code_value), data: {clipboard_target: "source"}) { value }
              button(type: :button, class: themed(:code_copy), data: {action: "clipboard#copy"}) do
                Plutonium::Translation.t("plutonium.ui.display.code.copy")
              end
            end
          end
        end
      end
    end
  end
end
