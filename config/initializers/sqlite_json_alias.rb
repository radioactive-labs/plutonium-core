# Alias json to jsonb in SQLite migrations
ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.class_eval do
    def jsonb(*args, **options)
      json(*args, **options)
    end
  end
end 