# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class RailsPulseGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresSqlite
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
        add_sqlite_database(@db_name, migrations_paths: "db/rails_pulse_migrate")

        # Finally prepare the database (runs migration that loads schema)
        prepare_database(@db_name)
      end

      def mount_rails_pulse_engine
        mount_engine %(mount RailsPulse::Engine, at: "#{options[:route]}"), authenticated: true
      end

      def solid_queue_installed?
        gem_in_bundle?("solid_queue")
      end

      def setup_recurring_tasks
        recurring_file = "config/recurring.yml"
        return unless File.exist?(File.expand_path(recurring_file, destination_root))
        return if file_includes?(recurring_file, "rails_pulse")

        recurring_tasks = <<~YAML

          rails_pulse_summary:
            class: RailsPulse::SummaryJob
            schedule: "5 * * * *" # 5 minutes past every hour

          rails_pulse_cleanup:
            class: RailsPulse::CleanupJob
            schedule: "0 1 * * *" # Daily at 1am
        YAML

        append_to_file recurring_file, recurring_tasks
      end
    end
  end
end
