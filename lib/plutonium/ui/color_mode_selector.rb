# frozen_string_literal: true

module Plutonium
  module UI
    # Component for selecting color mode (light/dark/system)
    # @example Basic usage
    #   render ColorModeSelector.new
    class ColorModeSelector < Plutonium::UI::Component::Base
      BUTTON_CLASSES = "inline-flex justify-center items-center p-2 text-[var(--pu-text-muted)] rounded-[var(--pu-radius-md)] cursor-pointer hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] transition-colors duration-200"
      ICON_SIZE = 18
      ICON_STROKE = 1.5

      def view_template
        button(
          type: "button",
          class: BUTTON_CLASSES,
          data_controller: "color-mode",
          data_action: "click->color-mode#toggleMode",
          title: "Toggle color mode"
        ) do
          render Phlex::TablerIcons::DeviceDesktop.new(size: ICON_SIZE, stroke: ICON_STROKE, class: "color-mode-icon-auto")
          render Phlex::TablerIcons::Sun.new(size: ICON_SIZE, stroke: ICON_STROKE, class: "color-mode-icon-light hidden")
          render Phlex::TablerIcons::Moon.new(size: ICON_SIZE, stroke: ICON_STROKE, class: "color-mode-icon-dark hidden")
        end
      end
    end
  end
end
