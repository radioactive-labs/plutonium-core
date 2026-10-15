# frozen_string_literal: true

module Plutonium
  module UI
    module Interaction
      module Async
        # Lists the runs currently working on THIS resource, above its collection,
        # followed by the viewer's own runs that finished within
        # +recent_runs_window+ (see Page::Index#render_running_banner).
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
        # comment. An opaque run dispatched from a resource still records that
        # resource as its +target_type+, so it shows on that resource's index; one
        # dispatched from nowhere has none and appears on no resource index.
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
                # misleading (see Async::Executor#refuse_partial_batch). The run's
                # own page renders the pair.
                span(class: "font-medium text-[var(--pu-text)]") { plain run.to_label }
                plain " "
                run.in_progress? ? render_state(run) : render_outcome(run)
              end
              a(href: resource_url_for(run), class: "pu-btn pu-btn-xs pu-btn-soft-primary shrink-0") do
                plain t(run.in_progress? ? "plutonium.async.banner.view_progress" : "plutonium.async.banner.view_run")
              end
            end
          end

          def render_state(run)
            span(class: "text-[var(--pu-text-muted)]") { plain(Plutonium::Translation.value_label(run.class, :state, run.state) || run.state.humanize) }
          end

          # A finished run is listed for what it ended as, so outcome rather than
          # state ("completed" hides a partial :continue run; "failed" hides a
          # rejection), in the progress panel's colours.
          def render_outcome(run)
            span(class: "pu-badge pu-badge-#{RunProgress::BADGE_VARIANTS.fetch(run.outcome, "neutral")}") do
              plain(Plutonium::Translation.value_label(run.class, :outcome, run.outcome) || run.outcome.humanize)
            end
          end
        end
      end
    end
  end
end
