class AddTrackingIdToKitchenSinks < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    add_column :kitchen_sinks, :tracking_id, :string, default: "trk_123"
  end
end
