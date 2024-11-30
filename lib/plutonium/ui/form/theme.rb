# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Theme < Phlexi::Form::Theme
        def self.theme
          super.merge({
            base: "relative bg-white dark:bg-gray-800 shadow-md sm:rounded-lg my-3 p-6 space-y-6",
            fields_wrapper: "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-4 grid-flow-row-dense",
            actions_wrapper: "flex justify-end space-x-2",
            wrapper: nil,
            inner_wrapper: "w-full",
            # errors
            form_errors_wrapper: "flex p-4 mb-4 text-sm text-red-800 rounded-lg bg-red-50 dark:bg-gray-800 dark:text-red-400",
            form_errors_message: "font-medium",
            form_errors_list: "mt-1.5 list-disc list-inside",
            # label themes
            label: "mt-2 block mb-2 text-base font-bold",
            invalid_label: "text-red-700 dark:text-red-500",
            valid_label: "text-green-700 dark:text-green-500",
            neutral_label: "text-gray-500 dark:text-gray-400",
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
            # button themes
            button: "px-4 py-2 bg-primary-600 text-white rounded-md hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500",
            # flatpickr
            flatpickr: :input,
            valid_flatpickr: :valid_input,
            invalid_flatpickr: :invalid_input,
            neutral_flatpickr: :neutral_input
          })
        end
      end
    end
  end
end
