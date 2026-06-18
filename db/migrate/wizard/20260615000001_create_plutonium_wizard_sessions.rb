# frozen_string_literal: true

class CreatePlutoniumWizardSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :plutonium_wizard_sessions do |t|
      t.string :wizard, null: false
      t.string :status, null: false, default: "in_progress" # in_progress | completing | completed
      t.string :current_step

      # Identity — a deterministic digest of (wizard, scope, anchor, principal).
      # A single unique column is required because nullable polymorphic columns
      # can't enforce the singleton rule (NULL != NULL in unique indexes).
      t.string :instance_key, null: false

      # Polymorphic refs — for querying/listing, NOT identity. *_id is string-typed
      # to accommodate bigint or uuid host primary keys.
      t.string :scope_type
      t.string :scope_id
      t.string :owner_type
      t.string :owner_id
      t.string :anchor_type
      t.string :anchor_id
      t.string :token

      # The portal (engine) this run was launched in, e.g. "OrgPortal::Engine" (the
      # main app's class name for a public mount). Records the run's portal context
      # so the "continue where you left off" listing only ever shows — and links —
      # runs that belong to the portal being viewed (two portals can share an entity
      # scope, so scope alone can't identify the portal).
      t.string :engine

      t.public_send(:jsonb, :data, null: false, default: {})
      t.public_send(:jsonb, :tracked_records, null: false, default: {})
      # Steps the user has actually visited+validated (§6.3 completeness). A
      # zero-validation step is only "complete" once it's been visited.
      t.public_send(:jsonb, :visited, null: false, default: [])

      t.datetime :expires_at
      t.datetime :completed_at
      t.timestamps

      t.index :instance_key, unique: true
      t.index [:status, :expires_at]
      t.index [:owner_type, :owner_id, :engine, :status]
      t.index [:scope_type, :scope_id, :status]
      t.index [:wizard, :anchor_type, :anchor_id, :status]
    end
  end
end
