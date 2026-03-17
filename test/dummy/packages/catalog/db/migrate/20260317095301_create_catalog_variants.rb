class CreateCatalogVariants < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_variants do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.integer :price_cents, null: false, default: 0
      t.integer :stock_count, null: false, default: 0
      t.belongs_to :product, null: false, foreign_key: {to_table: :catalog_products}

      t.timestamps
    end
  end
end
