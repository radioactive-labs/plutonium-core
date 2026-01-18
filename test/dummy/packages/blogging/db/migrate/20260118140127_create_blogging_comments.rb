class CreateBloggingComments < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :blogging_comments do |t|
      t.text :body, null: false
      t.belongs_to :user, null: false, foreign_key: true
      t.belongs_to :post, null: false, foreign_key: {:to_table=>:blogging_posts}

      t.timestamps
    end
  end
end
