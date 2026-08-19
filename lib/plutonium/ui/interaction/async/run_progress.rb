# frozen_string_literal: true

module Plutonium
  module UI
    module Interaction
      module Async
        # The progress panel on a run's show page — the page IS the progress page.
        #
        # == How it refreshes
        #
        # Polling, not ActionCable: a turbo-frame the browser re-fetches on a timer
        # works on any deployment, including ones with no cable server, and a run's
        # progress is a handful of numbers that nobody needs sub-second. The frame
        # is driven by the +run-progress+ Stimulus controller, which lives INSIDE
        # the frame — so when the run finishes, the refreshed markup no longer
        # carries the controller and the timer stops of its own accord. A finished
        # run is a static record; a poll that never stops is a background request
        # per viewer, forever.
        #
        # The frame's +src+ is the run's own show URL. Turbo sends
        # +Turbo-Frame: <id>+ with that request, so the response must be the PANEL
        # ALONE — Plutonium's DynaFrameContent already wraps every response in a
        # frame named by that header, and a second tag with the same id would nest
        # the whole page inside its own progress frame (and again on the next
        # poll). {Async::RunDefinition::ShowPage} short-circuits the page for exactly this
        # request; this class drops its own frame tag to match.
        class RunProgress < Plutonium::UI::Component::Base
          include Phlex::Rails::Helpers::TurboFrameTag

          # Slow enough to be cheap for a page left open on a wall display, fast
          # enough that a short run does not look stuck.
          POLL_INTERVAL_MS = 2_000

          # Semantic colour per outcome. +completed_with_errors+ is deliberately
          # NOT success: see Plutonium::Interaction::Async::Run#outcome.
          BADGE_VARIANTS = {
            "pending" => "warning",
            "running" => "info",
            "completed" => "success",
            "completed_with_errors" => "warning",
            "failed" => "danger"
          }.freeze

          # Public so the page can recognise a poll of THIS panel and answer with
          # the panel alone.
          def self.frame_id(run) = "pu_run_progress_#{run.id}"

          def initialize(run)
            @run = run
          end

          attr_reader :run

          def view_template
            return render_panel if answering_own_frame?

            # `turbo-frame` defaults to `display: inline`, which swallows the
            # margin `sections_wrapper` needs to separate it from the card below.
            turbo_frame_tag(frame_id, class: "block") { render_panel }
          end

          private

          def frame_id = self.class.frame_id(run)

          # True when this render IS the response to the frame's own poll.
          def answering_own_frame? = current_turbo_frame == frame_id

          # Reload once, so the fields outside this frame stop disagreeing with it.
          def finished_attributes
            # The STRING, not true: Phlex renders a boolean attribute bare, and a
            # valueless data attribute is exactly the shape Stimulus's Boolean
            # coercion is least clear about.
            {data: {controller: "run-progress", run_progress_finished_value: "true"}}
          end

          def render_panel
            div(class: "pu-card pu-run-progress", **poll_attributes) do
              div(class: "pu-card-body space-y-4") do
                render_status
                render_progress
                render_failures if run.errors_log.any?
              end
            end
          end

          # Only an in-progress run carries the poll. Absent here, nothing on the
          # page has a timer — which is how the refresh stops.
          #
          # Except on the LAST poll, which needs one more instruction. Only this
          # panel lives in the polled frame; the fields beside it were rendered
          # once, when the run was dispatched. So a run that finishes leaves the
          # page showing two contradicting truths — a green "Completed, 5 of 5"
          # above a list still reading "Running", "0 done", "finished at -" — and
          # the stale half is the more detailed one. Telling the page to reload
          # itself once is what lets those fields catch up.
          #
          # It cannot loop. The flag is emitted only while ANSWERING A POLL, and
          # the reload it triggers is a full page render, where that is false.
          def poll_attributes
            return finished_attributes if !run.in_progress? && answering_own_frame?
            return {} unless run.in_progress?

            {
              data: {
                controller: "run-progress",
                run_progress_url_value: resource_url_for(run),
                run_progress_interval_value: POLL_INTERVAL_MS
              }
            }
          end

          def render_status
            div(class: "flex items-center gap-2 flex-wrap") do
              span(class: "pu-badge pu-badge-#{BADGE_VARIANTS.fetch(run.outcome, "neutral")}") do
                plain run.outcome.humanize
              end
              # The count rides alongside the badge rather than only in the list
              # below: a partially-applied :continue run ends as "completed", and
              # the one thing a reader must not be able to miss is that it did not
              # do everything it was asked to.
              if run.error_count.positive?
                span(class: "text-xs font-medium text-[var(--pu-text-danger)]") do
                  plain "#{run.error_count} #{"error".pluralize(run.error_count)}"
                end
              end
            end
          end

          # NEVER rendered without {#render_status} above it. After a refused
          # partial batch (:halt / :transactional), progress_done counts targets
          # DISPOSITIONED, not applied — so a run that performed nothing at all can
          # show progress_done > 0. Paired with the state that reads correctly;
          # alone it reads as work done. See Async::Executor#refuse_partial_batch.
          def render_progress
            fraction = run.progress_fraction

            # nil total is INDETERMINATE, not zero: opaque work has no denominator,
            # and a 0% bar would claim nothing has happened rather than admitting
            # the amount is unknown.
            return render_indeterminate if fraction.nil?

            percent = (fraction * 100).round
            div(class: "space-y-1") do
              div(class: "w-full h-2 rounded-full bg-[var(--pu-surface-alt)] overflow-hidden") do
                div(class: "h-2 rounded-full bg-primary-600", style: "width: #{percent}%")
              end
              div(class: "text-xs text-[var(--pu-text-muted)]") do
                plain "#{run.progress_done} of #{run.progress_total} targets (#{percent}%)"
              end
            end
          end

          def render_indeterminate
            div(class: "text-xs text-[var(--pu-text-muted)] pu-run-progress-indeterminate") do
              plain(run.in_progress? ? "Working…" : "No progress total was recorded")
            end
          end

          def render_failures
            div(class: "space-y-1") do
              div(class: "text-[10px] font-semibold uppercase tracking-wider text-[var(--pu-text-muted)]") do
                plain "Failures"
              end
              ul(class: "pu-run-progress-failures text-xs space-y-1") do
                run.errors_log.each do |entry|
                  li(class: "text-[var(--pu-text-danger)]") { plain failure_text(entry) }
                end
              end
            end
          end

          # A nil target_id is the RUN-LEVEL sentinel (see AsyncRun#record_target_failure!),
          # not a target whose id happens to be blank.
          def failure_text(entry)
            target_id = entry["target_id"]
            target_id.nil? ? entry["message"].to_s : "##{target_id}: #{entry["message"]}"
          end
        end
      end
    end
  end
end
