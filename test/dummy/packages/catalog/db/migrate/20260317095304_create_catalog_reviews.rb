class CreateCatalogReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_reviews do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.integer :rating, null: false
      t.boolean :verified, null: false, default: false
      t.belongs_to :product, null: false, foreign_key: {to_table: :catalog_products}
      t.belongs_to :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
