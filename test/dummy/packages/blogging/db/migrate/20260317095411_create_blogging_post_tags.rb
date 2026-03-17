class CreateBloggingPostTags < ActiveRecord::Migration[8.1]
  def change
    create_table :blogging_post_tags do |t|
      t.integer :position, null: false, default: 0
      t.belongs_to :post, null: false, foreign_key: {to_table: :blogging_posts, on_delete: :cascade}
      t.belongs_to :tag, null: false, foreign_key: {to_table: :blogging_tags, on_delete: :cascade}
      t.index [:post_id, :tag_id], unique: true

      t.timestamps
    end
  end
end
