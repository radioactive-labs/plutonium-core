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
      # dispositioned before the interruption is not redone.
      #
      # This is still a heuristic on TIME, not a true lease: a run that is merely
      # slow (not dead) and crosses stall_after gets resumed too. What bounds
      # that is lock_version — see #reap. The resumed row's version no longer
      # matches the live worker's, so the live worker stops at its next write
      # rather than racing. Two things that does NOT do: it cannot interrupt an
      # in-flight perform_on (a target may be applied twice, once by each side),
      # and it cannot roll back what the superseded worker already committed. Set
      # stall_after well above this app's slowest legitimate run.
      #
      # Hosts must schedule this themselves (a periodic job / cron task),
      # same as Wizard::SweepJob.
      class ReapJob < ActiveJob::Base
        # One sweep at a time, when the host's queue offers a semaphore (see
        # Runs::Job, which explains the conditional and why only +key+/+to+ are
        # passed). A scheduled sweep that outlives its own interval would
        # otherwise overlap the next tick and rescan the same rows; the atomic
        # UPDATE in #reap keeps that CORRECT, but it is still two workers doing
        # one job's work.
        #
        # A constant key: every sweep is the same sweep, so they queue behind
        # each other globally rather than per row.
        if respond_to?(:limits_concurrency)
          limits_concurrency to: 1, key: ->(*) { "sweep" }
        end

        def perform(stall_after: Plutonium.configuration.interaction_runs.stall_after)
          threshold = stall_after.ago

          Run.stalled(before: threshold).find_each { |run| reap(run, threshold) }
        end

        private

        # The conditional UPDATE re-checks "still stalled" and claims the row
        # in one atomic statement, so a run that progressed (or finished)
        # between the query above and now is left alone.
        #
        # Bumping lock_version is what makes resuming a merely-SLOW run safe
        # rather than merely unlikely. The executor that is still alive holds the
        # old value, so its very next write raises ActiveRecord::StaleObjectError
        # and it abandons the pass (see Runs::Executor#call) instead of racing
        # the new one and silently losing whichever progress write landed second.
        # It does not un-apply work already committed — this bounds the damage of
        # a bad stall_after, it does not make one free.
        # last_activity_at is stamped because Run.stalled matches on it: leaving
        # it at its old value means the row this sweep just resumed is STILL
        # stalled, so the next sweep reaps it again, and the one after that —
        # bumping lock_version and re-enqueuing every interval until a worker
        # finally claims it. On a backed-up queue that is an unbounded pile of
        # duplicate deliveries for one run.
        #
        # Resuming is not the run's own activity, but it is activity ON the run,
        # which is what the scope is really asking about: has anything happened
        # here lately. It buys the resumed job a full stall_after to be picked
        # up before this sweep concludes anything again.
        def reap(run, threshold)
          resumed = Run.stalled(before: threshold).where(id: run.id)
            .update_all(["state = ?, last_activity_at = ?, lock_version = lock_version + 1",
              "pending", Time.current]) == 1
          return unless resumed

          Rails.logger.info { "plutonium: resuming stalled interaction run #{run.id} (#{run.class})" }
          Job.perform_later(run.id)
        end
      end
    end
  end
end
