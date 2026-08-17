# frozen_string_literal: true

module Plutonium
  module UI
    module Interaction
      # Lists the runs currently working on THIS resource, above its collection.
      #
      # == Why it exists
      #
      # A dispatch redirects to the run's own page, but a user who navigates away
      # has no way back short of knowing the URL. The index of the resource being
      # worked on is where they will look, so that is where the run has to be.
      #
      # == Why it queries on target_type
      #
      # +target_type+ is a real column rather than a key inside the +options+
      # JSON precisely so this predicate can be indexed — see the migration's own
      # comment. An opaque run has no +target_type+ at all and therefore appears
      # on no resource index: it belongs to no resource.
      #
      # == Why it can render nothing
      #
      # An always-present empty banner is chrome that teaches the user to ignore
      # the area it occupies. When nothing is running there is nothing to say.
      class RunningBanner < Plutonium::UI::Component::Base
        def initialize(runs:)
          @runs = runs
        end

        attr_reader :runs

        def view_template
          return if runs.empty?

          div(class: "pu-running-banner mb-3 rounded-[var(--pu-radius-md)] border border-[var(--pu-border)] bg-[var(--pu-surface-alt)] p-3 space-y-2") do
            runs.each { |run| render_run(run) }
          end
        end

        private

        def render_run(run)
          div(class: "flex items-center justify-between gap-3 text-sm", data: {run_id: run.id}) do
            div(class: "min-w-0") do
              # The label carries the run's identity; the state carries what it
              # is doing. Progress is deliberately NOT shown bare here: after a
              # refused partial batch progress_done counts targets DISPOSITIONED
              # rather than attempted, so a number without its state is
              # misleading (see Runs::Executor#refuse_partial_batch). The run's
              # own page renders the pair.
              span(class: "font-medium text-[var(--pu-text)]") { plain run.to_label }
              plain " "
              span(class: "text-[var(--pu-text-muted)]") { plain run.state.humanize }
            end
            a(href: resource_url_for(run), class: "pu-btn pu-btn-xs pu-btn-soft-primary shrink-0") do
              plain "View progress"
            end
          end
        end
      end
    end
  end
end
