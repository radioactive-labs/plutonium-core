# frozen_string_literal: true

module Plutonium
  module UI
    module Display
      class Theme < Phlexi::Display::Theme
        def self.theme
          super.merge({
            base: "",
            value_wrapper: "max-h-[300px] overflow-y-auto",
            # Merged into the fields_wrapper's Block, which supplies `pu-card`
            # itself — this is only for anything a caller wants to add on top.
            fields_wrapper: nil,
            fields_inner: "pu-card-body grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-x-8 gap-y-6 grid-flow-row-dense",

            # display_layout sectioning. `sections_wrapper` replaces
            # `fields_inner` as the card's inner padding box when a layout is
            # declared (it stacks sections instead of fields directly), and
            # each section's field grid uses `section_grid` — the same grid as
            # `fields_inner` without the padding, which the wrapper now owns.
            # Split into their own keys so overriding one path doesn't
            # silently reshape the other.
            # Sections are their OWN cards (see Component::Section), so this
            # only has to stack them — no card, no padding of its own.
            sections_wrapper: "space-y-4",
            section_grid: "grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-4 gap-x-8 gap-y-6 grid-flow-row-dense",

            # Section chrome (heading, accent, divider, collapsible caret).
            # Shared defaults with the form so both read the same; override any
            # key here to restyle show-page sections alone.
            **Plutonium::UI::Component::Section::DEFAULT_THEME,

            # Labels and descriptions
            label: "text-sm font-semibold uppercase tracking-wide text-[var(--pu-text-muted)] mb-2",
            description: "text-sm text-[var(--pu-text-subtle)]",
            placeholder: "text-lg text-[var(--pu-text-subtle)] italic",

            # Value types
            string: "text-lg text-[var(--pu-text)] whitespace-pre-line leading-relaxed",
            text: "text-lg text-[var(--pu-text)] whitespace-pre-line leading-relaxed",
            link: "text-lg text-primary-600 dark:text-primary-400 hover:text-primary-500 dark:hover:text-primary-300 whitespace-pre-line transition-colors",

            # Color display
            color: "flex items-center gap-2",
            color_indicator: "w-6 h-6 rounded border border-[var(--pu-border)]",
            color_label: "text-sm text-[var(--pu-text-muted)]",

            # Boolean / badge pills — variant class is applied by the component.
            boolean: "",
            badge: "",
            currency: "text-lg text-[var(--pu-text)] tabular-nums",

            # Contact info
            email: "flex items-center gap-2 text-lg text-primary-600 dark:text-primary-400 hover:text-primary-500 transition-colors",
            phone: "flex items-center gap-2 text-lg text-primary-600 dark:text-primary-400 hover:text-primary-500 transition-colors",

            # Structured content
            json: "text-sm text-[var(--pu-text)] whitespace-pre font-mono bg-[var(--pu-surface-alt)] border border-[var(--pu-border-muted)] rounded-[var(--pu-radius-md)] p-4 overflow-x-auto",
            prefixed_icon: "w-6 h-6 mr-2 text-[var(--pu-text-muted)]",
            markdown: "format dark:format-invert format-primary max-w-none",
            rich_text: "format dark:format-invert format-primary max-w-none",
            key_value: "grid grid-cols-[auto_1fr] gap-x-6 gap-y-2 text-[var(--pu-text)]",
            key_value_key: "font-medium text-[var(--pu-text-muted)] break-words",
            key_value_value: "break-words",
            key_value_nested: "font-mono text-sm",
            list: "flex flex-wrap gap-1.5",
            list_item: "pu-badge pu-badge-neutral",
            relative_time: "text-lg text-[var(--pu-text)]",
            code: "flex items-center gap-2",
            code_value: "font-mono text-sm text-[var(--pu-text)] bg-[var(--pu-surface-alt)] border border-[var(--pu-border-muted)] rounded-[var(--pu-radius-sm)] px-2 py-0.5 break-all",
            code_copy: "pu-btn pu-btn-xs pu-btn-ghost",
            duration: "text-lg text-[var(--pu-text)] tabular-nums",
            file_size: "text-lg text-[var(--pu-text)] tabular-nums",
            progress: "flex items-center gap-3",
            progress_track: "h-2 w-full max-w-xs rounded-full bg-[var(--pu-surface-alt)] overflow-hidden",
            progress_bar: "h-full rounded-full bg-primary-500",
            progress_label: "text-sm text-[var(--pu-text-muted)] tabular-nums",
            rating: "flex items-center gap-0.5",
            rating_filled: "w-5 h-5 text-warning-500 fill-current",
            rating_empty: "w-5 h-5 text-[var(--pu-border)]",
            binary: "text-sm text-[var(--pu-text-muted)]",

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
