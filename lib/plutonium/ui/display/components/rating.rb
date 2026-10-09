# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # A score as stars out of `max:` (default 5).
        class Rating < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            filled = value.to_f.round.clamp(0, @max)
            label = Plutonium::Translation.t("plutonium.ui.display.rating.label", value: filled, max: @max)
            div(**attributes, role: :img, aria_label: label) do
              @max.times do |index|
                state = (index < filled) ? "filled" : "empty"
                span(data: {rating_star: state}) do
                  render Phlex::TablerIcons::Star.new(class: themed(:"rating_#{state}"))
                end
              end
            end
          end

          private

          def build_attributes
            super
            @max = attributes.delete(:max) || 5
          end

          def normalize_value(value) = value
        end
      end
    end
  end
end
