class AddPositionToCatalogVariants < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    unless column_exists?(:catalog_variants, :position)
      change_table(:catalog_variants) { |t| t.position }  # decimal(16,8) via the Plutonium helper
    end
  end
end
