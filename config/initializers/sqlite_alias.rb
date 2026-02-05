# Alias PostgreSQL-specific types for SQLite compatibility in migrations
#
# This allows using PostgreSQL-specific column types (jsonb, uuid, etc.) in migrations
# while developing with SQLite. The types are mapped to SQLite equivalents.

# Type mappings: PostgreSQL type -> SQLite equivalent
PLUTONIUM_SQLITE_TYPE_ALIASES = {
  jsonb: :json,
  hstore: :json,
  uuid: :string,
  inet: :string,
  cidr: :string,
  macaddr: :string,
  ltree: :string
}.freeze

ActiveSupport.on_load(:active_record) do
  next unless defined?(ActiveRecord::ConnectionAdapters::SQLite3Adapter)

  # Add methods to TableDefinition for create_table blocks
  ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.class_eval do
    PLUTONIUM_SQLITE_TYPE_ALIASES.each do |pg_type, sqlite_type|
      define_method(pg_type) do |*args, **options|
        send(sqlite_type, *args, **options)
      end
    end
  end

  # Override valid_type? to accept PostgreSQL types
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval do
    alias_method :original_valid_type?, :valid_type?

    def valid_type?(type)
      PLUTONIUM_SQLITE_TYPE_ALIASES.key?(type&.to_sym) || original_valid_type?(type)
    end
  end

  # Override type_to_sql to map PostgreSQL types to SQLite equivalents
  ActiveRecord::ConnectionAdapters::SQLite3Adapter.class_eval do
    alias_method :original_type_to_sql, :type_to_sql

    def type_to_sql(type, **)
      mapped_type = PLUTONIUM_SQLITE_TYPE_ALIASES[type&.to_sym] || type
      original_type_to_sql(mapped_type, **)
    end
  end
end
