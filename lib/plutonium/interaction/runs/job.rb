# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
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
        queue_as { Plutonium.configuration.interaction_runs.queue }

        def perform(run_id)
          run = Plutonium::Interaction::Run.find_by(id: run_id)

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
