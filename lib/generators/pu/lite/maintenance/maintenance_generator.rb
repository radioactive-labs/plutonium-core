# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class MaintenanceGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresRecurring

      source_root File.expand_path("templates", __dir__)

      desc "Install a nightly SqliteMaintenanceJob (PRAGMA optimize + VACUUM)"

      class_option :schedule, type: :string, default: "every day at 3:30am",
        desc: "Cron-style schedule for the maintenance job"

      def start
        template "app/jobs/sqlite_maintenance_job.rb"

        if gem_in_bundle?("solid_queue")
          unless add_recurring_tasks(maintenance_task_yaml, marker: "sqlite_maintenance")
            log :skip, "could not schedule (config/recurring.yml missing or already scheduled)"
          end
        else
          log :info, "solid_queue not found — job installed but not scheduled. Add a 'sqlite_maintenance' entry to your scheduler."
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def maintenance_task_yaml
        <<~YAML
          sqlite_maintenance:
            class: SqliteMaintenanceJob
            queue: default
            schedule: "#{options[:schedule]}"
            description: "VACUUM + PRAGMA optimize across SQLite databases"
        YAML
      end
    end
  end
end
