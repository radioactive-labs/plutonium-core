# frozen_string_literal: true

class CreatePlutoniumInteractionRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :plutonium_interaction_runs do |t|
      # STI discriminator — the author's Run subclass.
      t.string :type, null: false
      t.string :state, null: false, default: "pending" # pending | running | completed | failed

      # JSON payloads are jsonb, matching plutonium_wizard_sessions: Postgres
      # hosts get equality and GIN indexing (plain json has neither), and SQLite
      # hosts get the type via PLUTONIUM_SQLITE_TYPE_ALIASES, which aliases
      # jsonb -> json. Changing a column type post-release costs every host app a
      # migration, so pick the queryable one now.
      #
      # The dispatching interaction's validated inputs.
      t.public_send(:jsonb, :options, null: false, default: {})

      # Targets. target_type is a REAL column, not JSON: the index feature
      # queries "runs for this resource", which cannot be indexed out of a
      # JSON array. Ids are re-resolved through the policy scope at perform time.
      t.string :target_type
      t.public_send(:jsonb, :target_ids, null: false, default: [])

      # Who started it, and in which tenant — the two halves of the policy
      # context, which Plutonium authorizes on as (user, entity_scope).
      #
      # The initiator is ALWAYS required. There is no such thing as a run with
      # no user to authorize as, and a nullable initiator would inevitably come
      # to mean "unauthenticated/unscoped" — the fail-OPEN case.
      #
      # The scoped entity is nullable BY DESIGN: it is present only when the
      # run was launched in an entity-scoped portal, and nil for an un-scoped
      # one (same as plutonium_wizard_sessions.scope_type/scope_id). nil here
      # means "no tenant", NOT "tenant unknown". Code rebuilding the policy
      # context must handle nil explicitly rather than assume a tenant is
      # present — this schema offers no non-null guarantee to lean on.
      #
      # *_id is string-typed to accommodate bigint or uuid host primary keys,
      # matching plutonium_wizard_sessions.
      t.string :initiator_type, null: false
      t.string :initiator_id, null: false
      t.string :scoped_entity_type
      t.string :scoped_entity_id

      # Counts. Both nil for opaque (untargeted) work — the progress UI reads
      # nil as "indeterminate" rather than 0%.
      t.integer :progress_total
      t.integer :progress_done, null: false, default: 0

      # Per-target execution failures, appended as the run proceeds — hence an
      # array default. A run may fail on some targets and still complete.
      t.public_send(:jsonb, :errors_log, null: false, default: [])

      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps

      t.index [:target_type, :state], name: "idx_pu_runs_on_target_and_state"
      t.index [:initiator_type, :initiator_id], name: "idx_pu_runs_on_initiator"
      t.index [:scoped_entity_type, :scoped_entity_id], name: "idx_pu_runs_on_scoped_entity"
    end
  end
end
