class CreateCatalogSpecs < ActiveRecord::Migration[7.0]
  def change
    create_table :catalog_specs do |t|
      t.json :payload, null: true
      t.json :rows, null: true

      t.timestamps
    end
  end
end
