class CreateDemoFeaturesCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :demo_features_categories do |t|
      t.string :name, null: false
      t.text :description, null: true

      t.timestamps
    end
  end
end
