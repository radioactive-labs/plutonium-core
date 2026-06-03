class AddFeaturedToCatalogProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :catalog_products, :featured, :boolean, null: false, default: false
  end
end
