# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Theme < Phlexi::Table::Theme
        def self.theme
          super.merge({
            selection_checkbox: "w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-elevated-dark dark:border-gray-600",
            name_column: "font-medium text-gray-900 whitespace-nowrap dark:text-white",
            align_start: "text-start",
            align_end: "text-end",
            wrapper: "pu-table-wrapper relative overflow-x-auto shadow-md sm:rounded-sm",
            base: "pu-table w-full text-sm text-left rtl:text-right text-gray-500 dark:text-gray-400",
            caption: "p-md text-lg font-semibold text-left rtl:text-right text-gray-900 bg-surface dark:text-white dark:bg-surface-dark",
            description: "mt-xs text-sm font-normal text-gray-500 dark:text-gray-400",
            header: "pu-table-header text-xs text-gray-700 uppercase bg-elevated dark:bg-elevated-dark dark:text-gray-400",
            header_grouping_cell: "px-lg py-sm text-center text-sm border-b border-t border-r last:border-r-0 dark:border-gray-800",
            header_cell: "pu-table-header-cell px-lg py-sm",
            header_cell_content_wrapper: "inline-flex items-center",
            header_cell_sort_wrapper: "flex items-center",
            header_cell_sort_indicator: "ml-xs.5",
            body_row: "pu-table-row bg-surface border-b last:border-none dark:bg-surface-dark dark:border-gray-700",
            body_cell: "pu-table-cell px-lg py-md whitespace-pre max-w-[450px] overflow-hidden text-ellipsis transition-all duration-300 ease-in-out",
            sort_icon: "w-3 h-3",
            sort_icon_active: "text-primary-600",
            sort_icon_inactive: "text-gray-600 dark:text-gray-500",
            sort_index_clear_link: "ml-sm",
            sort_index_clear_link_text: "text-xs font-bold text-gray-600 dark:text-gray-500",
            sort_index_clear_link_icon: "ml-xs text-red-600"
          })
        end
      end
    end
  end
end
