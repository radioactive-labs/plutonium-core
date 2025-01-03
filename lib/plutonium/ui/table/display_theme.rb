# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class DisplayTheme < Phlexi::Table::DisplayTheme
        def self.theme
          super.merge({
            value_wrapper: "max-h-[150px] overflow-y-auto",
            prefixed_icon: "w-4 h-4 mr-1",
            link: "text-primary-600 dark:text-primary-500",
            color: "flex items-center",
            color_indicator: "w-10 h-10 rounded-full mr-2",
            email: "flex items-center text-primary-600 dark:text-primary-500 whitespace-nowrap",
            phone: "flex items-center text-primary-600 dark:text-primary-500 whitespace-nowrap",
            json: " whitespace-pre font-mono shadow-inner p-4",
            attachment_value_wrapper: "flex flex-wrap gap-1"
          })
        end
      end
    end
  end
end
