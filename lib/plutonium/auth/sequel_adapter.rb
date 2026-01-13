# frozen_string_literal: true

require "sequel/core"

module Plutonium
  module Auth
    # Provides runtime detection of the database adapter for Sequel configuration.
    # This module dynamically detects the ActiveRecord adapter and returns the
    # corresponding Sequel adapter, allowing users to change their database
    # without needing to regenerate rodauth files.
    module SequelAdapter
      # Maps ActiveRecord adapter names to their corresponding Sequel adapter names.
      # JRuby uses JDBC adapters which have different naming conventions.
      SEQUEL_ADAPTERS = {
        "postgresql" => RUBY_ENGINE == "jruby" ? "postgresql" : "postgres",
        "mysql2" => RUBY_ENGINE == "jruby" ? "mysql" : "mysql2",
        "sqlite3" => "sqlite",
        "oracle_enhanced" => "oracle",
        "sqlserver" => RUBY_ENGINE == "jruby" ? "mssql" : "tinytds"
      }.freeze

      class << self
        # Returns a Sequel database connection that reuses ActiveRecord's connection.
        # Automatically detects the correct adapter based on the current ActiveRecord config.
        #
        # @return [Sequel::Database] configured Sequel database connection
        # @raise [RuntimeError] if the Sequel adapter initialization fails
        def db
          adapter = sequel_adapter
          begin
            if RUBY_ENGINE == "jruby"
              Sequel.connect("jdbc:#{adapter}://", extensions: :activerecord_connection, keep_reference: false)
            else
              Sequel.public_send(adapter, extensions: :activerecord_connection, keep_reference: false)
            end
          rescue => e
            raise "Failed to initialize Sequel with adapter '#{adapter}'. " \
                  "Please ensure your database configuration is correct and the required " \
                  "database gems are installed. Original error: #{e.message}"
          end
        end

        # Returns the Sequel adapter name based on the current ActiveRecord adapter.
        # If the ActiveRecord adapter is not in the SEQUEL_ADAPTERS mapping, the
        # ActiveRecord adapter name is returned as-is, which may work for adapters
        # where the names match between ActiveRecord and Sequel.
        #
        # @return [String] the Sequel adapter name
        def sequel_adapter
          SEQUEL_ADAPTERS[activerecord_adapter] || activerecord_adapter
        end

        private

        # Returns the current ActiveRecord adapter name.
        #
        # @return [String] the ActiveRecord adapter name
        # @raise [RuntimeError] if the ActiveRecord adapter cannot be determined
        def activerecord_adapter
          adapter = if ActiveRecord::Base.respond_to?(:connection_db_config)
            ActiveRecord::Base.connection_db_config&.adapter
          else
            ActiveRecord::Base.connection_config&.fetch(:adapter, nil)
          end

          unless adapter
            raise "Unable to determine the ActiveRecord database adapter. " \
                  "Please ensure ActiveRecord is properly configured with a database connection."
          end

          adapter
        end
      end
    end
  end
end
