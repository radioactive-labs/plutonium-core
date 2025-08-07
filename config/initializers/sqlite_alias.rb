# Alias json to jsonb in SQLite migrations
ActiveSupport.on_load(:active_record) do
  next unless ActiveRecord::Base.connection.adapter_name.downcase.include?("sqlite")

  ActiveRecord::ConnectionAdapters::SQLite3::TableDefinition.class_eval do
    def jsonb(*args, **options)
      json(*args, **options)
    end

    def uuid(*args, **options)
      string(*args, **options)
    end
  end
end
