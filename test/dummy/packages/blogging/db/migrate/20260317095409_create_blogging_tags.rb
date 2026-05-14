class CreateBloggingTags < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :blogging_tags do |t|
      t.string :name, null: false, index: {unique: true}
      t.string :color, null: false, default: "#6B7280"

      t.timestamps
    end
  end
end
