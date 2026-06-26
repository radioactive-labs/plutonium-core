class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.string :status, null: false
      t.decimal :position, precision: 16, scale: 8

      t.index :status

      t.timestamps
    end
  end
end
