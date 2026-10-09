class CreateTaggingKitchenSink < ActiveRecord::Migration[[Rails::VERSION::MAJOR, Rails::VERSION::MINOR].join(".").to_f]
  def change
    create_table :kitchen_sink_tags, id: :bigint do |t|
      t.column :organization_id, :bigint, null: false # Change to :uuid if you are using UUIDs
      t.string :name, null: false
      t.timestamp :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.timestamp :updated_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end

    create_table :kitchen_sink_taggings do |t|
      t.column :taggable_id, :bigint, null: false, index: true # Change to :uuid if you are using UUIDs
      t.column :tag_id, :bigint, null: false, index: true
      t.string :context, null: false
      t.timestamp :created_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.timestamp :updated_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
    end

    add_index :kitchen_sink_tags, %i[organization_id name], unique: true
    add_index :kitchen_sink_taggings, %i[taggable_id tag_id], unique: true
    add_foreign_key :kitchen_sink_taggings, :kitchen_sink_tags, column: :tag_id
    add_foreign_key :kitchen_sink_taggings, :kitchen_sinks, column: :taggable_id
  end
end
