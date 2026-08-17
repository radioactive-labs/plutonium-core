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
            color: "flex items-center text-lg text-[var(--pu-text)] whitespace-pre-line",
            color_indicator: "w-10 h-10 rounded-lg mr-3 shadow-sm border border-[var(--pu-border)]",

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
