# frozen_string_literal: true

require "sequel/core"

module Plutonium
  module Auth
    # Provides runtime detection of the database adapter for Sequel configuration.
    # This module dynamically detects the ActiveRecord adapter and returns the
    # corresponding Sequel adapter, allowing users to change their database
    # without needing to regenerate rodauth files.
    module SequelAdapter
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
        def db
          if RUBY_ENGINE == "jruby"
            Sequel.connect("jdbc:#{sequel_adapter}://", extensions: :activerecord_connection, keep_reference: false)
          else
            Sequel.public_send(sequel_adapter, extensions: :activerecord_connection, keep_reference: false)
          end
        end

        # Returns the Sequel adapter name based on the current ActiveRecord adapter.
        #
        # @return [String] the Sequel adapter name
        def sequel_adapter
          SEQUEL_ADAPTERS[activerecord_adapter] || activerecord_adapter
        end

        private

        # Returns the current ActiveRecord adapter name.
        #
        # @return [String] the ActiveRecord adapter name
        def activerecord_adapter
          if ActiveRecord::Base.respond_to?(:connection_db_config)
            ActiveRecord::Base.connection_db_config.adapter
          else
            ActiveRecord::Base.connection_config.fetch(:adapter)
          end
        end
      end
    end
  end
end
