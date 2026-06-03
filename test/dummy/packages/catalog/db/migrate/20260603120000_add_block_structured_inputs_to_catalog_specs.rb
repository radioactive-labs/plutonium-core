class AddBlockStructuredInputsToCatalogSpecs < ActiveRecord::Migration[7.0]
  def change
    add_column :catalog_specs, :meta, :json, null: true   # single, inline block
    add_column :catalog_specs, :items, :json, null: true  # repeater, inline block
  end
end
