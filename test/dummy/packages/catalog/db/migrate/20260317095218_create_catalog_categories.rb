class CreateCatalogCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_categories do |t|
      t.string :name, null: false
      t.text :description, null: true
      t.belongs_to :parent, null: true, foreign_key: {to_table: :catalog_categories}

      t.timestamps
    end
  end
end
