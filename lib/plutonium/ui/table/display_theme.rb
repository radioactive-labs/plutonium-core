# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      class DisplayTheme < Phlexi::Table::DisplayTheme
        def self.theme
          super.merge({
            value_wrapper: "max-h-[150px] overflow-y-auto",
            prefixed_icon: "w-4 h-4 mr-1 text-[var(--pu-text-muted)]",
            link: "text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 transition-colors",
            color: "flex items-center gap-2",
            color_indicator: "w-6 h-6 rounded border border-[var(--pu-border)]",
            color_label: "text-sm text-[var(--pu-text-muted)]",
            email: "flex items-center gap-1 text-primary-600 dark:text-primary-400 hover:text-primary-500 whitespace-nowrap transition-colors",
            phone: "flex items-center gap-1 text-primary-600 dark:text-primary-400 hover:text-primary-500 whitespace-nowrap transition-colors",
            markdown: "format format-sm dark:format-invert format-primary max-w-none",
            rich_text: "format format-sm dark:format-invert format-primary max-w-none",
            currency: "tabular-nums",
            # Boolean / badge pills: the component applies the variant class.
            boolean: "",
            badge: "",
            key_value: "grid grid-cols-[auto_1fr] w-max gap-x-3 gap-y-0.5 text-sm",
            key_value_key: "font-medium text-[var(--pu-text-muted)] break-words",
            key_value_value: "break-words",
            key_value_nested: "font-mono text-xs",
            list: "flex flex-wrap gap-1",
            list_item: "pu-badge pu-badge-neutral",
            relative_time: "text-sm text-[var(--pu-text)]",
            code: "flex items-center gap-2",
            code_value: "font-mono text-sm text-[var(--pu-text)] bg-[var(--pu-surface-alt)] border border-[var(--pu-border-muted)] rounded-[var(--pu-radius-sm)] px-2 py-0.5 break-all",
            code_copy: "pu-btn pu-btn-xs pu-btn-ghost",
            duration: "text-sm text-[var(--pu-text)] tabular-nums",
            file_size: "text-sm text-[var(--pu-text)] tabular-nums",
            progress: "flex items-center gap-2",
            progress_track: "h-2 w-full max-w-xs rounded-full bg-[var(--pu-surface-alt)] overflow-hidden",
            progress_bar: "h-full rounded-full bg-primary-500",
            progress_label: "text-sm text-[var(--pu-text-muted)] tabular-nums",
            rating: "flex items-center gap-0.5",
            rating_filled: "w-4 h-4 text-warning-500 fill-current",
            rating_empty: "w-4 h-4 text-[var(--pu-border)]",
            binary: "text-sm text-[var(--pu-text-muted)]",
            phlexi_render: :string,
            json: "whitespace-pre font-mono text-xs bg-[var(--pu-surface-alt)] border border-[var(--pu-border-muted)] rounded-[var(--pu-radius-sm)] p-2 overflow-x-auto",
            attachment_value_wrapper: "flex flex-wrap gap-1"
          })
        end
      end
    end
  end
end
