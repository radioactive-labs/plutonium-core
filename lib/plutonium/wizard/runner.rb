# frozen_string_literal: true

module Plutonium
  module Wizard
    # The pure navigation/commit engine (§6). Given a wizard class, a {Store}, and
    # an instance key, it loads (or builds) the {State}, hydrates a single wizard
    # instance, and drives the flow: compute the visible path, validate + stage a
    # step, run per-step `on_submit`/`persist`, navigate back, cancel (cleanup),
    # and finalize via `execute` (with the completeness check, branch-hidden
    # pruning, and the locked `in_progress → completing` transition).
    #
    # No HTTP/controller/UI here — the controller (Task 5) drives this directly.
    class Runner
      # The outcome of a runner operation.
      #
      # - +ok+ — the operation succeeded (validation passed / navigation moved).
      # - +errors+ — {attribute => [messages]} when it didn't.
      # - +completed+ — finalize ran `execute` to completion.
      # - +redirect_step+ — finalize found a completeness gap; the step to bounce to.
      # - +value+ — the successful `execute` outcome's value.
      Result = Struct.new(:ok, :errors, :completed, :redirect_step, :value) do
        def ok? = !!ok

        def completed? = !!completed

        def errors = self[:errors] || {}
      end

      attr_reader :wizard, :state

      def initialize(wizard_class:, store:, instance_key:, view_context: nil,
        owner: nil, anchor: nil, scope: nil, token: nil,
        current_user: nil, current_scoped_entity: nil)
        @wizard_class = wizard_class
        @store = store
        @instance_key = instance_key
        # The keyed row IS the lock (§4.2): an existing in_progress row at this
        # instance_key is RESUMED, never forked. `read` returns it (or any prior
        # row, incl. a completed one-time marker) for the digest; a fresh launch
        # with no row builds new state.
        existing = store.read(instance_key)

        # Owner-scoped resume (§4.5): for a non-`anonymous` wizard, a row may only
        # be resumed by its owner. A run id leaked in a URL can't be picked up by a
        # different logged-in user — a mismatch reads as "no such run for you".
        # `@forbidden` lets the driving layer 404 rather than silently fork.
        if existing && owner_mismatch?(wizard_class, existing, current_user)
          existing = nil
          @forbidden = true
        end

        @resumed = !existing.nil?
        @state = existing || new_state(owner:, anchor:, scope:, token:)
        @wizard = wizard_class.new(view_context:)
        @wizard.data_attributes = @state.data
        @wizard.anchor = (@state.anchor || anchor) if wizard_class.anchored?
        @wizard.current_user = current_user
        @wizard.current_scoped_entity = current_scoped_entity
        @wizard.wizard_token = token
        # `persisted` is rehydrated LAZILY (§4.5): inject the stored GID source so
        # `wizard.persisted[:key]` locates that key's GIDs on first read (memoized)
        # — a request that never reads `persisted` issues zero locate queries. The
        # anchor (the authz/scoping gate) is still resolved eagerly above.
        @wizard.persisted_gid_source = @state.persisted
      end

      # Whether a row already existed at this key when the runner was built — i.e.
      # this launch RESUMED rather than started fresh (§4.2).
      def resumed? = @resumed

      # Whether an existing row at this key belongs to a DIFFERENT user (§4.5
      # owner-scoping). The driving layer turns this into a 404 so a leaked run id
      # can't be resumed by another logged-in user.
      def forbidden? = !!@forbidden

      # Whether this run's key already has a retained `completed` one-time marker
      # (§4.3 / §9) — re-entering a finished one-time wizard. The driving layer
      # redirects such a request out rather than re-running it.
      def completed_one_time?
        @wizard_class.one_time? && @state.status.to_s == "completed"
      end

      # The currently-visible step path (§6.2 subtractive branching). Each step's
      # `condition:` is evaluated against the latest staged `data`; the review step
      # is always last by construction. Recomputed each call.
      def visible_path
        sync_data
        @wizard_class.steps.select do |step|
          step.condition.nil? || @wizard.instance_exec(&step.condition)
        end
      end

      # The visible step matching the stored cursor, or the first visible step.
      def current_step
        path = visible_path
        path.find { |s| s.key.to_s == @state.current_step.to_s } || path.first
      end

      # The keys of steps the user has REACHED (the high-water mark — every step the
      # cursor has landed on, including the one advanced from and the one advanced
      # to). Drives stepper clickability / `go_to` reachability (§7); it does NOT
      # gate completeness — that's `submitted?`. Reaching a step lets you navigate
      # back to it without forcing it to count as done.
      def visited_keys
        @state.visited.map(&:to_s)
      end

      # Whether a visible non-review step is complete: SUBMITTED AND its staged data
      # currently validates (§6.3). Drives the review step's per-step jump links and
      # the gated Finish button (§2.5). A review step is "complete" iff every other
      # visible step is. "Submitted" (advanced THROUGH, not merely reached) is the
      # gating notion — distinct from `visited`/reached, which is for navigation —
      # so a user can't skip a zero-validation step just by landing on it.
      def step_complete?(step)
        return incomplete_visible_steps.empty? if step.review?

        submitted?(step) && validate(step, {}).empty?
      end

      # The ordered visible non-review steps that aren't yet complete (§6.3). The
      # review step lists these as "fix this" jump links and gates Finish.
      def incomplete_visible_steps
        visible_path.reject(&:review?).select do |step|
          !submitted?(step) || validate(step, {}).any?
        end
      end

      # Validate + stage a step, run its `on_submit` (in a transaction), then move
      # the cursor to the next visible step. On validation/`on_submit` failure the
      # cursor does not move and the errors are returned.
      def advance(step_key, params)
        step = step_for(step_key)
        errors = validate(step, params)
        return Result.new(ok: false, errors:) if errors.any?

        stage(step.key, params)
        run_on_submit(step) if step.on_submit
        @state.visited |= [step.key.to_s]
        # Staging this step's params may have flipped a branch `condition:`, hiding
        # an earlier step that already persisted records (save-as-you-go). Prune it
        # NOW — roll its records back and clear its state — so nothing is orphaned
        # for the rest of the flow (§6.3). A rollback failure here surfaces as a
        # step failure (same as `on_submit`), it is not swallowed; the cursor does
        # not move and the advance's data is not lost (the prune persists state).
        prune_departed_steps
        @state.current_step = next_visible_after(step)&.key&.to_s
        # Mark the step we ARRIVE at visited too, not just the one we left. `visited`
        # is the set of steps the user has *reached* (the high-water mark) — what the
        # stepper uses to decide which headers link. Without this, landing on a step
        # and navigating away before completing it would leave it unreachable (you
        # couldn't click back to it). Completeness gating is unaffected: it also
        # checks validity, so a required step reached-but-empty still reads incomplete.
        @state.visited |= [@state.current_step].compact
        persist_state
        Result.new(ok: true)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(ok: false, errors: message_errors(e.record))
      rescue StepError => e
        Result.new(ok: false, errors: {e.attribute => [e.message]})
      end

      # Point the cursor at a specific visible step on a GET (stepper jump / resume
      # via direct URL). Only honored when the target is a currently-visible step
      # the user has already visited — forward jumps to unvisited steps are not
      # allowed (§7). The review step is reachable once it's the visible terminal.
      # No persistence: a GET must not mutate stored state; the cursor move lives
      # for this request so the right step renders seeded from staged data.
      def go_to(step_key)
        return if step_key.blank?

        target = visible_path.find { |s| s.key.to_s == step_key.to_s }
        return unless target
        return if target.key.to_s == @state.current_step.to_s

        # The review step is reachable once the user has started the flow (visited
        # at least one step): it shows the auto-summary, the outstanding "fix this"
        # links, and a Finish that stays disabled until every step is complete —
        # the actual finalize POST re-checks completeness regardless. Other steps
        # are reachable only once visited (no forward jumps to unvisited steps).
        reachable = target.review? ? visited_keys.any? : visited_keys.include?(target.key.to_s)
        @state.current_step = target.key.to_s if reachable
      end

      # Move the cursor to the previous visible step. No validation; never discards
      # staged data (§6 — back is navigation, not submission).
      def back
        @state.current_step = previous_visible&.key&.to_s
        persist_state
        Result.new(ok: true)
      end

      # Abandon the flow: run cleanup (each step's `on_rollback`, then always
      # destroy its tracked records, in reverse step order) BEFORE clearing the
      # row — `clear` is a `delete_all` with no callbacks, so compensation must
      # happen first (§2.3).
      def cancel
        run_cleanup
        @store.clear(@instance_key)
        Result.new(ok: true)
      end

      # Finish the flow (§6.3): assert every visible non-review step is visited and
      # valid (else bounce to the first gap); prune branch-hidden data on a working
      # copy; perform the locked `in_progress → completing` transition; run
      # `execute` in a transaction; complete the row on success, revert on failure.
      def finalize
        gap = first_incomplete_visible
        return Result.new(ok: false, redirect_step: gap.key) if gap

        # Safety net (§6.3): roll back + forget any branch-hidden step that still
        # holds persisted records or staged data, so nothing orphaned survives into
        # `execute`. `advance` prunes promptly, but a step can be hidden via paths
        # that don't pass through `advance` (e.g. seeded/resumed state).
        prune_departed_steps
        pruned = prune_hidden(@state.data)

        return Result.new(ok: false) unless lock_for_completion!

        outcome = nil
        ActiveRecord::Base.transaction do
          @wizard.data_attributes = pruned
          outcome = @wizard.execute
          raise ActiveRecord::Rollback if outcome.failure?
        end

        if outcome.success?
          # Repeatability (§4.3): a one-time wizard RETAINS its completed row at
          # the key (blocks restart, the gate checks it); every other wizard
          # DELETES the row on completion (repeatable — tokened runs always are).
          if @wizard_class.one_time?
            @store.complete(@instance_key)
          else
            @store.clear(@instance_key)
          end
          Result.new(ok: true, completed: true, value: outcome.value)
        else
          revert_completing!
          Result.new(ok: false, errors: wizard_errors)
        end
      rescue ActiveRecord::RecordInvalid => e
        revert_completing!
        Result.new(ok: false, errors: message_errors(e.record))
      rescue StepError => e
        revert_completing!
        Result.new(ok: false, errors: {e.attribute => [e.message]})
      rescue
        # `lock_for_completion!` committed `completing` in its own transaction
        # before `execute` ran (§6.2). Any hard failure here must revert that row
        # to `in_progress` so the user can retry, then propagate.
        revert_completing!
        raise
      end

      private

      def sync_data
        @wizard.data_attributes = @state.data
      end

      # Stage a step's submitted (flat) fields under its step key — `data` is keyed
      # by step ({step_key => {field => value}}), so a step's writes never touch
      # another step's slice.
      def stage(step_key, params)
        key = step_key.to_s
        current = @state.data[key] || {}
        @state.data = @state.data.merge(key => current.merge(params))
        sync_data
      end

      def persist_state
        @store.write(@instance_key, @state, cleanup_after: @wizard_class.cleanup_after)
      rescue ActiveRecord::RecordNotUnique
        # Concurrent creation raced us to the unique instance_key index. Re-read the
        # existing row and merge the data/cursor/visited we just staged onto it, then
        # write once more so this advance's work isn't lost (§6.2 carry-forward).
        existing = @store.read(@instance_key)
        return unless existing

        # `data` is nested ({step_key => {field => value}}); deep-merge so a
        # concurrent step's fields aren't clobbered by a shallow top-level merge.
        existing.data = existing.data.deep_merge(@state.data)
        existing.persisted = existing.persisted.merge(@state.persisted)
        existing.visited |= @state.visited
        existing.current_step = @state.current_step
        @state = existing
        @store.write(@instance_key, @state, cleanup_after: @wizard_class.cleanup_after)
      end

      def step_for(key)
        @wizard_class.steps.find { |s| s.key.to_s == key.to_s }
      end

      def next_visible_after(step)
        path = visible_path
        idx = path.index { |s| s.key == step.key }
        idx ? path[idx + 1] : path.first
      end

      def previous_visible
        path = visible_path
        idx = path.index { |s| s.key.to_s == @state.current_step.to_s } || 0
        path[[idx - 1, 0].max]
      end

      # Validate a step's params: imported (model) validation merged with inline
      # `validates`. `imported_validate_fn` MAY be nil (validate: false) — nil-guard.
      def validate(step, params)
        return {} if step.review?

        merged = (@state.data[step.key.to_s] || {}).merge(params)
        errors = {}
        imported = step.imported_validate_fn&.call(merged)
        errors.merge!(stringify_messages(imported)) if imported
        errors.merge!(inline_errors(step, merged)) { |_k, a, b| Array(a) + Array(b) }
        errors.reject { |_attr, msgs| Array(msgs).blank? }
      end

      # Run the step's inline `validates` against a transient ActiveModel built from
      # THIS step's schema (not a cross-step union), returning {attribute => [String
      # messages]} keyed by symbol.
      def inline_errors(step, merged)
        validations = step.validations
        return {} if validations.blank?

        klass = inline_validator_class(step.attribute_schema, validations)
        obj = klass.new(merged)
        obj.valid?
        message_errors(obj)
      end

      def inline_validator_class(schema, validations)
        Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes

          # Anonymous classes have no name, which breaks `error.message`'s
          # translation lookup (it calls `model_name`). Supply a stable one.
          def self.model_name = ActiveModel::Name.new(self, nil, "WizardStep")

          schema.each { |name, type| attribute(name, Plutonium::Wizard.safe_attribute_type(type)) }

          define_method(:initialize) do |attrs = {}|
            super((attrs || {}).symbolize_keys.slice(*schema.keys))
          end

          validations.each do |args, options|
            validates(*args, **options)
          end
        end
      end

      # Run the step's `on_submit` in a transaction, with the `persist` macro bound
      # to the wizard for the duration. Tracked records' GIDs land in
      # `state.persisted[step_key]`; the live records land in `wizard.persisted`.
      def run_on_submit(step)
        tracker = PersistTracker.new
        ActiveRecord::Base.transaction do
          sync_data
          @wizard.define_singleton_method(:persist) { |*records| tracker.add(records.flatten) }
          begin
            @wizard.instance_exec(&step.on_submit)
          ensure
            @wizard.singleton_class.send(:remove_method, :persist) if @wizard.singleton_class.method_defined?(:persist)
          end
        end
        @state.persisted = @state.persisted.merge(step.key.to_s => tracker.gids)
        @wizard.persisted[step.key.to_sym] = tracker.records
      end

      # Reverse-order cleanup of every step's tracked records (§2.3): run each
      # step's `on_rollback` (if any) then always destroy its tracked records.
      def run_cleanup
        ActiveRecord::Base.transaction do
          @wizard_class.steps.reverse_each { |step| rollback_step(step) }
        end
      end

      # Per-step rollback (§2.3), shared by `run_cleanup` (cancel/sweep) and the
      # branch-hidden prune path (§6.3). `persist`'d records are ALWAYS destroyed
      # by the engine; `on_rollback` is an OPTIONAL hook for ADDITIONAL cleanup of
      # untracked side effects (refund a charge, call an external API), run while
      # the records are still alive so it can read `persisted[step]`.
      #
      # Order: locate the step's tracked records and populate `wizard.persisted`,
      # run the user's `on_rollback` FIRST (records still alive — e.g. to read a
      # `charge_id` to refund), THEN destroy the records in reverse order via
      # `destroy!` (which respects a model's own soft-delete/paranoia override).
      #
      # A no-op only when the step tracked nothing AND has no `on_rollback` (so a
      # step never persisted to and with no compensator issues no locate beyond
      # the single `located_records` probe). A side-effect-only step (an
      # `on_rollback` but no persisted records) still runs its `on_rollback`.
      # Callers wrap this in a transaction so the compensating writes are atomic.
      def rollback_step(step)
        records = located_records(step)
        return if records.empty? && step.on_rollback.nil?

        @wizard.persisted[step.key.to_sym] = records
        @wizard.instance_exec(&step.on_rollback) if step.on_rollback
        records.reverse_each(&:destroy!)
      end

      def located_records(step)
        Array(@state.persisted[step.key.to_s]).filter_map { |gid| GlobalID::Locator.locate(gid) }
      end

      # The first visible non-review step that hasn't been submitted+validated
      # (§6.3): a step is incomplete if it was never SUBMITTED (advanced through) OR
      # its staged data is invalid. A zero-validation step is therefore NOT complete
      # until submitted, so a user can't skip it and still finalize. Branch-hidden
      # steps fall out of `visible_path` and are excluded naturally.
      def first_incomplete_visible
        visible_path.reject(&:review?).find do |step|
          !submitted?(step) || validate(step, {}).any?
        end
      end

      # Whether a step has been SUBMITTED (advanced through) — its staged `data`
      # slice exists. Distinct from `visited`/reached: advancing TO a step (landing
      # on it) doesn't stage its data, so it isn't "submitted" until the user
      # Nexts through it. This is what gates completeness/Finish (§6.3).
      def submitted?(step)
        @state.data.key?(step.key.to_s)
      end

      # Drop the staged slice of any step not currently visible (§6.3 pruning) —
      # `data` is keyed by step, so this is a slice of the visible step keys.
      # Returns a working copy; the stored data is untouched.
      def prune_hidden(data)
        data.slice(*visible_path.reject(&:review?).map { |s| s.key.to_s })
      end

      # Fully prune every step that has left the visible path but still has
      # persisted records or staged `data` (§6.3). Save-as-you-go means a step's
      # `on_submit` may have persisted records; when a later answer hides that step
      # those records would otherwise be orphaned (`prune_hidden` only slices the
      # working-copy `data`, it never rolls records back). For each departed step we
      # roll its records back (`rollback_step` — the step's `on_rollback` then the
      # engine's destroy), clear its persisted/data/visited state, then persist so
      # the cleared state is durable.
      #
      # Only departed steps that actually hold something are touched — a step never
      # persisted to and with no staged data issues no locate (we don't probe the
      # whole step list), so the lazy-persisted contract is preserved.
      def prune_departed_steps
        visible = visible_path
        departed = @wizard_class.steps.reject do |step|
          visible.any? { |v| v.key == step.key } || !step_has_state?(step)
        end
        return if departed.empty?

        # Compensating writes are atomic, consistent with `run_cleanup`/`on_submit`.
        # Reverse order so later steps unwind before the earlier ones they built on.
        ActiveRecord::Base.transaction do
          departed.reverse_each { |step| rollback_step(step) }
        end

        departed.each { |step| forget_step(step) }
        persist_state
      end

      # Whether a step holds anything worth pruning: persisted records (its key is
      # present in stored `persisted`) or a non-empty staged `data` slice for the
      # step. Pure hash/key inspection — never locates.
      def step_has_state?(step)
        return true if @state.persisted.key?(step.key.to_s)

        @state.data[step.key.to_s].present?
      end

      # Erase all trace of a step that left the visible path: its persisted GIDs
      # (state + the live wizard view), its staged `data`, and its visited mark — so
      # if the branch is re-entered the step is treated as unvisited and its
      # `on_submit` re-runs cleanly (§6.3).
      def forget_step(step)
        key = step.key.to_s
        @state.persisted = @state.persisted.except(key)
        @wizard.persisted[step.key.to_sym] = []

        @state.data = @state.data.except(key)
        @state.visited = @state.visited - [key]
        sync_data
      end

      # The locked `in_progress → completing` transition (§6.2). With the AR store a
      # row exists and we lock it; the Memory store has no row, so there's nothing
      # to lock and we proceed (the in-process test can't race). Returns false for
      # the loser of a concurrent finalize.
      def lock_for_completion!
        row = Session.find_by(instance_key: @instance_key)
        return true unless row

        row.with_lock do
          return false unless row.status_in_progress?
          row.update!(status: "completing")
        end
        true
      end

      def revert_completing!
        Session.where(instance_key: @instance_key, status: "completing")
          .update_all(status: "in_progress")
      end

      # Owner-scoping check (§4.5): a non-`anonymous` wizard's row may only be
      # resumed by the user that owns it. An `anonymous` wizard is guarded by its
      # unguessable run id instead (no owner), so it never mismatches here.
      def owner_mismatch?(wizard_class, state, current_user)
        return false if wizard_class.anonymous?
        return false if state.owner.nil?

        gid(state.owner) != gid(current_user)
      end

      def gid(record)
        record&.to_global_id&.to_s
      end

      def new_state(owner:, anchor:, scope:, token:)
        State.new(
          wizard: @wizard_class.name,
          instance_key: @instance_key,
          current_step: @wizard_class.steps.first&.key&.to_s,
          status: "in_progress",
          data: {},
          persisted: {},
          visited: [],
          owner:,
          anchor:,
          scope:,
          token:
        )
      end

      def wizard_errors
        message_errors(@wizard)
      end

      # Normalize a model's errors to {attribute_sym => [String messages]} (§6.1).
      def message_errors(obj)
        obj.errors.group_by_attribute.transform_values { |errs| errs.map(&:message) }
      end

      # Normalize a {attribute => [ActiveModel::Error | String]} hash (e.g. from
      # `imported_validate_fn`) to {attribute => [String messages]} (§6.1).
      def stringify_messages(errors)
        errors.transform_values do |msgs|
          Array(msgs).map { |m| m.respond_to?(:message) ? m.message : m }
        end
      end

      # Accumulates the records passed to the `persist` macro inside `on_submit`.
      class PersistTracker
        def initialize
          @records = []
        end

        def add(records)
          @records.concat(Array(records))
        end

        attr_reader :records

        def gids
          @records.map { |r| r.to_global_id.to_s }
        end
      end
    end
  end
end
