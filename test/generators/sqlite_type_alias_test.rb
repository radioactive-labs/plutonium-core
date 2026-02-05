# frozen_string_literal: true

return unless ENV["GENERATOR_TESTS"]

require "test_helper"

class SqliteTypeAliasTest < ActiveSupport::TestCase
  # Test the SQLite type aliasing initializer

  test "PLUTONIUM_SQLITE_TYPE_ALIASES is defined" do
    assert defined?(PLUTONIUM_SQLITE_TYPE_ALIASES)
    assert PLUTONIUM_SQLITE_TYPE_ALIASES.is_a?(Hash)
    assert PLUTONIUM_SQLITE_TYPE_ALIASES.frozen?
  end

  test "maps jsonb to json" do
    assert_equal :json, PLUTONIUM_SQLITE_TYPE_ALIASES[:jsonb]
  end

  test "maps hstore to json" do
    assert_equal :json, PLUTONIUM_SQLITE_TYPE_ALIASES[:hstore]
  end

  test "maps uuid to string" do
    assert_equal :string, PLUTONIUM_SQLITE_TYPE_ALIASES[:uuid]
  end

  test "maps inet to string" do
    assert_equal :string, PLUTONIUM_SQLITE_TYPE_ALIASES[:inet]
  end

  test "maps cidr to string" do
    assert_equal :string, PLUTONIUM_SQLITE_TYPE_ALIASES[:cidr]
  end

  test "maps macaddr to string" do
    assert_equal :string, PLUTONIUM_SQLITE_TYPE_ALIASES[:macaddr]
  end

  test "maps ltree to string" do
    assert_equal :string, PLUTONIUM_SQLITE_TYPE_ALIASES[:ltree]
  end

  test "SQLite adapter accepts PostgreSQL types as valid" do
    skip "SQLite3Adapter not available" unless defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)

    adapter = ActiveRecord::Base.connection
    return unless adapter.is_a?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)

    PLUTONIUM_SQLITE_TYPE_ALIASES.each_key do |pg_type|
      assert adapter.valid_type?(pg_type), "SQLite adapter should accept #{pg_type} as valid type"
    end
  end

  test "SQLite adapter converts PostgreSQL types to SQLite equivalents" do
    skip "SQLite3Adapter not available" unless defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)

    adapter = ActiveRecord::Base.connection
    return unless adapter.is_a?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)

    # type_to_sql should map PostgreSQL types to SQLite equivalents
    assert_equal adapter.type_to_sql(:json), adapter.type_to_sql(:jsonb)
    assert_equal adapter.type_to_sql(:string), adapter.type_to_sql(:uuid)
    assert_equal adapter.type_to_sql(:string), adapter.type_to_sql(:inet)
  end

  test "TableDefinition has methods for PostgreSQL types" do
    skip "SQLite3 TableDefinition not available" unless defined?(ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition)

    table_def = ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.new(nil, "test")

    PLUTONIUM_SQLITE_TYPE_ALIASES.each_key do |pg_type|
      assert table_def.respond_to?(pg_type), "TableDefinition should respond to #{pg_type}"
    end
  end
end
