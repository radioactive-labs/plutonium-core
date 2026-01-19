class CreateDemoFeaturesProducts < ActiveRecord::Migration[7.2]
  def change
    create_table :demo_features_products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.text :notes, null: false
      t.integer :stock_count, null: false
      t.float :weight, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :compare_at_price, precision: 10, scale: 2, null: false
      t.boolean :active, null: false
      t.boolean :featured, null: false
      t.boolean :taxable, null: false
      t.date :release_date, null: false
      t.date :discontinue_date, null: false
      t.datetime :last_restocked_at, null: false
      t.datetime :published_at, null: false
      t.time :available_from_time, null: false
      t.time :available_until_time, null: false
      t.json :metadata, null: false
      t.json :specifications, null: false
      t.integer :status, null: false
      t.belongs_to :category, null: true, foreign_key: {to_table: :demo_features_categories}

      t.timestamps
    end
  end
end
