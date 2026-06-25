# frozen_string_literal: true

module Plutonium
  module UI
    module Page
      # The "resume or start new" chooser (§4.5), shown at the bare launch URL when
      # a tokened wizard opts in with `on_relaunch :prompt` and the user already has
      # pending (in-progress) runs. Lists each pending run with a Resume link and
      # offers a Start-new button. Keyed/one-time/anchored wizards never reach here
      # (they auto-resume their single keyed run); only tokened wizards can have
      # several concurrent runs to choose between.
      class WizardChooser < Plutonium::UI::Page::Base
        # @param wizard_class  [Class] the wizard being launched.
        # @param entries       [Array<Plutonium::Wizard::Resume::Entry>] pending runs.
        # @param start_new_url [String] bare launch URL that forces a fresh run.
        def initialize(wizard_class:, entries:, start_new_url:)
          @wizard_class = wizard_class
          @entries = entries
          @start_new_url = start_new_url
          super(page_title: wizard_class.label, page_description: nil)
        end

        def view_template
          DynaFrameContent() do
            article(class: "pu-wizard pu-wizard-chooser mx-auto max-w-2xl", data: {wizard_chooser: true}) do
              render_header
              div(class: card_classes) do
                render_pending_list
                render_start_new
              end
            end
          end
        end

        private

        def render_header
          div(class: "pu-wizard-header mb-7 text-center") do
            h1(class: "text-2xl font-bold tracking-tight text-[var(--pu-text)]") { @wizard_class.label }
            p(class: "mx-auto mt-1.5 max-w-prose text-[var(--pu-text-muted)]") do
              "Pick up where you left off, or start a new one."
            end
          end
        end

        def card_classes
          "pu-wizard-card overflow-hidden rounded-[var(--pu-radius-xl)] " \
            "border border-[var(--pu-border)] bg-[var(--pu-surface)] shadow-[var(--pu-shadow-lg)]"
        end

        # The pending runs, capped in height and scrollable so a user with many
        # drafts doesn't get an unbounded card (the Start-new footer below it stays
        # in view).
        def render_pending_list
          ul(class: "max-h-96 overflow-y-auto divide-y divide-[var(--pu-border)]") do
            @entries.each { |entry| render_entry(entry) }
          end
        end

        # One pending run: its current step + when it was last touched, and a Resume
        # link. A run whose mount can't be resolved (no `resume_url`) is shown as a
        # disabled row rather than a dead link.
        def render_entry(entry)
          li(class: "flex items-center justify-between gap-4 px-5 py-4", data: {wizard_chooser_entry: entry.current_step}) do
            div(class: "min-w-0") do
              p(class: "truncate text-sm font-semibold text-[var(--pu-text)]") do
                entry.current_step_label.presence || "In progress"
              end
              p(class: "mt-0.5 text-xs text-[var(--pu-text-muted)]") { "Updated #{updated_ago(entry)} ago" }
            end
            div(class: "flex items-center gap-2 shrink-0") do
              if entry.resume_url.present?
                a(href: entry.resume_url, class: "pu-btn pu-btn-sm pu-btn-outline", data: {wizard_chooser_resume: true}) { "Resume" }
              else
                span(class: "pu-btn pu-btn-sm pu-btn-outline opacity-50 cursor-not-allowed") { "Resume" }
              end
 
              # Discard form
              discard_url = entry.resume_url ? entry.resume_url.sub(/\/[^\/]+\z/, "") : nil
              if discard_url.present?
                # We can use helpers.form_with or direct html form.
                # Since this is a Phlex component, we can use a direct html form helper:
                # form(action: discard_url, method: "post") do
                #   input(type: "hidden", name: "_method", value: "delete")
                #   ...
                # end
                form(action: discard_url, method: "post", class: "inline-block") do
                  token = helpers.form_authenticity_token
                  input(type: "hidden", name: "authenticity_token", value: token)
                  input(type: "hidden", name: "_method", value: "delete")
                  button(type: "submit", class: "pu-btn pu-btn-sm pu-btn-danger pu-btn-outline", data: {wizard_chooser_discard: true, confirm: "Are you sure you want to discard this progress?"}) do
                    "Discard"
                  end
                end
              end
            end
          end
        end

        def render_start_new
          div(class: "border-t border-[var(--pu-border)] bg-[var(--pu-surface-alt)] px-5 py-4") do
            a(href: @start_new_url, class: "pu-btn pu-btn-md pu-btn-primary w-full justify-center", data: {wizard_chooser_start_new: true}) do
              "Start new"
            end
          end
        end

        def updated_ago(entry)
          helpers.time_ago_in_words(entry.updated_at)
        rescue
          "a while"
        end

        def page_type = :wizard_chooser_page
      end
    end
  end
end
