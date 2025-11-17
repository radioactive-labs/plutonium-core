# frozen_string_literal: true

module Plutonium
  module UI
    module Form
      class Theme < Phlexi::Form::Theme
        def self.theme
          super.merge({
            base: "pu-form relative bg-surface dark:bg-surface-dark shadow-md sm:rounded-sm my-sm p-lg space-y-lg",
            fields_wrapper: "pu-form-fields grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-md grid-flow-row-dense",
            actions_wrapper: "pu-form-actions flex justify-end space-x-sm",
            wrapper: "pu-form-field",
            inner_wrapper: "pu-form-field-inner w-full",
            # errors
            form_errors_wrapper: "pu-form-errors flex p-md mb-md text-sm text-red-800 rounded-sm bg-red-50 dark:bg-surface-dark dark:text-red-400",
            form_errors_message: "pu-form-errors-message font-medium",
            form_errors_list: "pu-form-errors-list mt-xs.5 list-disc list-inside",
            # label themes
            label: "pu-form-label mt-sm block mb-sm text-base font-bold",
            invalid_label: "text-red-700 dark:text-red-500",
            valid_label: "text-green-700 dark:text-green-500",
            neutral_label: "text-gray-500 dark:text-gray-400",
            # input themes
            input: "pu-form-input w-full p-sm border rounded shadow-sm font-medium text-sm dark:bg-elevated-dark focus:ring-2",
            invalid_input: "bg-red-50 border-red-500 dark:border-red-500 text-red-900 dark:text-red-500 placeholder-red-700 dark:placeholder-red-500 focus:ring-red-500 focus:border-red-500",
            valid_input: "bg-green-50 border-green-500 dark:border-green-500 text-green-900 dark:text-green-400 placeholder-green-700 dark:placeholder-green-500 focus:ring-green-500 focus:border-green-500",
            neutral_input: "border-gray-300 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white focus:ring-primary-500 focus:border-primary-500",
            # checkbox
            checkbox: "pu-form-checkbox p-sm border rounded shadow-sm font-medium text-sm dark:bg-elevated-dark",
            # radio buttons
            radio_button: "pu-form-radio p-sm border shadow-sm font-medium text-sm dark:bg-elevated-dark",
            # color
            color: "pu-color-input appearance-none bg-transparent border-none cursor-pointer w-10 h-10",
            invalid_color: nil,
            valid_color: nil,
            neutral_color: nil,
            # file
            # file: "w-full border rounded shadow-sm font-medium text-sm dark:bg-elevated-dark focus:outline-none",
            file: "pu-form-file w-full border rounded shadow-sm font-medium text-sm dark:bg-elevated-dark border-gray-300 dark:border-gray-600 dark:placeholder-gray-400 dark:text-white focus:ring-primary-500 focus:border-primary-500 focus:outline-none focus:ring-2 [&::file-selector-button]:mr-sm [&::file-selector-button]:px-md [&::file-selector-button]:py-sm [&::file-selector-button]:bg-page [&::file-selector-button]:border-0 [&::file-selector-button]:rounded-l-md [&::file-selector-button]:text-sm [&::file-selector-button]:font-medium [&::file-selector-button]:text-gray-700 [&::file-selector-button]:hover:bg-interactive [&::file-selector-button]:cursor-pointer dark:[&::file-selector-button]:bg-gray-600 dark:[&::file-selector-button]:text-gray-200 dark:[&::file-selector-button]:hover:bg-gray-500",
            # hint themes
            hint: "pu-form-hint mt-sm text-sm text-gray-500 dark:text-gray-200 whitespace-pre",
            # error themes
            error: "pu-form-error mt-sm text-sm text-red-600 dark:text-red-500",
            # button themes
            button: "pu-form-button px-md py-sm bg-primary-600 text-white rounded hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-primary-500",
            # flatpickr
            flatpickr: :input,
            valid_flatpickr: :valid_input,
            invalid_flatpickr: :invalid_input,
            neutral_flatpickr: :neutral_input,
            # int_tel_input
            int_tel_input: :input,
            valid_int_tel_input: :valid_input,
            invalid_int_tel_input: :invalid_input,
            neutral_int_tel_input: :neutral_input,
            uppy: :file,
            valid_uppy: :valid_file,
            invalid_uppy: :invalid_file,
            neutral_uppy: :neutral_file,

            association: :select,
            valid_association: :valid_select,
            invalid_association: :invalid_select,
            neutral_association: :neutral_select,

            polymorpic_association: :association,
            valid_polymorpic_association: :valid_association,
            invalid_polymorpic_association: :invalid_association,
            neutral_polymorpic_association: :neutral_association

          })
        end
      end
    end
  end
end
