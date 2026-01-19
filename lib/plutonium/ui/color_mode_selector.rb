# frozen_string_literal: true

module Plutonium
  module UI
    # Component for selecting color mode (light/dark/system)
    # @example Basic usage
    #   render ColorModeSelector.new
    class ColorModeSelector < Plutonium::UI::Component::Base
      # Common CSS classes used across the component
      COMMON_CLASSES = {
        button: "inline-flex justify-center items-center p-2 text-[var(--pu-text-muted)] rounded-[var(--pu-radius-md)] cursor-pointer hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] transition-colors duration-200",
        icon: "w-5 h-5"
      }.freeze

      # Available color modes with their associated icons and actions
      COLOR_MODES = [
        {mode: "light", icon: Phlex::TablerIcons::Sun, action: "setLightColorMode"},
        {mode: "dark", icon: Phlex::TablerIcons::Moon, action: "setDarkColorMode"}
      ].freeze

      # Renders the color mode selector
      # @return [void]
      def view_template
        button(
          type: "button",
          class: COMMON_CLASSES[:button],
          data_controller: "color-mode",
          data_action: "click->color-mode#toggleMode",
          data_color_mode_current_value: "light", # Default to light mode
          title: "Toggle color mode"
        ) do
          # Both icons rendered, only one visible at a time
          render Phlex::TablerIcons::Sun.new(class: "#{COMMON_CLASSES[:icon]} color-mode-icon-light", data: {color_mode_icon: "light"})
          render Phlex::TablerIcons::Moon.new(class: "#{COMMON_CLASSES[:icon]} color-mode-icon-dark", data: {color_mode_icon: "dark"})
        end
      end
    end
  end
end
