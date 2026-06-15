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
      Result = Struct.new(:ok, :errors, :completed, :redirect_step, :value, keyword_init: true) do
        def ok? = !!ok

        def completed? = !!completed

        def errors = self[:errors] || {}
      end

      attr_reader :wizard, :state

      def initialize(wizard_class:, store:, instance_key:, view_context: nil,
        owner: nil, anchor: nil, scope: nil, token: nil)
        @wizard_class = wizard_class
        @store = store
        @instance_key = instance_key
        @state = store.read(instance_key) || new_state(owner:, anchor:, scope:, token:)
        @wizard = wizard_class.new(view_context:)
        @wizard.data_attributes = @state.data
        @wizard.anchor = (@state.anchor || anchor) if wizard_class.anchored?
        rehydrate_persisted
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

      # Validate + stage a step, run its `on_submit` (in a transaction), then move
      # the cursor to the next visible step. On validation/`on_submit` failure the
      # cursor does not move and the errors are returned.
      def advance(step_key, params)
        step = step_for(step_key)
        errors = validate(step, params)
        return Result.new(ok: false, errors:) if errors.any?

        stage(params)
        run_on_submit(step) if step.on_submit
        @state.current_step = next_visible_after(step)&.key&.to_s
        persist_state
        Result.new(ok: true)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(ok: false, errors: e.record.errors.group_by_attribute)
      rescue StepError => e
        Result.new(ok: false, errors: {e.attribute => [e.message]})
      end

      # Move the cursor to the previous visible step. No validation; never discards
      # staged data (§6 — back is navigation, not submission).
      def back
        @state.current_step = previous_visible&.key&.to_s
        persist_state
        Result.new(ok: true)
      end

      # Abandon the flow: run cleanup (`on_rollback`/destroy tracked records, in
      # reverse step order) BEFORE clearing the row — `clear` is a `delete_all`
      # with no callbacks, so compensation must happen first (§2.3).
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

        pruned = prune_hidden(@state.data)

        return Result.new(ok: false) unless lock_for_completion!

        outcome = nil
        ActiveRecord::Base.transaction do
          @wizard.data_attributes = pruned
          outcome = @wizard.execute
          raise ActiveRecord::Rollback if outcome.failure?
        end

        if outcome.success?
          @store.complete(@instance_key)
          Result.new(ok: true, completed: true, value: outcome.value)
        else
          revert_completing!
          Result.new(ok: false, errors: wizard_errors)
        end
      rescue ActiveRecord::RecordInvalid => e
        revert_completing!
        Result.new(ok: false, errors: e.record.errors.group_by_attribute)
      rescue StepError => e
        revert_completing!
        Result.new(ok: false, errors: {e.attribute => [e.message]})
      end

      private

      def sync_data
        @wizard.data_attributes = @state.data
      end

      def stage(params)
        @state.data = @state.data.merge(params)
        sync_data
      end

      def persist_state
        @store.write(@instance_key, @state, cleanup_after: @wizard_class.cleanup_after)
      rescue ActiveRecord::RecordNotUnique
        # Concurrent creation raced us to the unique instance_key index; re-read the
        # existing row and proceed (§ carry-forward learning). The data we staged is
        # already in @state; a subsequent write will reconcile it.
        existing = @store.read(@instance_key)
        @state = existing if existing
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

        merged = @state.data.merge(params)
        errors = {}
        imported = step.imported_validate_fn&.call(merged)
        errors.merge!(imported) if imported
        errors.merge!(inline_errors(step, merged)) { |_k, a, b| Array(a) + Array(b) }
        errors.reject { |_attr, msgs| Array(msgs).blank? }
      end

      # Run the step's inline `validates` against a transient ActiveModel built from
      # the union schema, returning {attribute => [messages]} keyed by symbol.
      def inline_errors(step, merged)
        validations = step.validations
        return {} if validations.blank?

        klass = inline_validator_class(validations)
        obj = klass.new(merged)
        obj.valid?
        obj.errors.group_by_attribute
      end

      def inline_validator_class(validations)
        schema = @wizard_class.union_attribute_schema
        Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes

          schema.each { |name, type| attribute(name, type) }

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

      # Reverse-order cleanup of every step's tracked records (§2.3): the step's
      # `on_rollback` if it has one (with `persisted` populated), else destroy.
      def run_cleanup
        @wizard_class.steps.reverse_each do |step|
          records = located_records(step)
          next if records.empty?

          @wizard.persisted[step.key.to_sym] = records
          if step.on_rollback
            @wizard.instance_exec(&step.on_rollback)
          else
            records.reverse_each(&:destroy!)
          end
        end
      end

      def located_records(step)
        Array(@state.persisted[step.key.to_s]).filter_map { |gid| GlobalID::Locator.locate(gid) }
      end

      # The first visible non-review step that hasn't been visited+validated, i.e.
      # whose currently-staged data fails its validations (§6.3 completeness).
      def first_incomplete_visible
        visible_path.reject(&:review?).find { |step| validate(step, {}).any? }
      end

      # Drop staged data for attributes not owned by a currently-visible step (§6.3
      # pruning) — returns a working copy; the stored data is untouched.
      def prune_hidden(data)
        visible_keys = visible_path.flat_map { |s| s.attribute_schema.keys.map(&:to_s) }
        visible_keys += visible_path.flat_map { |s| s.structured_inputs.keys.map(&:to_s) }
        data.slice(*visible_keys)
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

      def rehydrate_persisted
        return if @state.persisted.blank?

        @state.persisted.each do |step_key, gids|
          records = Array(gids).filter_map { |gid| GlobalID::Locator.locate(gid) }
          @wizard.persisted[step_key.to_sym] = records
        end
      end

      def new_state(owner:, anchor:, scope:, token:)
        State.new(
          wizard: @wizard_class.name,
          instance_key: @instance_key,
          current_step: @wizard_class.steps.first&.key&.to_s,
          status: "in_progress",
          data: {},
          persisted: {},
          owner:,
          anchor:,
          scope:,
          token:
        )
      end

      def wizard_errors
        @wizard.errors.group_by_attribute.transform_values { |errs| errs.map(&:message) }
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
