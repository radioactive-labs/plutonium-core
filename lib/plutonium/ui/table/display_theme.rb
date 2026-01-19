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
            color: "flex items-center",
            color_indicator: "w-8 h-8 rounded-md mr-2 shadow-sm border border-[var(--pu-border)]",
            email: "flex items-center gap-1 text-primary-600 dark:text-primary-400 hover:text-primary-500 whitespace-nowrap transition-colors",
            phone: "flex items-center gap-1 text-primary-600 dark:text-primary-400 hover:text-primary-500 whitespace-nowrap transition-colors",
            json: "whitespace-pre font-mono text-xs bg-[var(--pu-surface-alt)] border border-[var(--pu-border-muted)] rounded-[var(--pu-radius-sm)] p-2 overflow-x-auto",
            attachment_value_wrapper: "flex flex-wrap gap-1"
          })
        end
      end
    end
  end
end
