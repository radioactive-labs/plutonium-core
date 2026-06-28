# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      # The "already completed" page for a one-time wizard (§9). Shown when a user
      # re-opens a one-time wizard they've already finished: the completion marker
      # is retained but its `data` is cleared, so there is nothing to review — just
      # a confirmation that the flow is done.
      #
      # Authors can override the body entirely with a `completed do |wizard| … end`
      # block on the wizard class (rendered in this component's Phlex context, with
      # the wizard yielded); otherwise the built-in confirmation renders.
      class WizardCompleted < Plutonium::UI::Page::Base
        # @param runner   [Plutonium::Wizard::Runner]
        # @param exit_url [String] where the default "Continue" button points.
        def initialize(runner:, exit_url:)
          @runner = runner
          @wizard = runner.wizard
          @exit_url = exit_url
          super(page_title: @wizard.class.label, page_description: nil)
        end

        def view_template
          DynaFrameContent() do
            article(class: "pu-wizard pu-wizard-completed mx-auto max-w-2xl") do
              div(class: card_classes) do
                div(class: "px-6 py-10 text-center sm:px-10") do
                  block = @wizard.class.completed_block
                  if block
                    instance_exec(@wizard, &block)
                  else
                    render_default
                  end
                end
              end
            end
          end
        end

        private

        def card_classes
          "pu-wizard-card overflow-hidden rounded-[var(--pu-radius-xl)] " \
            "border border-[var(--pu-border)] bg-[var(--pu-surface)] shadow-[var(--pu-shadow-lg)]"
        end

        # The built-in confirmation body: a success badge, the wizard title, a short
        # message, and a Continue button out.
        def render_default
          render_check_badge
          h1(class: "mt-5 text-2xl font-bold tracking-tight text-[var(--pu-text)]") do
            @wizard.class.label
          end
          p(class: "mx-auto mt-2 max-w-prose text-[var(--pu-text-muted)]") do
            "You've already completed this — there's nothing more to do here."
          end
          div(class: "mt-7") do
            # Exits the wizard to a different page; opt out of Turbo morph (which
            # would otherwise nest the destination into this page — see Page::Wizard).
            a(href: @exit_url, class: "pu-btn pu-btn-md pu-btn-primary", data: {wizard_completed: "exit", turbo: "false"}) { "Continue" }
          end
        end

        # A success-tinted circular checkmark badge.
        def render_check_badge
          div(class: "mx-auto grid h-16 w-16 place-items-center rounded-full bg-success-100 text-success-600 dark:bg-success-900/30 dark:text-success-400") do
            svg(
              class: "h-8 w-8",
              xmlns: "http://www.w3.org/2000/svg",
              fill: "none",
              viewbox: "0 0 24 24",
              stroke: "currentColor",
              stroke_width: "2.5",
              aria_hidden: "true"
            ) do |s|
              s.path(stroke_linecap: "round", stroke_linejoin: "round", d: "M4.5 12.75l6 6 9-13.5")
            end
          end
        end

        def page_type = :wizard_completed_page
      end
    end
  end
end
