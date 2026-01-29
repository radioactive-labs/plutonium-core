# Alias json to jsonb in SQLite migrations

ActiveSupport.on_load(:active_record) do
  if defined?(ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition)
    ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.class_eval do
      def jsonb(*args, **options)
        json(*args, **options)
      end

      def uuid(*args, **options)
        string(*args, **options)
      end
    end
  end
end
