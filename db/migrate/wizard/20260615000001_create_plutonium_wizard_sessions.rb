# frozen_string_literal: true

class CreatePlutoniumWizardSessions < ActiveRecord::Migration[7.2]
  def change
    json_type = (connection.adapter_name =~ /postgres/i) ? :jsonb : :json

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
      t.string :owner_type
      t.string :owner_id
      t.string :anchor_type
      t.string :anchor_id
      t.string :scope_type
      t.string :scope_id
      t.string :token

      t.public_send(json_type, :data, null: false, default: {})
      t.public_send(json_type, :tracked_records, null: false, default: {})

      t.datetime :expires_at
      t.datetime :completed_at
      t.timestamps

      t.index :instance_key, unique: true
      t.index [:status, :expires_at]
      t.index [:owner_type, :owner_id, :status]
      t.index [:scope_type, :scope_id, :status]
      t.index [:wizard, :anchor_type, :anchor_id, :status]
    end
  end
end
