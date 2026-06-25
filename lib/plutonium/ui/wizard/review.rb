# frozen_string_literal: true

module Plutonium
  module UI
    module Wizard
      # The terminal review step's body (§2.5), a small state machine (see
      # {#render_mode}):
      #
      #   - INCOMPLETE (a visible step is unvisited/invalid) → a "fix this" jump
      #     link per outstanding step + an auto-summary of what's entered so far.
      #   - COMPLETE + custom block → the author's block, rendered bare.
      #   - COMPLETE + no block, `summary: true` (default) → the auto-summary of
      #     every visible step's collected `data` (via SummaryDisplay).
      #   - COMPLETE + no block, `summary: false` → the built-in "ready to
      #     complete" panel (for a fully author-owned / chromeless review).
      #
      # The Finish button is rendered by the page (gated: disabled while any
      # visible step is incomplete); this component only renders the body.
      class Review < Plutonium::UI::Component::Base
        # @param runner  [Plutonium::Wizard::Runner]
        # @param step_url [Proc] step_key → GET url, for the fix-this links.
        def initialize(runner:, step_url:)
          @runner = runner
          @step_url = step_url
        end

        def view_template
          render_outstanding if show_outstanding?
          render_summary if show_summary?
          render_custom_block if show_custom?
          render_ready if show_ready?
        end

        private

        # The review body composes from these pieces (see the `review summary:`
        # macro). Order of render: outstanding → summary → custom → ready.
        #
        #   - outstanding banner — while any visible step is incomplete.
        #   - summary cards      — whenever the auto-summary is on: the
        #     review-and-fix view when incomplete, the check-before-finish view
        #     when complete.
        #   - custom block       — author content, ONLY once complete; sits BELOW
        #     the summary when summary is on, and REPLACES it when summary is off.
        #   - ready panel        — complete + summary off + no custom block: the
        #     built-in "ready to complete" confirmation (chromeless finish).
        def show_outstanding? = !complete?

        def show_summary? = summary?

        def show_custom? = complete? && !custom_block.nil?

        def show_ready? = complete? && !summary? && custom_block.nil?

        def complete? = @runner.incomplete_visible_steps.empty?

        def summary? = @runner.current_step.summary?

        def custom_block = @runner.current_step.block

        def steps = @runner.visible_path.reject(&:review?)

        # The step's typed `data` sub-object (`data.<step>`), the summary's source.
        def step_data(step) = @runner.wizard.data[step.key]

        def render_outstanding
          incomplete = @runner.incomplete_visible_steps
          return if incomplete.empty?

          div(class: "pu-wizard-review-outstanding rounded-lg border border-warning-300 bg-warning-50 dark:border-warning-800 dark:bg-warning-950/30 p-4 mb-6", role: "alert") do
            p(class: "text-sm font-medium text-[var(--pu-text)] mb-2") do
              "Some steps still need attention before you can finish:"
            end
            ul(class: "space-y-1") do
              incomplete.each do |step|
                li do
                  a(
                    href: @step_url.call(step.key),
                    class: "text-sm font-medium text-primary-600 dark:text-primary-400 hover:underline",
                    data: {wizard_review_fix: step.key}
                  ) { "Fix #{step.label}" }
                end
              end
            end
          end
        end

        def render_summary
          div(class: "space-y-4") do
            steps.each do |step|
              fields = summary_fields(step)
              structured = step.structured_inputs
              next if fields.empty? && structured.empty?

              render_step_card(step, fields, structured)
            end
          end
        end

        # One step rendered as a card: a titled header strip (label + Edit) over a
        # body that holds the scalar summary and any structured collections.
        def render_step_card(step, fields, structured)
          section(
            class: "pu-wizard-review-step overflow-hidden rounded-[var(--pu-radius-lg)] border border-[var(--pu-border)] bg-[var(--pu-surface)] shadow-[var(--pu-shadow-sm)]",
            data: {wizard_review_step: step.key}
          ) do
            div(class: "flex items-center justify-between gap-3 border-b border-[var(--pu-border)] bg-[var(--pu-surface-alt)] px-5 py-3") do
              h3(class: "text-sm font-semibold text-[var(--pu-text)]") { step.label.to_s }
              a(
                href: @step_url.call(step.key),
                class: "shrink-0 text-xs font-medium text-primary-600 dark:text-primary-400 hover:underline"
              ) { "Edit" }
            end
            div(class: "px-5 py-4") do
              # Decorate so attachment fields resolve to displayable attachments —
              # the SummaryDisplay then renders them through the normal attachment
              # display component, not the raw token string.
              # Also pass `step:` so ChoicesData can resolve select labels (e.g.
              # a stored member_id renders as "John Doe", not "42").
              if fields.any?
                render SummaryDisplay.new(
                  Plutonium::Wizard::AttachmentData.wrap(step_data(step), step),
                  fields:, inputs: step.inputs, step: step
                )
              end
              render_structured(step) if structured.any?
            end
          end
        end

        def summary_fields(step)
          step.attribute_schema.keys.map(&:to_sym)
        end

        # Repeatable `structured_input` collections aren't scalar `data` attributes,
        # so the SummaryDisplay can't render them — summarise each collection as a
        # labelled list of its non-empty rows (blank trailing rows are dropped).
        def render_structured(step)
          data = step_data(step)
          step.structured_inputs.each_key do |name|
            rows = Array(data.public_send(name))
              .map(&:to_h)
              .reject { |row| row.values.all?(&:blank?) }

            div(class: "pu-wizard-review-collection mt-4 first:mt-0", data: {wizard_review_collection: name}) do
              h4(class: "mb-2 text-xs font-semibold uppercase tracking-wide text-[var(--pu-text-muted)]") do
                name.to_s.humanize
              end
              if rows.empty?
                p(class: "text-sm text-[var(--pu-text-subtle)]") { "None" }
              else
                ul(class: "space-y-1.5") do
                  rows.each do |row|
                    li(class: "flex flex-wrap items-center gap-x-2 gap-y-0.5 rounded-[var(--pu-radius-md)] bg-[var(--pu-surface-alt)] px-3 py-2 text-sm text-[var(--pu-text)]") do
                      row.each do |key, value|
                        span do
                          span(class: "text-[var(--pu-text-muted)]") { "#{key.to_s.humanize}: " }
                          plain value.to_s
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        # The review step's custom block, rendered BARE — just a spacing + targeting
        # wrapper, no surface/border/typography of its own — so the author has full
        # control over the body's look.
        def render_custom_block
          div(class: "pu-wizard-review-custom", data: {wizard_review_custom: true}) do
            instance_exec(@runner.wizard, &custom_block)
          end
        end

        # The built-in "ready to complete" panel: shown when everything is valid,
        # there's no custom block, and the auto-summary is turned off (`summary:
        # false`). A clean confirmation so a chromeless review still reads as done.
        def render_ready
          div(
            class: "pu-wizard-review-ready flex flex-col items-center text-center py-6",
            data: {wizard_review_ready: true}
          ) do
            div(class: "mb-4 flex h-14 w-14 items-center justify-center rounded-full bg-success-100 text-success-600 dark:bg-success-900/30 dark:text-success-400") do
              render Phlex::TablerIcons::Check.new(class: "h-7 w-7")
            end
            h3(class: "text-lg font-semibold tracking-tight text-[var(--pu-text)]") { "You're all set" }
            p(class: "mt-1.5 max-w-prose text-sm text-[var(--pu-text-muted)]") do
              "Everything looks good. Click Finish to complete."
            end
          end
        end
      end
    end
  end
end
