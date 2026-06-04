# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class RailsPulseGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresSqlite
      include PlutoniumGenerators::Concerns::ConfiguresRecurring
      include PlutoniumGenerators::Concerns::MountsEngines

      source_root File.expand_path("templates", __dir__)

      desc "Set up Rails Pulse for performance monitoring with SQLite"

      class_option :database, type: :string, default: "rails_pulse",
        desc: "Database name for Rails Pulse (default: rails_pulse)"
      class_option :route, type: :string, default: "/manage/pulse",
        desc: "Route path for Rails Pulse dashboard"

      def start
        bundle "rails_pulse"

        if options[:database]
          setup_separate_database
        else
          run_rails_pulse_install
        end

        template "config/initializers/rails_pulse.rb", force: true
        mount_rails_pulse_engine
        setup_recurring_tasks if solid_queue_installed?
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def run_rails_pulse_install
        Bundler.with_unbundled_env do
          run "bin/rails generate rails_pulse:install"
        end
      end

      def setup_separate_database
        @db_name = options[:database]

        # Run install first - creates schema file and migration
        Bundler.with_unbundled_env do
          run "bin/rails generate rails_pulse:install --database=separate"
        end

        # Then add database config
        add_sqlite_database(@db_name, migrations_paths: "db/rails_pulse_migrate", schema_dump: false)

        # rails_pulse ships a callable schema lambda; load it idempotently
        # against the rails_pulse connection.
        Bundler.with_unbundled_env do
          run "bin/rails db:schema:load_rails_pulse"
        end
      end

      def mount_rails_pulse_engine
        mount_engine %(mount RailsPulse::Engine, at: "#{options[:route]}"), authenticated: true
      end

      def solid_queue_installed?
        gem_in_bundle?("solid_queue")
      end

      def setup_recurring_tasks
        add_recurring_tasks(rails_pulse_tasks_yaml, marker: "rails_pulse")
      end

      def rails_pulse_tasks_yaml
        <<~YAML
          rails_pulse_summary:
            class: RailsPulse::SummaryJob
            queue: default
            schedule: every hour at minute 5
            description: "Roll up Rails Pulse raw records into summary tables"

          rails_pulse_cleanup:
            class: RailsPulse::CleanupJob
            queue: default
            schedule: every day at 1am
            description: "Archive/purge old Rails Pulse data"
        YAML
      end
    end
  end
end
