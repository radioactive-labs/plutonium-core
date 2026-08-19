# frozen_string_literal: true

require_relative "../lib/plutonium_generators"

module Pu
  module Wizards
    # Turns the wizard subsystem on.
    #
    # App-wide, and takes no portal — unlike pu:async_interactions:install,
    # which connects a RESOURCE and therefore needs somewhere to route it. A
    # wizard mounts itself wherever it is declared (the `wizard` macro on a
    # definition, or `register_wizard` in a portal or the main app), so there is
    # nothing here to attach to a portal.
    #
    # What it does is the two steps every wizard app needs and neither of which
    # a wizard can do for itself: flip the flag that registers the migration
    # path, and schedule the sweep.
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresRecurring

      desc(
        "Enable wizards and schedule the abandonment sweep\n\n" \
        "e.g. rails g pu:wizards:install"
      )

      class_option :schedule, type: :string, default: "every 15 minutes",
        desc: "Cron-style schedule for the SweepJob recurring task"

      def start
        enable_wizards
        schedule_sweep_job
        migration_reminder
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      # The flag gates the MIGRATION as well as the behaviour: while it is off
      # the wizard migration path is never registered, so
      # plutonium_wizard_sessions does not exist and nothing works.
      def enable_wizards
        configure_plutonium "config.wizards.enabled = true"
      end

      # Idempotent via add_recurring_tasks, so re-running this is a no-op.
      #
      # Scheduling matters more than it looks. For an +execute+-only wizard an
      # unscheduled sweep just leaves stale session rows, which is untidy; for an
      # +on_submit+ wizard it is the only thing that cleans up the partial domain
      # records an abandoned run left behind.
      def schedule_sweep_job
        if gem_in_bundle?("solid_queue")
          unless add_recurring_tasks(sweep_job_task_yaml, marker: "sweep_abandoned_wizards")
            log :skip, "SweepJob not scheduled (config/recurring.yml missing or already scheduled)"
          end
        else
          log :info, "solid_queue not found — schedule Plutonium::Wizard::SweepJob yourself (see docs)"
        end
      end

      def sweep_job_task_yaml
        <<~YAML
          sweep_abandoned_wizards:
            class: Plutonium::Wizard::SweepJob
            schedule: "#{options[:schedule]}"
        YAML
      end

      # Not run for you: the migration path is registered from the initializer at
      # BOOT, and this process booted before the flag was written.
      def migration_reminder
        log :info, "wizards enabled — run `rails db:migrate` to create plutonium_wizard_sessions"
      end
    end
  end
end
