class AddFingerprintToKitchenSinks < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    add_column :kitchen_sinks, :fingerprint, :binary
  end
end
