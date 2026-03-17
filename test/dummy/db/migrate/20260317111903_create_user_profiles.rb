class CreateUserProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :user_profiles do |t|
      t.string :display_name, null: true
      t.text :bio, null: true
      t.string :timezone, null: true
      t.string :locale, null: true
      t.belongs_to :user, null: false, foreign_key: true, index: {unique: true}

      t.timestamps
    end
  end
end
