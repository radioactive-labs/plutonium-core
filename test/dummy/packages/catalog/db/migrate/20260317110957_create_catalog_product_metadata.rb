class CreateCatalogProductMetadata < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_product_metadata do |t|
      t.string :meta_title, null: true
      t.text :meta_description, null: true
      t.string :meta_keywords, null: true
      t.string :og_image_url, null: true
      t.belongs_to :product, null: false, foreign_key: {to_table: :catalog_products, on_delete: :cascade}, index: {unique: true}

      t.timestamps
    end
  end
end
