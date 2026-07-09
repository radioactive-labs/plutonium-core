class CreateTasks < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.string :status, null: false
      t.position  # Plutonium helper: decimal(16,8) tuned for fractional ordering

      t.index :status

      t.timestamps
    end
  end
end
