class CreateOrganizationUsers < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :organization_users do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :role, null: false, default: 0  # Member by default

      t.timestamps
    end
    add_index :organization_users, [:organization_id, :user_id], unique: true
  end
end
