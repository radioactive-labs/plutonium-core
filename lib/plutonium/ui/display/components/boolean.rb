# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      module Components
        # Renders a boolean as a colored "Yes" / "No" pill with a leading icon.
        class Boolean < Phlexi::Display::Components::Base
          include Phlexi::Display::Components::Concerns::DisplaysValue

          def render_value(value)
            if value
              pill(label: true_label, variant: "pu-badge-success", icon: Phlex::TablerIcons::Check)
            else
              pill(label: false_label, variant: "pu-badge-neutral", icon: Phlex::TablerIcons::X)
            end
          end

          private

          def pill(label:, variant:, icon:)
            span(**attributes, class: tokens("pu-badge", variant), "aria-label": label) do
              render icon.new(class: "w-3.5 h-3.5")
              plain label
            end
          end

          def true_label = @true_label || "Yes"

          def false_label = @false_label || "No"

          def build_attributes
            @true_label = attributes.delete(:true_label)
            @false_label = attributes.delete(:false_label)
            super
          end

          # Keep the real boolean — the default stringifies, turning `false` into
          # the truthy string "false".
          def normalize_value(value) = value
        end
      end
    end
  end
end
