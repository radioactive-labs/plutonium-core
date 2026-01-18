class CreateBloggingPosts < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :blogging_posts do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.boolean :published

      t.timestamps
    end
  end
end
