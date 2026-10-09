# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A byte count as "12 KB".
        class FileSize < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            span(**attributes) { value }
          end

          private

          def normalize_value(value) = ActiveSupport::NumberHelper.number_to_human_size(value)
        end
      end
    end
  end
end
