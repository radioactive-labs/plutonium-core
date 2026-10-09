# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A `has_rich_text` field. Action Text renders and sanitizes the HTML
        # (including attachments) through its content layout.
        class RichText < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            div(**attributes) { raw(safe(value.to_s)) }
          end

          private

          def normalize_value(value) = value
        end
      end
    end
  end
end
