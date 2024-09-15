# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Theme < Phlexi::Form::Theme
        def self.theme
          super.merge({
            base: "flex flex-col space-y-6 px-4 py-2",
            actions_wrapper: "flex justify-end space-x-2",
            # label themes
            label: "md:w-1/6 mt-2 block mb-2 text-sm font-medium",
            invalid_label: "text-red-700 dark:text-red-500",
            valid_label: "text-green-700 dark:text-green-500",
            neutral_label: "text-gray-700 dark:text-white",
            # input themes
            input: "w-full p-2 border rounded-md shadow-sm font-medium text-sm dark:bg-gray-700",
            invalid_input: "bg-red-50 border-red-500 dark:border-red-500 text-red-900 dark:text-red-500 placeholder-red-700 dark:placeholder-red-500 focus:ring-red-500 focus:border-red-500",
            valid_input: "bg-green-50 border-green-500 dark:border-green-500 text-green-900 dark:text-green-400 placeholder-green-700 dark:placeholder-green-500 focus:ring-green-500 focus:border-green-500",
            neutral_input: "border-gray-300 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white focus:ring-primary-500 focus:border-primary-500",
            # color
            color: "pu-color-input appearance-none bg-transparent border-none cursor-pointer w-10 h-10",
            invalid_color: nil,
            valid_color: nil,
            neutral_color: nil,
            # file
            file: "w-full border rounded-md shadow-sm font-medium text-sm dark:bg-gray-700 focus:outline-none",
            # hint themes
            hint: "mt-2 text-sm text-gray-500 dark:text-gray-200",
            # error themes
            error: "mt-2 text-sm text-red-600 dark:text-red-500",
            # wrapper themes
            wrapper: "flex flex-col md:flex-row items-start space-y-2 md:space-y-0 md:space-x-2 mb-4",
            inner_wrapper: "md:w-5/6 w-full",
            # button themes
            button: "px-4 py-2 bg-primary-600 text-white rounded-md hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500"
          })
        end
      end
    end
  end
end
