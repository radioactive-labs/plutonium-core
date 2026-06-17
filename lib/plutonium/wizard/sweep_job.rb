# frozen_string_literal: true

module Plutonium
  module Wizard
    # The abandonment sweep (§8.1). Reaps idle wizard sessions whose +expires_at+
    # has passed (status +in_progress+ or +completing+ — the latter catches a
    # finalize that crashed mid-flight, §6.2). For each row it builds a {Runner}
    # and calls +cancel+, which runs the wizard's cleanup — each step's per-step
    # +on_rollback+ (additive side-effect cleanup, if any) then the engine's
    # always-on destroy of every tracked record, in reverse order — and then
    # deletes the row.
    #
    # This is **load-bearing for save-as-you-go wizards**: for +execute+-only
    # wizards an unscheduled sweep merely leaves stale session rows (harmless), but
    # for +on_submit+ wizards the sweep is the only thing that cleans up abandoned
    # partial domain records. Hosts must schedule it (a periodic job / rake task).
    #
    # The job is idempotent and safe to re-run: a row already cleared is skipped,
    # and an unconstantizable wizard class is skipped while the row is still reaped.
    # +completed+ rows are never touched (the +sweepable+ scope excludes them).
    class SweepJob < ActiveJob::Base
      def perform(now: Time.current)
        store = Store::ActiveRecord.new

        Session.sweepable(now).find_each do |row|
          sweep_row(row, store)
        end
      end

      private

      def sweep_row(row, store)
        wizard_class = row.wizard.safe_constantize

        if wizard_class
          # `cancel` runs the wizard's cleanup (each step's on_rollback, then the
          # engine always destroys its tracked records) and then clears the row.
          #
          # Reconstruct the run's context from the row the sweep already trusts:
          #
          # - `current_user: row.owner` — a non-`anonymous` wizard's state is
          #   owner-scoped (§4.5), so with no owner the runner would mismatch, drop
          #   the loaded state, and cancel an EMPTY run, orphaning every `persist`'d
          #   record (the exact case the sweep exists for).
          # - `current_scoped_entity: row.scope` — the wizard's `current_scoped_entity`
          #   is set from this argument (not the loaded state), so a tenant-aware
          #   `on_rollback` would otherwise run with a nil tenant.
          #
          # (The `anchor` needs no argument — the runner restores it from the loaded
          # state.)
          Runner.new(
            wizard_class: wizard_class,
            store: store,
            instance_key: row.instance_key,
            current_user: row.owner,
            current_scoped_entity: row.scope
          ).cancel
        end

        # Safety net: an unconstantizable wizard never ran `cancel` (so the row is
        # still present), and a `cancel` failure shouldn't leave the row behind.
        # `clear` is a no-op when the row is already gone.
        store.clear(row.instance_key)
      end
    end
  end
end
