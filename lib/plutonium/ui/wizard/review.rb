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

        def render_outstanding
          incomplete = @runner.incomplete_visible_steps
          return if incomplete.empty?

          div(class: "pu-wizard-review-outstanding rounded-lg border border-[var(--pu-warning)] bg-[var(--pu-warning)]/10 p-4 mb-6", role: "alert") do
            p(class: "text-sm font-medium text-[var(--pu-text)] mb-2") do
              "Some steps still need attention before you can finish:"
            end
            ul(class: "space-y-1") do
              incomplete.each do |step|
                li do
                  a(
                    href: @step_url.call(step.key),
                    class: "text-sm font-medium text-[var(--pu-primary)] hover:underline",
                    data: {wizard_review_fix: step.key}
                  ) { "Fix #{step.label}" }
                end
              end
            end
          end
        end

        def render_summary
          steps.each do |step|
            fields = summary_fields(step)
            next if fields.empty?

            section(class: "pu-wizard-review-step mb-6", data: {wizard_review_step: step.key}) do
              div(class: "flex items-center justify-between mb-2") do
                h3(class: "text-base font-semibold text-[var(--pu-text)]") { step.label.to_s }
                a(
                  href: @step_url.call(step.key),
                  class: "text-xs font-medium text-[var(--pu-primary)] hover:underline"
                ) { "Edit" }
              end
              render SummaryDisplay.new(@runner.wizard.data, fields:, inputs: step.inputs)
            end
          end
        end

        def summary_fields(step)
          step.attribute_schema.keys.map(&:to_sym)
        end

        def render_custom_block
          block = @runner.current_step.block
          return unless block

          div(class: "pu-wizard-review-custom mt-6") do
            instance_exec(@runner.wizard, &block)
          end
        end
      end
    end
  end
end
