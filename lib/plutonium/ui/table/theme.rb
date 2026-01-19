# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class Theme < Phlexi::Table::Theme
        def self.theme
          super.merge({
            # Selection
            selection_checkbox: "pu-checkbox",
            selection_header_cell: "pu-selection-cell",
            selection_body_cell: "pu-selection-cell py-4",

            # Column formatting
            name_column: "font-medium text-[var(--pu-text)] whitespace-nowrap",
            align_start: "text-start",
            align_end: "text-end",

            # Table structure
            wrapper: "pu-table-wrapper overflow-x-auto",
            base: "pu-table rtl:text-right",
            caption: "pu-panel-header text-lg font-semibold text-left rtl:text-right",
            description: "mt-1 text-sm font-normal text-[var(--pu-text-muted)]",

            # Header
            header: "pu-table-header",
            header_grouping_cell: "pu-table-header-cell text-center text-sm border-b border-t border-r last:border-r-0 border-[var(--pu-table-border)]",
            header_cell: "pu-table-header-cell",
            header_cell_content_wrapper: "inline-flex items-center",
            header_cell_sort_wrapper: "flex items-center",
            header_cell_sort_indicator: "ml-1.5",

            # Body
            body_row: "pu-table-body-row",
            body_cell: "pu-table-body-cell whitespace-pre max-w-[450px] overflow-hidden text-ellipsis",

            # Sorting
            sort_icon: "w-3 h-3",
            sort_icon_active: "text-primary-600 dark:text-primary-400",
            sort_icon_inactive: "text-[var(--pu-text-subtle)]",
            sort_index_clear_link: "ml-2",
            sort_index_clear_link_text: "text-xs font-bold text-[var(--pu-text-subtle)]",
            sort_index_clear_link_icon: "ml-1 text-danger-600 dark:text-danger-400"
          })
        end
      end
    end
  end
end
