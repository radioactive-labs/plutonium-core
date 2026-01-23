class AddAuthorAndEditorToBloggingPosts < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    add_reference :blogging_posts, :author, null: true, foreign_key: {to_table: :users}
    add_reference :blogging_posts, :editor, null: true, foreign_key: {to_table: :users}
  end
end
