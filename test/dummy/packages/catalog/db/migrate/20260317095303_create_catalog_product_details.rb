class CreateCatalogProductDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_product_details do |t|
      t.text :specifications, null: true
      t.text :warranty_info, null: true
      t.belongs_to :product, null: false, foreign_key: {to_table: :catalog_products, on_delete: :cascade}, index: {unique: true}

      t.timestamps
    end
  end
end
