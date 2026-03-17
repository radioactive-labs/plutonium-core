class CreateBloggingPosts < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :blogging_posts do |t|
      t.string :type
      t.string :title, null: false
      t.text :body, null: false
      t.integer :status, null: false, default: 0
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :author, null: true, foreign_key: {to_table: :users}
      t.belongs_to :editor, null: true, foreign_key: {to_table: :users}
      t.belongs_to :organization, null: false, foreign_key: true

      t.timestamps
    end
  end
end
