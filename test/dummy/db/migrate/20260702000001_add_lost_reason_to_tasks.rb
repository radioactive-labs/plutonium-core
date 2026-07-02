class AddLostReasonToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :lost_reason, :string
  end
end
