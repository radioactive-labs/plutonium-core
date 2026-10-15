# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class MaintenanceGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresRecurring

      source_root File.expand_path("templates", __dir__)

      desc "Install a nightly SqliteMaintenanceJob (PRAGMA optimize + VACUUM) and schedule SolidQueue finished-job cleanup"

      class_option :schedule, type: :string, default: "every day at 3:30am",
        desc: "Cron-style schedule for the maintenance job"
      class_option :clear_finished_schedule, type: :string, default: "every hour at minute 12",
        desc: "Schedule for clearing finished SolidQueue jobs"

      def start
        template "app/jobs/sqlite_maintenance_job.rb"

        if gem_in_bundle?("solid_queue")
          unless add_recurring_tasks(maintenance_task_yaml, marker: "sqlite_maintenance")
            log :skip, "could not schedule (config/recurring.yml missing or already scheduled)"
          end
          # Rails 8 apps ship this task already; the marker matches its command
          # so we never schedule it twice under a different key.
          unless add_recurring_tasks(clear_finished_jobs_task_yaml, marker: "clear_finished_in_batches")
            log :skip, "finished-job cleanup not scheduled (config/recurring.yml missing or already scheduled)"
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

      # SolidQueue keeps finished jobs (preserve_finished_jobs defaults to true)
      # and only deletes them when asked. Without this the queue database grows
      # without bound.
      def clear_finished_jobs_task_yaml
        <<~YAML
          clear_solid_queue_finished_jobs:
            command: "SolidQueue::Job.clear_finished_in_batches(sleep_between_batches: 0.3)"
            schedule: "#{options[:clear_finished_schedule]}"
            description: "Delete SolidQueue jobs finished longer ago than clear_finished_jobs_after"
        YAML
      end
    end
  end
end
