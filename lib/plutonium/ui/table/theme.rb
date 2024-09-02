# frozen_string_literal: true

require "phlexi-form"

module Plutonium
  module UI
    module Table
      class Theme < Phlexi::Table::Theme
        THEME = {
          selection_checkbox: "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600",
          name_column: "font-medium text-gray-900 whitespace-nowrap dark:text-white",
          align_end: "text-end",
          wrapper: "relative overflow-x-auto shadow-md sm:rounded-lg",
          base: "w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400",
          caption: "p-5 text-lg font-semibold text-left rtl:text-right text-gray-900 bg-white dark:text-white dark:bg-gray-800",
          description: "mt-1 text-sm font-normal text-gray-500 dark:text-gray-400",
          header: "text-xs text-gray-700 uppercase bg-gray-50 dark:bg-gray-700 dark:text-gray-400",
          header_grouping_cell: "px-6 py-3 text-center text-sm border-b border-t border-r last:border-r-0 dark:border-gray-800",
          header_cell: "px-6 py-3",
          body_row: "bg-white border-b dark:bg-gray-800 dark:border-gray-700",
          body_cell: "px-6 py-4",
          actions_row_cell: "flex items-center space-x-2",
          sort_icon: "w-3 h-3",
          sort_icon_active: "text-primary-600",
          sort_index_clear_link: "ml-2",
          sort_index_clear_link_text: "text-xs font-bold",
          sort_index_clear_link_icon: "ml-1 text-red-600"
        }.freeze
      end
    end
  end
end
