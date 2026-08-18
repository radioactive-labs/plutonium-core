# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # Resumes runs stuck pending/running long past their last recorded
      # activity — a worker crash mid-batch, or a job the queue silently
      # dropped.
      #
      # Resetting to "pending" and re-enqueuing is safe, not a replay: the
      # executor resumes from Run#unhandled_target_ids, so a target already
      # dispositioned before the interruption is not redone. This is a
      # heuristic on TIME, not a true lease — a run that is merely slow (not
      # dead) and happens to cross stall_after gets resumed too, and briefly
      # races its still-live worker. Set stall_after well above this app's
      # slowest legitimate run to keep that rare.
      #
      # Hosts must schedule this themselves (a periodic job / cron task),
      # same as Wizard::SweepJob.
      class ReapJob < ActiveJob::Base
        def perform(stall_after: Plutonium.configuration.interaction_runs.stall_after)
          threshold = stall_after.ago

          Run.stalled(before: threshold).find_each { |run| reap(run, threshold) }
        end

        private

        # The conditional UPDATE re-checks "still stalled" and claims the row
        # in one atomic statement, so a run that progressed (or finished)
        # between the query above and now is left alone.
        def reap(run, threshold)
          resumed = Run.stalled(before: threshold).where(id: run.id).update_all(state: "pending") == 1
          return unless resumed

          Rails.logger.info { "plutonium: resuming stalled interaction run #{run.id} (#{run.class})" }
          Job.perform_later(run.id)
        end
      end
    end
  end
end
