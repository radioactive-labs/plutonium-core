# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      module Components
        # A star picker: one radio per star, no JS. The radios run from `max:`
        # (default 5) down to 1 in a row-reversed flex box, so `.pu-rating`'s
        # `:checked ~ label` and `:hover ~ label` rules fill the stars up to
        # the chosen or hovered one. An optional rating ends with a "Clear"
        # radio (blank value); it comes last so no fill rule reaches it.
        class Rating < Phlexi::Form::Components::Base
          include Phlexi::Form::Components::Concerns::HandlesInput

          def view_template
            fieldset(id: attributes[:id], class: tokens("pu-rating", attributes[:class]), role: :radiogroup) do
              @max.downto(1) do |score|
                id = "#{attributes[:id]}_#{score}"
                input(type: :radio, id:, name: attributes[:name], value: score, checked: field.value.to_i == score,
                  required: attributes[:required], disabled: attributes[:disabled], class: "sr-only")
                label(for: id, title: star_label(score)) do
                  render Phlex::TablerIcons::Star.new
                  span(class: "sr-only") { star_label(score) }
                end
              end
              render_clear unless attributes[:required]
            end
          end

          protected

          def build_attributes
            super
            @max = attributes.delete(:max) || 5
          end

          private

          def render_clear
            id = "#{attributes[:id]}_clear"
            input(type: :radio, id:, name: attributes[:name], value: "", checked: field.value.blank?,
              disabled: attributes[:disabled], class: "sr-only")
            label(for: id, class: "pu-rating-clear") { Plutonium::Translation.t("plutonium.ui.form.rating.clear") }
          end

          def star_label(score) = Plutonium::Translation.t("plutonium.ui.display.rating.label", value: score, max: @max)
        end
      end
    end
  end
end
