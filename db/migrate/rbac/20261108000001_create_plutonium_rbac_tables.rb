# frozen_string_literal: true

class CreatePlutoniumRbacTables < ActiveRecord::Migration[7.2]
  def change
    create_table :plutonium_rbac_roles do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.text :description
      # Permission keys from Plutonium::Rbac::Catalog. jsonb (aliased to json on
      # SQLite via PLUTONIUM_SQLITE_TYPE_ALIASES), matching the runs table.
      t.jsonb :permissions, null: false, default: []
      # Synced from code by plutonium:rbac:sync, read-only in the UI.
      t.boolean :system_role, null: false, default: false
      # nil = global/system role; set = a role a tenant created.
      t.string :entity_type
      t.string :entity_id
      t.timestamps

      t.index [:entity_type, :entity_id, :key], unique: true, name: "idx_pu_rbac_roles_on_entity_and_key"
      # NULLs are distinct in the index above, so global keys need their own.
      t.index :key, unique: true, where: "entity_type IS NULL AND entity_id IS NULL", name: "idx_pu_rbac_roles_on_global_key"
    end

    create_table :plutonium_rbac_role_assignments do |t|
      t.string :holder_type, null: false
      t.string :holder_id, null: false
      t.references :role, null: false, foreign_key: {to_table: :plutonium_rbac_roles}
      t.timestamps

      t.index [:holder_type, :holder_id, :role_id], unique: true, name: "idx_pu_rbac_assignments_on_holder_and_role"
    end
  end
end
