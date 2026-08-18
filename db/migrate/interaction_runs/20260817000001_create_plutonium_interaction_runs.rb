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
      t.jsonb :options, null: false, default: {}

      # Targets. target_type is a REAL column, not JSON: the index feature
      # queries "runs for this resource", which cannot be indexed out of a
      # JSON array. Ids are re-resolved through the policy scope at perform time.
      t.string :target_type
      t.jsonb :target_ids, null: false, default: []

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

      # The third half of the policy context: WHICH policy applied.
      #
      # Policy lookup in a controller passes the controller's own module nesting
      # as the namespace (ActionPolicy::Behaviours::Namespaced), which is how a
      # portal gets its own policy — StorefrontPortal::Blogging::PostPolicy
      # rather than Blogging::PostPolicy. A job has no controller and therefore
      # no namespace to derive, so without this the lookup falls back to the base
      # policy and every narrowing the portal applied is silently lost. Nullable
      # because a top-level dispatch legitimately has no namespace; nil here
      # means "top level", NOT "namespace unknown".
      #
      # Stored as the module's NAME (e.g. "StorefrontPortal"), constantized at
      # perform time — ActionPolicy.lookup requires a Module and raises on a
      # String.
      t.string :authorization_namespace

      # The policy actually resolved AT DISPATCH, e.g.
      # "StorefrontPortal::Blogging::PostPolicy". An ASSERTION, not an input: at
      # perform time the policy is resolved from the namespace above and then
      # checked against this. The namespace fixes today's lookup, but a policy
      # renamed, deleted or re-parented between enqueue and perform would resolve
      # to something else — the same silent widening, just moved later in time.
      # Recording what we expected turns that into a loud failure.
      #
      # NOT named `policy_class`: ActionPolicy's lookup chain probes
      # `record.policy_class` before inferring from the class name, so a column
      # of that name would make ActionPolicy.lookup(run) return this String
      # instead of a policy — breaking authorization of run records themselves.
      t.string :policy_class_name

      # The policy PREDICATE dispatch checked, e.g. "archive?".
      #
      # The class above says which policy; this says which question to ask it.
      # Without it a run re-checks only VISIBILITY (the relation scope) and not
      # PERMISSION: an initiator whose archive? flipped to false after enqueue
      # would still resolve every target and the work would proceed. Dispatch
      # derives this from the action name and checks it PER RECORD — see
      # Plutonium::Resource::Controllers::InteractiveActions#authorize_interactive_bulk_action!
      # — and perform must reproduce exactly that.
      #
      # Nullable ONLY because opaque (untargeted) work has no per-record
      # predicate to check. nil means "no per-target predicate", and for a
      # TARGETED run that is refused rather than read as "allow everything" —
      # the fail-open shape again.
      t.string :policy_action

      # Counts. Both nil for opaque (untargeted) work — the progress UI reads
      # nil as "indeterminate" rather than 0%.
      t.integer :progress_total
      t.integer :progress_done, null: false, default: 0

      # Per-target execution failures, appended as the run proceeds — hence an
      # array default. A run may fail on some targets and still complete.
      t.jsonb :errors_log, null: false, default: []

      t.datetime :started_at
      t.datetime :finished_at

      # Set only once a job actually picks the run up (Runs::Executor#claim!)
      # and bumped on every write that represents real progress thereafter —
      # NOT at create time, and not the same thing as updated_at, which bumps
      # on any write to the row. nil means "never picked up"; Runs::ReapJob
      # falls back to created_at for that case.
      t.datetime :last_activity_at

      # Target ids already dispositioned (succeeded or failed), so a run
      # resumed after an interruption can skip work it already did instead of
      # either replaying it or refusing to resume at all. See Runs::Executor.
      t.jsonb :handled_target_ids, null: false, default: []

      t.timestamps

      t.index [:target_type, :state], name: "idx_pu_runs_on_target_and_state"
      t.index [:initiator_type, :initiator_id], name: "idx_pu_runs_on_initiator"
      t.index [:scoped_entity_type, :scoped_entity_id], name: "idx_pu_runs_on_scoped_entity"
    end
  end
end
