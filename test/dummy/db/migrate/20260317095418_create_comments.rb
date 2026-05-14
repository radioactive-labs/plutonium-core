class CreateComments < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :comments do |t|
      t.text :body, null: false
      t.belongs_to :commentable, polymorphic: true, null: false
      t.belongs_to :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
