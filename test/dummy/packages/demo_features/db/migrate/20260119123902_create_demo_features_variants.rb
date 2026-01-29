class CreateDemoFeaturesVariants < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :demo_features_variants do |t|
      t.belongs_to :product, null: false, foreign_key: {to_table: :demo_features_products}
      t.string :name, null: false
      t.string :sku, null: false
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock_count, null: false
      t.boolean :active, null: false
      t.json :options, null: false

      t.timestamps
    end
  end
end
