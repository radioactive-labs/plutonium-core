# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A value out of `max:` (default 100) as a bar and a percentage.
        #
        #   display :completion, as: :progress           # 0..100
        #   display :ratio, as: :progress, max: 1        # 0..1
        class Progress < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            percent = (value.to_f / @max * 100).clamp(0, 100).round
            div(**attributes, role: :progressbar, aria_valuenow: value, aria_valuemin: 0, aria_valuemax: @max) do
              div(class: themed(:progress_track)) do
                div(class: themed(:progress_bar), style: "width: #{percent}%")
              end
              span(class: themed(:progress_label)) { "#{percent}%" }
            end
          end

          private

          def build_attributes
            super
            @max = attributes.delete(:max) || 100
          end

          def normalize_value(value) = value
        end
      end
    end
  end
end
