class CreateHrEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :hr_employees do |t|
      t.belongs_to :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :salary, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
