# frozen_string_literal: true

class CreateBloggingPostMetadatas < ActiveRecord::Migration[7.1]
  def change
    create_table :blogging_post_metadata do |t|
      t.references :post, null: false, foreign_key: {to_table: :blogging_posts, on_delete: :cascade}
      t.string :seo_title
      t.text :seo_description
      t.string :canonical_url

      t.timestamps
    end
  end
end
