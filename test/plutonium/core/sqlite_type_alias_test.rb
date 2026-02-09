# frozen_string_literal: true

require "test_helper"
require "open3"

class Plutonium::Core::SqliteTypeAliasTest < ActiveSupport::TestCase
  # Test the SQLite type aliasing that allows using PostgreSQL-specific column
  # types in migrations while developing with SQLite.

  def setup
    skip "SQLite3Adapter not available" unless sqlite_adapter?
  end

  def teardown
    drop_test_table if sqlite_adapter?
  end

  # Type constant tests

  test "PLUTONIUM_SQLITE_TYPE_ALIASES is defined and frozen" do
    assert defined?(PLUTONIUM_SQLITE_TYPE_ALIASES)
    assert_kind_of Hash, PLUTONIUM_SQLITE_TYPE_ALIASES
    assert_predicate PLUTONIUM_SQLITE_TYPE_ALIASES, :frozen?
  end

  test "maps PostgreSQL types to SQLite equivalents" do
    expected = {
      jsonb: :json,
      hstore: :json,
      uuid: :string,
      inet: :string,
      cidr: :string,
      macaddr: :string,
      ltree: :string
    }

    expected.each do |pg_type, sqlite_type|
      assert_equal sqlite_type, PLUTONIUM_SQLITE_TYPE_ALIASES[pg_type],
        "Expected #{pg_type} to map to #{sqlite_type}"
    end
  end

  # Adapter integration tests

  test "SQLite adapter accepts PostgreSQL types as valid" do
    PLUTONIUM_SQLITE_TYPE_ALIASES.each_key do |pg_type|
      assert adapter.valid_type?(pg_type), "SQLite adapter should accept #{pg_type} as valid type"
    end
  end

  test "SQLite adapter converts PostgreSQL types to SQLite equivalents in type_to_sql" do
    assert_equal adapter.type_to_sql(:json), adapter.type_to_sql(:jsonb)
    assert_equal adapter.type_to_sql(:json), adapter.type_to_sql(:hstore)
    assert_equal adapter.type_to_sql(:string), adapter.type_to_sql(:uuid)
    assert_equal adapter.type_to_sql(:string), adapter.type_to_sql(:inet)
    assert_equal adapter.type_to_sql(:string), adapter.type_to_sql(:cidr)
    assert_equal adapter.type_to_sql(:string), adapter.type_to_sql(:macaddr)
    assert_equal adapter.type_to_sql(:string), adapter.type_to_sql(:ltree)
  end

  # Migration tests - test that we can actually create tables with PostgreSQL types

  test "can create table with jsonb column" do
    create_test_table do |t|
      t.jsonb :data
    end

    assert adapter.column_exists?(:pu_type_alias_test, :data)
  end

  test "can create table with uuid column" do
    create_test_table do |t|
      t.uuid :external_id
    end

    assert adapter.column_exists?(:pu_type_alias_test, :external_id)
  end

  test "can create table with inet column" do
    create_test_table do |t|
      t.inet :ip_address
    end

    assert adapter.column_exists?(:pu_type_alias_test, :ip_address)
  end

  test "can create table with all PostgreSQL types" do
    create_test_table do |t|
      t.jsonb :json_data
      t.hstore :key_value_data
      t.uuid :external_id
      t.inet :ip_address
      t.cidr :network
      t.macaddr :mac
      t.ltree :path
    end

    %i[json_data key_value_data external_id ip_address network mac path].each do |column|
      assert adapter.column_exists?(:pu_type_alias_test, column),
        "Expected column #{column} to exist"
    end
  end

  test "can add PostgreSQL type column to existing table" do
    create_test_table do |t|
      t.string :name
    end

    adapter.add_column :pu_type_alias_test, :metadata, :jsonb
    adapter.add_column :pu_type_alias_test, :external_id, :uuid

    assert adapter.column_exists?(:pu_type_alias_test, :metadata)
    assert adapter.column_exists?(:pu_type_alias_test, :external_id)
  end

  # Change column tests

  test "can change column to jsonb type" do
    create_test_table do |t|
      t.text :data
    end

    adapter.change_column :pu_type_alias_test, :data, :jsonb

    assert adapter.column_exists?(:pu_type_alias_test, :data)
  end

  test "can change column to uuid type" do
    create_test_table do |t|
      t.string :external_id
    end

    adapter.change_column :pu_type_alias_test, :external_id, :uuid

    assert adapter.column_exists?(:pu_type_alias_test, :external_id)
  end

  test "can change column to inet type" do
    create_test_table do |t|
      t.string :ip_address
    end

    adapter.change_column :pu_type_alias_test, :ip_address, :inet

    assert adapter.column_exists?(:pu_type_alias_test, :ip_address)
  end

  test "can change columns to all PostgreSQL types" do
    create_test_table do |t|
      t.text :json_data
      t.text :key_value_data
      t.string :external_id
      t.string :ip_address
      t.string :network
      t.string :mac
      t.string :path
    end

    adapter.change_column :pu_type_alias_test, :json_data, :jsonb
    adapter.change_column :pu_type_alias_test, :key_value_data, :hstore
    adapter.change_column :pu_type_alias_test, :external_id, :uuid
    adapter.change_column :pu_type_alias_test, :ip_address, :inet
    adapter.change_column :pu_type_alias_test, :network, :cidr
    adapter.change_column :pu_type_alias_test, :mac, :macaddr
    adapter.change_column :pu_type_alias_test, :path, :ltree

    %i[json_data key_value_data external_id ip_address network mac path].each do |column|
      assert adapter.column_exists?(:pu_type_alias_test, column),
        "Expected column #{column} to exist after change_column"
    end
  end

  # Generator tests - verify PostgreSQL types work in scaffold generator

  test "scaffold generator accepts PostgreSQL types" do
    # Run the generator with PostgreSQL types
    generator_output = run_generator(
      "TestNetworkDevice",
      "name:string",
      "external_id:uuid",
      "ip_address:inet?",
      "metadata:jsonb"
    )

    assert generator_output[:success], "Generator should succeed: #{generator_output[:stderr]}"

    # Verify migration file was created with PostgreSQL types
    migration_file = find_migration("create_test_network_devices")
    assert migration_file, "Migration file should be created"

    migration_content = File.read(migration_file)
    assert_match(/t\.uuid :external_id/, migration_content)
    assert_match(/t\.inet :ip_address/, migration_content)
    assert_match(/t\.jsonb :metadata/, migration_content)
  ensure
    cleanup_generated_files("test_network_device")
  end

  # Model integration tests using NetworkDevice resource

  test "NetworkDevice model can create records with PostgreSQL types" do
    device = NetworkDevice.create!(
      name: "Router 1",
      external_id: SecureRandom.uuid,
      ip_address: "192.168.1.1",
      network_range: "192.168.1.0/24",
      mac_address: "00:1A:2B:3C:4D:5E",
      metadata: {vendor: "Cisco", model: "ISR4331"},
      location_path: "us.east.datacenter1.rack5"
    )

    assert device.persisted?
    assert_equal "Router 1", device.name
    assert_equal "192.168.1.1", device.ip_address
    assert_equal "192.168.1.0/24", device.network_range
    assert_equal "00:1A:2B:3C:4D:5E", device.mac_address
    assert_equal({"vendor" => "Cisco", "model" => "ISR4331"}, device.metadata)
    assert_equal "us.east.datacenter1.rack5", device.location_path
  ensure
    NetworkDevice.delete_all
  end

  test "NetworkDevice model can read and update records with PostgreSQL types" do
    device = NetworkDevice.create!(
      name: "Switch 1",
      external_id: SecureRandom.uuid,
      ip_address: "10.0.0.1",
      metadata: {ports: 48}
    )

    device.reload
    assert_equal "10.0.0.1", device.ip_address
    assert_equal({"ports" => 48}, device.metadata)

    device.update!(ip_address: "10.0.0.2", metadata: {ports: 48, speed: "1Gbps"})
    device.reload

    assert_equal "10.0.0.2", device.ip_address
    assert_equal({"ports" => 48, "speed" => "1Gbps"}, device.metadata)
  ensure
    NetworkDevice.delete_all
  end

  private

  def sqlite_adapter?
    defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter) &&
      adapter.is_a?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)
  end

  def adapter
    ActiveRecord::Base.connection
  end

  def create_test_table(&block)
    drop_test_table
    adapter.create_table(:pu_type_alias_test, &block)
  end

  def drop_test_table
    adapter.drop_table(:pu_type_alias_test) if adapter.table_exists?(:pu_type_alias_test)
  end

  def run_generator(name, *attributes)
    args = [name, *attributes, "--dest=main_app", "--no-interactive"].map { |a| "'#{a}'" }.join(" ")
    stdout, stderr, status = Open3.capture3(
      "bundle exec rails g pu:res:scaffold #{args}",
      chdir: Rails.root
    )
    {success: status.success?, stdout: stdout, stderr: stderr}
  end

  def find_migration(name_pattern)
    Dir.glob(Rails.root.join("db/migrate/*_#{name_pattern}.rb")).first
  end

  def cleanup_generated_files(resource_name)
    table_name = resource_name.pluralize

    # Remove generated files
    files_to_remove = [
      Rails.root.join("app/models/#{resource_name}.rb"),
      Rails.root.join("app/controllers/#{table_name}_controller.rb"),
      Rails.root.join("app/policies/#{resource_name}_policy.rb"),
      Rails.root.join("app/definitions/#{resource_name}_definition.rb"),
      *Dir.glob(Rails.root.join("db/migrate/*_create_#{table_name}.rb"))
    ]

    files_to_remove.each { |f| FileUtils.rm_f(f) }

    # Drop table if it exists
    adapter.drop_table(table_name.to_sym) if adapter.table_exists?(table_name.to_sym)
  end
end
