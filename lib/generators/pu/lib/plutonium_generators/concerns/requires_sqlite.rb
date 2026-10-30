# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    # For generators that only make sense on SQLite. Start with
    # `return unless sqlite_primary?`.
    module RequiresSqlite
      private

      def sqlite_primary?
        path = File.expand_path("config/database.yml", destination_root)
        return true unless File.exist?(path)

        yaml = ConfiguresDatabase::DatabaseYAML.for(path)
        return true if yaml.sqlite?

        log :skip, "#{self.class.name.demodulize} is SQLite only (primary database is #{yaml.default_adapter})"
        false
      end
    end
  end
end
