class CreateCatalogCategories < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :catalog_categories do |t|
      t.string :name, null: false
      t.text :description, null: true
      t.belongs_to :parent, null: true, foreign_key: {to_table: :catalog_categories}

      t.timestamps
    end
  end
end
