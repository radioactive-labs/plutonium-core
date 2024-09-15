# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Theme < Phlexi::Display::Theme
        def self.theme
          super.merge({
            base: "relative bg-white dark:bg-gray-800 shadow-md sm:rounded-lg my-3",
            fields_wrapper: "p-6 grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-6 gap-y-10 grid-flow-row-dense",
            label: "text-base font-bold text-gray-500 dark:text-gray-400 mb-1",
            description: "text-sm text-gray-400 dark:text-gray-500",
            placeholder: "text-lg text-gray-500 dark:text-gray-300 mb-1 italic",
            string: "max-h-[300px] overflow-y-auto text-lg text-gray-900 dark:text-white mb-1 whitespace-pre-line",
            text: "max-h-[300px] overflow-y-auto text-lg text-gray-900 dark:text-white mb-1 whitespace-pre-line",
            link: "text-primary-600 dark:text-primary-500 whitespace-pre-line",
            color: "flex items-center text-lg text-gray-900 dark:text-white mb-1 whitespace-pre-line",
            color_indicator: "w-10 h-10 rounded-full mr-2",
            email: "flex items-center text-lg text-primary-600 dark:text-primary-500 mb-1 whitespace-pre-line",
            json: "max-h-[300px] overflow-y-auto text-md hover:font-serif font-mono text-gray-900 dark:text-white mb-1 shadow-inner p-2",
            prefixed_icon: "w-8 h-8 mr-2"
          })
        end
      end
    end
  end
end
