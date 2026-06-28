# frozen_string_literal: true

# Tables for the wizard-attachment demo/tests: a tiny model per backend, plus
# active_shrine's polymorphic attachments table (its install generator can't run
# here — it strips ActiveStorage, which the dummy also exercises).
class CreateAttachmentDemoTables < ActiveRecord::Migration[7.2]
  def change
    create_table :as_docs do |t|
      t.string :title
      t.timestamps
    end

    create_table :shrine_docs do |t|
      t.string :title
      t.timestamps
    end

    create_table :active_shrine_attachments do |t|
      t.belongs_to :record, polymorphic: true, null: true, index: true
      t.string :name, null: false, index: true
      t.string :type, null: false, default: "ActiveShrine::Attachment"
      t.json :file_data, null: false
      t.json :metadata, null: false, default: {}
      t.timestamps
    end
  end
end
