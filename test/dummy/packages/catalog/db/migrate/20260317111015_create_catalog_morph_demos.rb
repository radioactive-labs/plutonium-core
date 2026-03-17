class CreateCatalogMorphDemos < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_morph_demos do |t|
      t.integer :record_type, null: false
      t.string :name, null: false
      t.string :status, null: false
      t.string :priority, null: true
      t.datetime :scheduled_at, null: true
      t.text :description, null: true
      t.string :phone, null: true
      t.belongs_to :category, null: false, foreign_key: {to_table: :catalog_categories}

      t.timestamps
    end
  end
end
