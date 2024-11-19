# frozen_string_literal: true

module Plutonium
  module UI
    # Component for selecting color mode (light/dark/system)
    # @example Basic usage
    #   render ColorModeSelector.new
    class ColorModeSelector < Plutonium::UI::Component::Base
      # Common CSS classes used across the component
      COMMON_CLASSES = {
        button: "w-full block py-2 px-4 text-sm text-gray-700 hover:bg-gray-100 dark:hover:text-white dark:text-gray-300 dark:hover:bg-gray-600",
        icon: "w-6 h-6 text-gray-800 dark:text-white",
        trigger: "inline-flex justify-center p-2 text-gray-500 rounded cursor-pointer dark:hover:text-white dark:text-gray-200 hover:text-gray-900 hover:bg-gray-100 dark:hover:bg-gray-600",
        dropdown: "hidden z-50 my-4 text-base list-none bg-white rounded divide-y divide-gray-100 shadow dark:bg-gray-700"
      }.freeze

      # Available color modes with their associated icons and actions
      COLOR_MODES = [
        {label: "Light", icon: Phlex::TablerIcons::Sun, action: "setLightColorMode"},
        {label: "Dark", icon: Phlex::TablerIcons::Moon, action: "setDarkColorMode"},
        {label: "System", icon: Phlex::TablerIcons::DeviceDesktop, action: "setSystemColorMode"}
      ].freeze

      # Renders the color mode selector
      # @return [void]
      def view_template
        div(data_controller: "resource-drop-down") do
          render_dropdown_trigger
          render_dropdown_menu
        end
      end

      private

      # @private
      def render_dropdown_trigger
        button(
          type: "button",
          data_resource_drop_down_target: "trigger",
          class: COMMON_CLASSES[:trigger]
        ) do
          render Phlex::TablerIcons::Adjustments.new(class: COMMON_CLASSES[:icon])
        end
      end

      # @private
      def render_dropdown_menu
        div(
          class: COMMON_CLASSES[:dropdown],
          data_resource_drop_down_target: "menu"
        ) do
          render_color_mode_options
        end
      end

      # @private
      def render_color_mode_options
        ul(class: "py-1", role: "none") do
          COLOR_MODES.each do |mode|
            render_color_mode_button(**mode)
          end
        end
      end

      # @private
      # @param label [String] The text label for the button
      # @param icon [Class] The TablerIcon class to render
      # @param action [String] The color-mode controller action to trigger
      def render_color_mode_button(label:, icon:, action:)
        li do
          button(
            type: "button",
            class: COMMON_CLASSES[:button],
            role: "menuitem",
            data_action: "click->color-mode##{action}"
          ) do
            div(class: "flex justify-start") do
              render icon.new(class: COMMON_CLASSES[:icon])
              plain " #{label}"
            end
          end
        end
      end
    end
  end
end
