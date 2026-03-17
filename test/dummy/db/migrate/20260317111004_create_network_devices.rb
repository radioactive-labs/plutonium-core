class CreateNetworkDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :network_devices do |t|
      t.string :name, null: false
      t.uuid :external_id, null: false
      t.inet :ip_address, null: true
      t.cidr :network_range, null: true
      t.macaddr :mac_address, null: true
      t.jsonb :metadata, null: false
      t.ltree :location_path, null: true

      t.timestamps
    end
  end
end
