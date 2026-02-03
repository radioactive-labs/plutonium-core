# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class SolidCableGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresSqlite

      source_root File.expand_path("templates", __dir__)

      desc "Set up Solid Cable for Action Cable with SQLite"

      class_option :database, type: :string, default: "cable",
        desc: "Database name for Solid Cable"

      def start
        @db_name = options[:database]

        bundle "solid_cable"
        add_sqlite_database(@db_name)
        run_solid_cable_install
        configure_cable_yml
        prepare_database(@db_name)
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def run_solid_cable_install
        Bundler.with_unbundled_env do
          run "bin/rails generate solid_cable:install", env: {"DATABASE" => @db_name}
        end
        run "git checkout -- config/environments/production.rb 2>/dev/null || true"
      end

      def configure_cable_yml
        cable_file = "config/cable.yml"
        remove_file cable_file
        create_file cable_file, <<~YAML
          default: &default
            adapter: solid_cable
            polling_interval: 1.second
            keep_messages_around_for: 1.day
            connects_to:
              database:
                writing: #{@db_name}

          development:
            <<: *default
            silence_polling: true

          test:
            <<: *default

          production:
            <<: *default
            polling_interval: 0.1.seconds
        YAML
      end
    end
  end
end
