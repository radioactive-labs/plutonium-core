class CreateDemoFeaturesProductTags < ActiveRecord::Migration[7.2]
  def change
    create_table :demo_features_product_tags do |t|
      t.belongs_to :product, null: false, foreign_key: {to_table: :demo_features_products}
      t.belongs_to :tag, null: false, foreign_key: {to_table: :demo_features_tags}
      t.integer :position, null: false

      t.timestamps
    end
  end
end
