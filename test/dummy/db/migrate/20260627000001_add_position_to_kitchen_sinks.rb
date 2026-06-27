class AddPositionToKitchenSinks < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:kitchen_sinks, :position)
      change_table(:kitchen_sinks) { |t| t.position }  # decimal(16,8) via the Plutonium helper
    end
  end
end
