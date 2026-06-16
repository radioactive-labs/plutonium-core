# frozen_string_literal: true

module Plutonium
  module UI
    module Wizard
      # The terminal review step's body (§2.5). It renders:
      #
      #   - an auto-summary of every visible non-review step's collected `data`,
      #     grouped by step, through the display pipeline (SummaryDisplay);
      #   - a "fix this" jump link for each visible step that is unvisited or
      #     invalid (so the user can complete it);
      #   - the review step's optional custom block, if present;
      #   - the Finish button is rendered by the page; this component only signals
      #     (via `complete?`) whether the page should enable it.
      #
      # Finish is gated: rendered disabled while any visible step is incomplete.
      class Review < Plutonium::UI::Component::Base
        # @param runner  [Plutonium::Wizard::Runner]
        # @param step_url [Proc] step_key → GET url, for the fix-this links.
        def initialize(runner:, step_url:)
          @runner = runner
          @step_url = step_url
        end

        def view_template
          render_outstanding
          render_summary
          render_custom_block
        end

        private

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
              render SummaryDisplay.new(step_data(step), fields:, inputs: step.inputs) if fields.any?
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

        # The review step's optional custom block, rendered as a tinted callout so
        # author text inherits a theme-aware colour (legible in dark mode).
        def render_custom_block
          block = @runner.current_step.block
          return unless block

          div(class: "pu-wizard-review-custom mt-5 rounded-[var(--pu-radius-lg)] border border-primary-200 bg-primary-50 px-5 py-4 text-sm text-[var(--pu-text)] dark:border-primary-900/60 dark:bg-primary-900/20") do
            instance_exec(@runner.wizard, &block)
          end
        end
      end
    end
  end
end
