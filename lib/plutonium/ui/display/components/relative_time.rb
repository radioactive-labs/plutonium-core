# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A timestamp as "3 minutes ago", kept live by the timeago controller.
        # The absolute time is the fallback text and the tooltip.
        class RelativeTime < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            absolute = I18n.l(value, format: :long)
            time(**attributes, datetime: value.iso8601, title: absolute,
              data: {controller: "timeago", timeago_datetime_value: value.iso8601}) { absolute }
          end

          private

          def normalize_value(value) = value
        end
      end
    end
  end
end
