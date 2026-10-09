# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A `binary` column's size, never its bytes.
        class Binary < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            span(**attributes) do
              Plutonium::Translation.t("plutonium.ui.display.binary", size: ActiveSupport::NumberHelper.number_to_human_size(value.bytesize))
            end
          end
        end
      end
    end
  end
end
