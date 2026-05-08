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
            header_cell: "pu-table-header-cell group",
            header_cell_content_wrapper: "inline-flex items-center",
            header_cell_sort_wrapper: "flex items-center justify-between gap-1",
            header_cell_sort_indicator: "ml-1.5",
            header_cell_link: "flex items-center gap-1 cursor-pointer hover:text-[var(--pu-text)]",

            # Body
            body_row: "pu-table-body-row",
            body_cell: "pu-table-body-cell whitespace-pre max-w-[450px] overflow-hidden text-ellipsis",

            # Sorting
            sort_icon: "w-3 h-3",
            sort_icon_active: "ml-1 inline-flex text-primary-600 dark:text-primary-400",
            sort_icon_inactive: "ml-1 inline-flex text-[var(--pu-text-subtle)] opacity-0 group-hover:opacity-100 transition-opacity",
            sort_priority_badge: "ml-1 inline-flex items-center justify-center w-4 h-4 text-[10px] font-semibold rounded bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300",
            sort_index_clear_link: "ml-2",
            sort_index_clear_link_text: "text-xs font-bold text-[var(--pu-text-subtle)]",
            sort_index_clear_link_icon: "ml-1 text-danger-600 dark:text-danger-400",

            # Column menu
            column_menu_trigger: "p-1 rounded text-[var(--pu-text-subtle)] hover:text-[var(--pu-text)] hover:bg-[var(--pu-surface-alt)] opacity-0 group-hover:opacity-100 transition-opacity",
            column_menu_panel: "hidden absolute right-0 top-full mt-1 z-50 min-w-[180px] bg-[var(--pu-surface)] border border-[var(--pu-border)] rounded-md shadow-lg p-1",
            column_menu_item: "flex items-center gap-2 px-2 py-1.5 text-sm text-[var(--pu-text)] rounded hover:bg-[var(--pu-surface-alt)] w-full",
            column_menu_item_disabled: "flex items-center gap-2 px-2 py-1.5 text-sm text-[var(--pu-text-subtle)] opacity-60 cursor-not-allowed",
            column_menu_separator: "my-1 border-t border-[var(--pu-border)]"
          })
        end
      end
    end
  end
end
