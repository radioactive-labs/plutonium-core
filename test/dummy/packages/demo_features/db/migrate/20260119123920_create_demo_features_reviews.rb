class CreateDemoFeaturesReviews < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :demo_features_reviews do |t|
      t.belongs_to :product, null: false, foreign_key: {to_table: :demo_features_products}
      t.belongs_to :user, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body, null: false
      t.integer :rating, null: false
      t.boolean :verified, null: false
      t.datetime :approved_at, null: false

      t.timestamps
    end
  end
end
