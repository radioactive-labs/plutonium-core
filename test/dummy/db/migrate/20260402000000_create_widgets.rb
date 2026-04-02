class CreateWidgets < ActiveRecord::Migration[8.1]
  def change
    create_table :widgets do |t|
      t.string :name, null: false
      t.belongs_to :organization, null: false, foreign_key: {on_delete: :cascade}

      t.timestamps
    end
  end
end
