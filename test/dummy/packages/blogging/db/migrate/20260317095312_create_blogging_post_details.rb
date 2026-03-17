class CreateBloggingPostDetails < ActiveRecord::Migration[8.1]
  def change
    create_table :blogging_post_details do |t|
      t.string :seo_title, null: true
      t.text :seo_description, null: true
      t.string :canonical_url, null: true
      t.belongs_to :post, null: false, foreign_key: {to_table: :blogging_posts, on_delete: :cascade}, index: {unique: true}

      t.timestamps
    end
  end
end
