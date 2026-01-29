class CreateDemoFeaturesCategories < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :demo_features_categories do |t|
      t.string :name, null: false
      t.text :description, null: true

      t.timestamps
    end
  end
end
