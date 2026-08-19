# frozen_string_literal: true

require_relative "../lib/plutonium_generators"

module Pu
  module AsyncInteractions
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ResourceRegistration
      include PlutoniumGenerators::Concerns::ConfiguresRecurring

      source_root File.expand_path("templates", __dir__)

      desc(
        "Enable async interactions, schedule the reaper, and connect the run resource to a portal\n\n" \
        "e.g. rails g pu:async_interactions:install --dest=admin_portal\n" \
        "     rails g pu:async_interactions:install --skip-portal   # app-wide only"
      )

      class_option :schedule, type: :string, default: "every 15 minutes",
        desc: "Cron-style schedule for the ReapJob recurring task"

      class_option :skip_portal, type: :boolean, default: false,
        desc: "Enable the subsystem without connecting the run resource to a portal"

      def start
        enable_async_interactions
        connect_portal unless options[:skip_portal]
        schedule_reap_job
        migration_reminder
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      attr_reader :app_namespace

      # The flag gates the MIGRATION as well as the behaviour: while it is off
      # the runs migration path is never registered, so plutonium_async_runs does
      # not exist and dispatching raises NotEnabledError.
      def enable_async_interactions
        configure_plutonium "config.async_interactions.enabled = true"
      end

      # The half that needs somewhere to route to.
      #
      # Skippable because a fresh app has no portals yet — only main_app, which
      # is the wrong home for a run resource in an app that is about to grow
      # portals. So an installer running before any portal exists (a project
      # template, say) can turn the subsystem on and leave connecting for later,
      # when there is a portal worth naming.
      def connect_portal
        @app_namespace = portal_option(:dest, prompt: "Select destination portal").camelize

        template "app/controllers/async_runs_controller.rb", controller_path
        register_resource_in_routes(routes_path, "Plutonium::Interaction::Async::Run")
      end

      # Not run for you: the migration path is registered from the initializer at
      # BOOT, and this process booted before the flag was written.
      def migration_reminder
        log :info, "async interactions enabled — run `rails db:migrate` to create plutonium_async_runs"
        return unless options[:skip_portal]

        log :info, "connect the run resource to a portal later: " \
                   "rails g pu:async_interactions:install --dest=<portal>"
      end

      # main_app is a valid destination (see PackageSelector#available_portals),
      # and it has neither a packages/ tree nor a Concerns::Controller to include.
      def main_app? = app_namespace == "MainApp"

      def controller_path
        return "app/controllers/async_runs_controller.rb" if main_app?

        "packages/#{package_namespace}/app/controllers/#{package_namespace}/async_runs_controller.rb"
      end

      def routes_path
        return "config/routes.rb" if main_app?

        "packages/#{package_namespace}/config/routes.rb"
      end

      def package_namespace
        app_namespace.underscore
      end

      # ReapJob is app-wide, not per-portal — idempotent via add_recurring_tasks,
      # so running this generator against a second portal is a harmless no-op here.
      def schedule_reap_job
        if gem_in_bundle?("solid_queue")
          unless add_recurring_tasks(reap_job_task_yaml, marker: "reap_stalled_async_runs")
            log :skip, "ReapJob not scheduled (config/recurring.yml missing or already scheduled)"
          end
        else
          log :info, "solid_queue not found — schedule Plutonium::Interaction::Async::ReapJob yourself (see docs)"
        end
      end

      def reap_job_task_yaml
        <<~YAML
          reap_stalled_async_runs:
            class: Plutonium::Interaction::Async::ReapJob
            schedule: "#{options[:schedule]}"
        YAML
      end
    end
  end
end
