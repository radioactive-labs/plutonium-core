class CreateCatalogProducts < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_products do |t|
      t.string :name, null: false
      t.text :description, null: true
      t.integer :price_cents, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.json :metadata, null: true
      t.belongs_to :category, null: false, foreign_key: {to_table: :catalog_categories}
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :organization, null: false, foreign_key: true

      t.timestamps
    end
  end
end
