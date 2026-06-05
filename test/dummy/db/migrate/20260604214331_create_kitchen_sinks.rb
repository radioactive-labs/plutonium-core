class CreateKitchenSinks < ActiveRecord::Migration[8.1]
  def change
    create_table :kitchen_sinks do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true

      t.string :name, null: false

      # Scalar inputs
      t.string :email_address, default: "user@example.com"
      t.string :secret
      t.string :website, default: "https://example.com"
      t.string :favorite_color, default: "#3b82f6"
      t.integer :age, default: 42
      t.decimal :balance, precision: 10, scale: 2, default: "1999.95"
      t.text :description
      t.text :bio

      # Booleans
      t.boolean :active, null: false, default: true
      t.boolean :featured, null: false, default: false

      # Enum-backed (see KitchenSink#enum)
      t.integer :status, null: false, default: 0   # active
      t.integer :plan, null: false, default: 1     # pro
      t.integer :tier, null: false, default: 1     # b

      # Date / time
      t.date :birthday
      t.datetime :meeting_at
      t.string :alarm_time, default: "09:30"

      # Misc
      t.string :phone, default: "+14155552671"
      t.json :config, default: {theme: "dark", beta: true}
      t.json :prefs, default: {newsletter: "weekly"}
      t.integer :balance_cents, default: 123456
      t.string :secret_token, default: "s3cr3t"

      t.timestamps

      t.index :status
    end
  end
end
