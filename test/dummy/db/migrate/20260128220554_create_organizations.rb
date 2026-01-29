class CreateOrganizations < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :organizations do |t|
      t.string :name, null: false

      t.timestamps
    end
    add_index :organizations, :name, unique: true
  end
end
