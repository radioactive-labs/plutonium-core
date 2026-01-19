# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Theme < Phlexi::Table::Theme
        def self.theme
          super.merge({
            selection_checkbox: "size-4 rounded border-gray-300 text-primary-700 focus:ring-primary-500 focus:ring-2 dark:bg-gray-700 dark:border-gray-600 cursor-pointer",
            selection_header_cell: "w-12 px-4 py-3",
            selection_body_cell: "w-12 px-4 py-4",
            name_column: "font-medium text-gray-900 whitespace-nowrap dark:text-white",
            align_start: "text-start",
            align_end: "text-end",
            wrapper: "relative overflow-x-auto shadow-md sm:rounded-lg",
            base: "w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400",
            caption: "p-5 text-lg font-semibold text-left rtl:text-right text-gray-900 bg-white dark:text-white dark:bg-gray-800",
            description: "mt-1 text-sm font-normal text-gray-500 dark:text-gray-400",
            header: "text-xs text-gray-700 uppercase bg-gray-200 dark:bg-gray-700 dark:text-gray-400",
            header_grouping_cell: "px-6 py-3 text-center text-sm border-b border-t border-r last:border-r-0 dark:border-gray-800",
            header_cell: "px-6 py-3",
            header_cell_content_wrapper: "inline-flex items-center",
            header_cell_sort_wrapper: "flex items-center",
            header_cell_sort_indicator: "ml-1.5",
            body_row: "bg-white border-b last:border-none dark:bg-gray-800 dark:border-gray-700",
            body_cell: "px-6 py-4 whitespace-pre max-w-[450px] overflow-hidden text-ellipsis transition-all duration-300 ease-in-out",
            sort_icon: "w-3 h-3",
            sort_icon_active: "text-primary-600",
            sort_icon_inactive: "text-gray-600 dark:text-gray-500",
            sort_index_clear_link: "ml-2",
            sort_index_clear_link_text: "text-xs font-bold text-gray-600 dark:text-gray-500",
            sort_index_clear_link_icon: "ml-1 text-red-600"
          })
        end
      end
    end
  end
end
