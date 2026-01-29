class CreateDemoFeaturesTags < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :demo_features_tags do |t|
      t.string :name, null: false
      t.string :color, null: false

      t.timestamps
    end
  end
end
