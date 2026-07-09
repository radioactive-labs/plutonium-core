class AddLostReasonToTasks < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    add_column :tasks, :lost_reason, :string
  end
end
