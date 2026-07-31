class CreateChores < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :chores do |t|
      t.string :title, null: false
      t.string :status, null: false, default: "todo"

      # An INTEGER position, not the decimal one `t.position` emits: acts_as_list
      # keeps a 1-based contiguous ranking and renumbers its neighbours on every
      # move, so there are no fractional midpoints to store. This column is the
      # whole point of the fixture — it proves Mode B works against storage the
      # framework itself would never choose.
      #
      # No presence validation accompanies it (see the model): acts_as_list
      # assigns the rank in a `before_create`, which runs AFTER validation, so
      # the column is populated by INSERT time but empty while validating.
      t.integer :position, null: false

      t.timestamps

      # Matches the acts_as_list scope — every query the gem issues is
      # "rows in my scope, ordered by position".
      t.index [:status, :position]
    end
  end
end
