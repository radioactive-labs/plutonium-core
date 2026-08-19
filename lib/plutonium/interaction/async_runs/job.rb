# frozen_string_literal: true

module Plutonium
  module Interaction
    module AsyncRuns
      # The ActiveJob entry point for a run.
      #
      # The only thing that crosses the process boundary is the run's id. Every
      # scrap of context — who started it, which tenant, which targets, which
      # policy — is re-read from the row by {Context}, so nothing is inherited
      # from the dispatching request. That is what makes a run safe to perform
      # minutes or hours later, on another machine.
      class Job < ActiveJob::Base
        # A block, not a value: the queue is read at enqueue time, so a host that
        # configures it in an initializer is not racing this class's load order.
        queue_as { Plutonium.configuration.async_runs.queue }

        # A per-run semaphore, when the host's queue offers one. Solid Queue
        # mixes ActiveJob::ConcurrencyControls into ActiveJob::Base whenever it
        # is in the bundle; Plutonium depends on neither, so the declaration is
        # conditional rather than assumed.
        #
        # This is not a second copy of Executor#claim!. claim! can only REFUSE a
        # duplicate delivery, and only once it is already running: the queue has
        # spent a worker slot to find out, and — worse — a resume that the reaper
        # started while the original worker is still mid-batch has by then
        # already re-entered perform_on for one target (see AsyncRuns::ReapJob, and
        # the lock_version fence that bounds but cannot prevent that). A
        # semaphore removes the race one step earlier: the second delivery waits
        # rather than racing, so on a queue that supports this the double-applied
        # target does not happen at all.
        if respond_to?(:limits_concurrency)
          # Keyed on the RUN, so runs never serialize against each other — only
          # against another delivery of themselves. Solid Queue prefixes the key
          # with the concurrency group (this class's name), so a host job keyed
          # on the same id cannot collide with it.
          #
          # +key+ and +to+ only: they are the two options every Solid Queue
          # release has taken. +on_conflict+ arrived in 1.2, and passing it would
          # turn an older host's boot into an ArgumentError — its default
          # (+:block+) is what a run wants anyway. A discarded delivery would
          # mean a reaper's resume silently dropped when the semaphore it is
          # waiting on is merely stale.
          limits_concurrency to: 1, key: ->(run_id) { run_id }

          # Read at dispatch time rather than passed to +limits_concurrency+
          # here, for the same reason queue_as takes a block — this class is
          # autoloaded, and a host configures stall_after in an initializer.
          #
          # stall_after is the right duration because it is the same question:
          # "how long may a run be silent before we assume its worker is dead?"
          # The semaphore then expires no later than the point the reaper would
          # resume the run anyway. Solid Queue's 3-minute default would expire
          # mid-batch on any run big enough to be worth dispatching, handing the
          # exclusivity away while the work is still going.
          def self.concurrency_duration = Plutonium.configuration.async_runs.stall_after
        end

        def perform(run_id)
          run = Plutonium::Interaction::AsyncRun.find_by(id: run_id)

          # A run deleted between enqueue and perform is not an error — there is
          # simply nothing to do, and raising would only retry until the queue
          # gives up.
          return if run.nil?

          # Idempotence, and the guard against a retry re-applying committed
          # work: a settled run has already reported its outcome, and performing
          # it again would act on its targets a second time.
          unless run.in_progress?
            Rails.logger.warn { "plutonium: interaction run #{run.id} is #{run.state}; skipping" }
            return
          end

          Executor.new(run).call
        end
      end
    end
  end
end
