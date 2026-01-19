# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Theme < Phlexi::Display::Theme
        def self.theme
          super.merge({
            base: "",
            value_wrapper: "max-h-[300px] overflow-y-auto",
            fields_wrapper: "p-8 grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-x-8 gap-y-8 grid-flow-row-dense",

            # Labels and descriptions
            label: "text-sm font-semibold uppercase tracking-wide text-[var(--pu-text-muted)] mb-2",
            description: "text-sm text-[var(--pu-text-subtle)]",
            placeholder: "text-lg text-[var(--pu-text-subtle)] italic",

            # Value types
            string: "text-lg text-[var(--pu-text)] whitespace-pre-line leading-relaxed",
            text: "text-lg text-[var(--pu-text)] whitespace-pre-line leading-relaxed",
            link: "text-lg text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 whitespace-pre-line transition-colors",

            # Color display
            color: "flex items-center text-lg text-[var(--pu-text)] whitespace-pre-line",
            color_indicator: "w-10 h-10 rounded-lg mr-3 shadow-sm border border-[var(--pu-border)]",

            # Contact info
            email: "flex items-center gap-2 text-lg text-primary-600 dark:text-primary-400 hover:text-primary-500 transition-colors",
            phone: "flex items-center gap-2 text-lg text-primary-600 dark:text-primary-400 hover:text-primary-500 transition-colors",

            # Structured content
            json: "text-sm text-[var(--pu-text)] whitespace-pre font-mono bg-[var(--pu-surface-alt)] border border-[var(--pu-border-muted)] rounded-[var(--pu-radius-md)] p-4 overflow-x-auto",
            prefixed_icon: "w-6 h-6 mr-2 text-[var(--pu-text-muted)]",
            markdown: "format dark:format-invert format-primary max-w-none",

            # Attachments
            attachment_value_wrapper: "grid grid-cols-[repeat(auto-fill,minmax(0,200px))] gap-4",

            # Render delegation
            phlexi_render: :string
          })
        end
      end
    end
  end
end
