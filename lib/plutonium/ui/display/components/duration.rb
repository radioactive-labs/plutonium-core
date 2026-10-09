# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A number of seconds (or an ActiveSupport::Duration) as "2h 15m".
        class Duration < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          UNITS = {days: 86_400, hours: 3600, minutes: 60, seconds: 1}.freeze

          def render_value(value)
            span(**attributes) { value }
          end

          private

          def normalize_value(value)
            remaining = value.to_i
            parts = UNITS.filter_map do |unit, size|
              count, remaining = remaining.divmod(size)
              Plutonium::Translation.t("plutonium.ui.display.duration.#{unit}", count:) if count.positive?
            end
            parts.empty? ? Plutonium::Translation.t("plutonium.ui.display.duration.seconds", count: 0) : parts.join(" ")
          end
        end
      end
    end
  end
end
