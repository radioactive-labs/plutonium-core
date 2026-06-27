class AddPositionToKitchenSinks < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:kitchen_sinks, :position)
      add_column :kitchen_sinks, :position, :decimal, precision: 16, scale: 8
    end
  end
end
