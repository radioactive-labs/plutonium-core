class AddShowcaseFieldsToKitchenSinks < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    add_column :kitchen_sinks, :rating, :integer
    add_column :kitchen_sinks, :completion, :integer
    add_column :kitchen_sinks, :cycle_seconds, :integer
    add_column :kitchen_sinks, :manual_bytes, :integer
    add_column :kitchen_sinks, :last_cleaned_at, :datetime
  end
end
