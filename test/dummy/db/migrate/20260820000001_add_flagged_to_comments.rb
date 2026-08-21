class AddFlaggedToComments < ActiveRecord::Migration[7.0]
  def change
    add_column :comments, :flagged, :boolean, null: false, default: false
  end
end
