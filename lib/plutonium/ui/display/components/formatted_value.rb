# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # Renders a value transformed by a user-supplied `formatter:` proc, themed
        # like a plain string. `formatter:` is a general column/display option, but
        # only the string component ever consumed it — handed to a typed component
        # (boolean pill, currency, badge…) the Proc leaked into the element's HTML
        # attributes and Phlex rejected it. The resource/table render layers route
        # every formatter-bearing field here instead.
        #
        # Unlike Phlexi's String component — which stringifies the value *before*
        # the formatter runs (so a boolean `false` would arrive as the truthy
        # string "false") — this keeps the raw value, matching the documented
        # contract that a formatter "receives just the value".
        class FormattedValue < Phlexi::Display::Components::String
          # Keep the raw value so the formatter sees a real boolean / number /
          # object rather than its `to_s`.
          def normalize_value(value) = value
        end
      end
    end
  end
end
