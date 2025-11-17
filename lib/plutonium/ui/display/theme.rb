# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Theme < Phlexi::Display::Theme
        def self.theme
          super.merge({
            base: "pu-display",
            value_wrapper: "max-h-[300px] overflow-y-auto",
            fields_wrapper: "pu-display-fields p-lg grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-lg gap-y-2xl grid-flow-row-dense",
            label: "pu-display-label text-base font-bold text-gray-500 dark:text-gray-400 mb-xs",
            description: "pu-display-description text-sm text-gray-400 dark:text-gray-500",
            placeholder: "pu-display-placeholder text-md text-gray-500 dark:text-gray-300 mb-xs italic",
            string: "pu-display-string text-md text-gray-900 dark:text-white mb-xs whitespace-pre-line",
            text: "pu-display-text text-md text-gray-900 dark:text-white mb-xs whitespace-pre-line",
            link: "pu-display-link text-primary-600 dark:text-primary-500 whitespace-pre-line",
            color: "pu-display-color flex items-center text-md text-gray-900 dark:text-white mb-xs whitespace-pre-line",
            color_indicator: "pu-display-color-indicator w-10 h-10 rounded-full mr-sm", # max-h-fit
            email: "pu-display-email flex items-center text-md text-primary-600 dark:text-primary-500 mb-xs whitespace-pre-line",
            phone: "pu-display-phone flex items-center text-md text-primary-600 dark:text-primary-500 mb-xs whitespace-pre-line",
            json: "pu-display-json text-sm text-gray-900 dark:text-white mb-xs whitespace-pre font-mono shadow-inner p-md",
            prefixed_icon: "pu-display-icon w-8 h-8 mr-sm",
            markdown: "pu-display-markdown format dark:format-invert format-primary",
            attachment_value_wrapper: "pu-display-attachments grid grid-cols-[repeat(auto-fill,minmax(0,180px))]",
            phlexi_render: :string
          })
        end
      end
    end
  end
end
