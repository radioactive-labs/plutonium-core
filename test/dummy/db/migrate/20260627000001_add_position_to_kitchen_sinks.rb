class AddPositionToKitchenSinks < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    unless column_exists?(:kitchen_sinks, :position)
      change_table(:kitchen_sinks) { |t| t.position }  # decimal(16,8) via the Plutonium helper
    end
  end
end
