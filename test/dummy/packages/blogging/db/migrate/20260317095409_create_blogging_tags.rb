class CreateBloggingTags < ActiveRecord::Migration[8.1]
  def change
    create_table :blogging_tags do |t|
      t.string :name, null: false, index: {unique: true}
      t.string :color, null: false, default: "#6B7280"

      t.timestamps
    end
  end
end
