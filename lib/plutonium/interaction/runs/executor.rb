# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # Performs a run: resolves its targets, calls the subclass's work, keeps
      # progress current, and applies the declared failure policy.
      #
      # Separate from {Plutonium::Interaction::Run} so the record stays a record,
      # and separate from {Job} so the whole thing can be driven synchronously in
      # a test or a console.
      #
      # == Authorization is re-derived here, per target, at the last moment
      #
      # {Context#targets} answers "may the initiator act on these?" once, up
      # front. That answer makes a good operator report but it is only true as of
      # the moment it was computed, and a bulk run over thousands of records acts
      # long afterwards. So the answer is re-derived immediately before each
      # +perform_on+, because BOTH of its inputs go stale:
      #
      # * the SUBJECTS (initiator, tenant) are cached on the context. They are
      #   re-read on a clock — see {SUBJECT_REFRESH_INTERVAL}.
      # * the RECORD is a snapshot from the resolution query, and predicates read
      #   record state (Blogging::PostPolicy#archive? is literally
      #   +record.published?+). Each target is re-read through the policy scope
      #   right before its check, which also catches a record that left the
      #   tenant mid-run.
      #
      # A target that fails the re-check is RECORDED as a failure, never silently
      # skipped: "you may no longer act on 3 of these" is exactly what tells an
      # operator the run under-applied.
      #
      # == Resuming after an interruption
      #
      # #call only ever STARTS from "pending" (see #claim!) — a run already
      # "running" is left alone, since two concurrent executors on the same
      # row would race. A run interrupted mid-batch (crash, dropped job) can
      # still be resumed safely: reset it to "pending" (see Runs::ReapJob)
      # and re-enqueue. Context#targets resolves only Run#unhandled_target_ids,
      # so a target already dispositioned before the interruption is not
      # redone.
      class Executor
        # How long a resolved (initiator, tenant) pair is trusted before
        # {Context#refresh_subjects!} re-reads it.
        #
        # Wall-clock rather than per-record because that is the shape of the risk
        # being managed: revocation urgency is measured in seconds, not in
        # records. Refreshing per record costs two queries per target — 20,000
        # extra queries on a 10,000-target run — to close a window this closes
        # for a handful.
        SUBJECT_REFRESH_INTERVAL = 5.seconds

        # Raised in place of calling +perform_on+ when the just-in-time re-check
        # refuses a target. A StandardError so it travels the same path as a
        # failure raised by the author's own code: a revoked permission is a
        # target failure, and the run's failure policy decides what that means.
        #
        # Deliberately never rescued BY TYPE — the blanket per-target rescue in
        # {#perform_one} catches it, which is the point. It exists to name the
        # condition at the raise site and in a log entry. Adding a typed rescue
        # for it would take it out of the failure policy's hands.
        class TargetRefusedError < StandardError; end

        # Raised out of a +:transactional+ batch so the run-level entry written
        # after the rollback still names the target that caused it — the
        # per-target entry that would have named it went back with the
        # transaction.
        #
        # Also never rescued by type: {#perform_all_or_nothing} catches
        # everything so it can reload after the rollback, and {#call} records it.
        class BatchAbortedError < StandardError; end

        attr_reader :run

        def initialize(run)
          @run = run
        end

        # @return [void]
        def call
          return unless claim!

          @context = build_context

          run.targeted? ? perform_targets : perform_opaque
        rescue StandardError, NotImplementedError => e
          # NotImplementedError is NOT a StandardError, and two things here raise
          # it: a run subclass that implements no work at all, and a policy
          # predicate that has been renamed since enqueue (Policy#send_with_report).
          # Both must land in the run's log rather than escaping.
          #
          # Swallowed rather than re-raised because ActiveJob would retry, and a
          # retry re-applies every target the run already committed. The row is
          # the report, and it now reads failed, with the reason.
          Rails.logger.warn { "plutonium: interaction run #{run.id} (#{run.class}) failed: #{e.message}" }
          run.fail!(e.message)
        end

        private

        attr_reader :context

        # Atomically claims a PENDING run so two concurrent deliveries (retry
        # after a crash, duplicate enqueue) can't both process it. A run
        # already "running" is left alone rather than replayed — that would
        # re-invoke perform_on on targets already applied. A stalled
        # "running" row surfaces to an operator instead of silently
        # double-applying; real resume needs per-target completion tracking,
        # which does not exist yet.
        #
        # @return [Boolean]
        def claim!
          now = Time.current
          claimed = run.class.where(id: run.id, state: "pending")
            .update_all(state: "running", started_at: now, last_activity_at: now) == 1

          unless claimed
            Rails.logger.warn { "plutonium: interaction run #{run.id} is #{run.state}; refusing to (re)start" }
            return false
          end

          run.assign_attributes(state: "running", started_at: now, last_activity_at: now)
          true
        end

        def build_context = Context.new(run)

        # send, not a plain call: Run#targeted? detects a non-public perform_on,
        # so the two shapes of work must be INVOKED the same way they are
        # detected. `private def perform` is a natural idiom for a method only
        # the framework is meant to call, and it must not change what the
        # executor does with it.
        def perform_opaque
          run.send(:perform)
          run.finish!
        end

        def perform_targets
          resolved = context.targets
          record_unresolved(resolved)

          return refuse_partial_batch(resolved) if unresolved?(resolved) && !continue?

          if transactional?
            perform_all_or_nothing(resolved.records)
            run.finish!
          elsif (remaining = perform_each(resolved.records))
            # The loop stopped, so the remaining targets were never attempted.
            # A run that did not do its job must not read as completed.
            run.fail!("stopped at the first target failure (#{run.failure_policy} policy); " \
                      "#{remaining} target(s) were not attempted")
          else
            # Partial failure under :continue is COMPLETED, not failed. The author
            # declared partial application acceptable, the executor ran to the
            # end, and errors_log plus progress_done carry the shortfall. Keeping
            # "failed" for runs that stopped early leaves the word meaning one
            # thing, which is what a retry — and the index banner — need.
            run.finish!
          end
        end

        # @return [Integer, nil] how many records were never attempted, if the
        #   failure policy stopped the loop early — nil if it ran to the end
        def perform_each(records)
          records.each_with_index do |record, index|
            return records.size - index - 1 if perform_one(record) == :halt
          end
          nil
        end

        def perform_all_or_nothing(records)
          # Model.transaction already wraps the block in with_connection (see
          # ActiveRecord::Transactions::ClassMethods#transaction), so the batch
          # holds one leased connection for its whole duration — which is both
          # what a transaction requires and what fiber-safety asks for. Reaching
          # for the connection ourselves would only duplicate that lease.
          run.class.transaction do
            records.each { |record| perform_one(record) }
          end
        rescue StandardError, NotImplementedError
          # Everything the block wrote went back with it: progress_done and every
          # per-target errors_log entry appended inside. Re-read so the in-memory
          # run stops carrying values the database no longer has — without this,
          # the fail! that follows would write those rolled-back values straight
          # back out and report work that was undone.
          run.reload
          raise
        end

        # @return [Symbol, nil] :halt when the failure policy says to stop
        #
        # Two failures deliberately do NOT become target failures, because they
        # are systemic — every remaining target would hit them identically, so
        # recording them per target would write M copies of one diagnosis (the
        # O(M²) errors_log that {#record_unresolved} exists to avoid) and end
        # with the run marked completed:
        #
        # * NotImplementedError ("this code was never written" — a policy
        #   predicate renamed since enqueue) is not a StandardError, so the
        #   blanket rescue below already lets it through.
        # * Context::UnresolvableError IS one, so it is let through explicitly.
        def perform_one(record)
          # send: see #perform_opaque.
          run.send(:perform_on, reauthorized(record))
          advance!(record.id)
          nil
        rescue Context::UnresolvableError
          # The initiator or the tenant was deleted while the run was working.
          # See the note above: this is the RUN's failure, not this target's.
          raise
        rescue => e
          raise BatchAbortedError, "target #{record.id} failed (#{e.message}); no targets were applied" if transactional?

          run.record_target_failure!(id: record.id, message: e.message)
          halt? ? :halt : nil
        end

        # Re-resolves a target through the policy scope and re-asks the predicate,
        # immediately before the work. Returns the FRESH instance, so the work
        # itself also acts on current state rather than on the snapshot the
        # up-front resolution loaded.
        #
        # One query per target, against a loop that already writes once per
        # target. Going through {Context#authorized_scope} rather than reloading
        # by primary key costs the same query and answers the wider question: a
        # record moved to another tenant since the run was dispatched simply is
        # not there.
        #
        # @raise [TargetRefusedError]
        def reauthorized(record)
          refresh_subjects_if_stale!

          key = record.class.primary_key
          # record.class, not the run's target_type: an STI row resolves its own
          # policy and therefore its own scope, which is the same rule
          # Context#policy_for follows.
          fresh = context.authorized_scope(record.class.all).find_by(key => record.public_send(key))
          raise TargetRefusedError, missing_message(record.id) if fresh.nil?
          raise TargetRefusedError, unauthorized_message(record.id) unless context.permitted?(fresh)

          fresh
        end

        # The clock belongs to the context, which owns the state it describes;
        # the cadence belongs here, because it is this executor's judgement about
        # how much staleness this shape of work can tolerate.
        def refresh_subjects_if_stale!
          return if Time.current - context.subjects_read_at < SUBJECT_REFRESH_INTERVAL

          context.refresh_subjects!
        end

        # Targets that were gone or no longer permitted when the run started,
        # recorded in ONE write.
        #
        # record_target_failure! self-persists, so a loop over M ids is M writes,
        # each rewriting the whole errors_log JSON — O(M²) bytes for a bulk run
        # whose targets have mostly disappeared. The plural form appends the
        # batch in a single update!, folding in the progress advance too:
        # unresolved targets still count as dispositioned, so the bar reaches
        # the end.
        def record_unresolved(resolved)
          entries = resolved.missing_ids.map { |id| {id: id, message: missing_message(id)} } +
            resolved.unauthorized_ids.map { |id| {id: id, message: unauthorized_message(id)} }
          return if entries.empty?

          run.record_target_failures!(entries)
        end

        def unresolved?(resolved) = resolved.missing_ids.any? || resolved.unauthorized_ids.any?

        # Note what progress_done means when this fires: {#record_unresolved} has
        # already counted the unresolved targets, so a refused batch finishes
        # with progress_done > 0 having performed NOTHING. The counter tracks
        # targets DISPOSITIONED, not targets attempted — which is the right
        # meaning for a progress bar (it has to reach the end) but is easy to
        # misread as work done. Task 6's page renders it directly: pair it with
        # the run's state, never on its own.
        #
        # :halt and :transactional both promise something a partial batch cannot
        # deliver — stop at the first problem, or apply everything or nothing —
        # and the problem is already known before any work has been done. Doing
        # part of the batch anyway would be the one outcome neither policy allows.
        def refuse_partial_batch(resolved)
          unresolved = resolved.missing_ids.size + resolved.unauthorized_ids.size
          run.fail!("#{unresolved} of #{run.target_ids.size} targets could not be resolved; " \
                    "a #{run.failure_policy} run does not apply a partial batch")
        end

        # Advances progress and records +id+ as dispositioned, in one write —
        # see Run#unhandled_target_ids, which is what lets a resumed run skip
        # it instead of reapplying it.
        def advance!(id)
          run.progress_done += 1
          run.handled_target_ids += [id.to_s]
          run.last_activity_at = Time.current
          run.save!
        end

        def missing_message(id) = "Target #{id} is no longer available"

        def unauthorized_message(id) = "Target #{id} is no longer permitted by #{context.policy_action}"

        def continue? = run.failure_policy == :continue

        def halt? = run.failure_policy == :halt

        def transactional? = run.failure_policy == :transactional
      end
    end
  end
end
