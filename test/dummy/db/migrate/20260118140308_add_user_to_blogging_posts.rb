class AddUserToBloggingPosts < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    add_reference :blogging_posts, :user, null: false, foreign_key: true
  end
end
