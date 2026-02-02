# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class SolidCacheGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresSqlite

      source_root File.expand_path("templates", __dir__)

      desc "Set up Solid Cache with SQLite"

      class_option :database, type: :string, default: "cache",
        desc: "Database name for Solid Cache"
      class_option :dev_cache, type: :boolean, default: true,
        desc: "Enable caching in development"

      def start
        @db_name = options[:database]

        bundle "solid_cache"
        add_sqlite_database(@db_name)
        run_solid_cache_install
        prepare_database(@db_name)
        configure_cache_yml
        configure_application
        enable_dev_cache if options[:dev_cache]
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def run_solid_cache_install
        Bundler.with_unbundled_env do
          run "bin/rails generate solid_cache:install", env: {"DATABASE" => @db_name}
        end
        run "git checkout -- config/environments/production.rb 2>/dev/null || true"
      end

      def configure_cache_yml
        cache_file = "config/cache.yml"
        gsub_file cache_file, "database: <%= Rails.env %>", "database: #{@db_name}"
        gsub_file cache_file, "database: cache", "database: #{@db_name}"
      end

      def configure_application
        create_file "config/initializers/solid_cache.rb", <<~RUBY
          # frozen_string_literal: true

          Rails.application.configure do
            config.cache_store = :solid_cache_store
          end
        RUBY
      end

      def enable_dev_cache
        Bundler.with_unbundled_env do
          run "bin/rails dev:cache"
        end
      end
    end
  end
end
