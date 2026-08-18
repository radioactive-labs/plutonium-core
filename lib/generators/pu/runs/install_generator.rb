# frozen_string_literal: true

require_relative "../lib/plutonium_generators"

module Pu
  module Runs
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ResourceRegistration
      include PlutoniumGenerators::Concerns::ConfiguresRecurring

      source_root File.expand_path("templates", __dir__)

      desc(
        "Connect Plutonium::Interaction::Run to a portal, so its show page becomes routable\n\n" \
        "e.g. rails g pu:runs:install --dest=admin_portal"
      )

      class_option :schedule, type: :string, default: "every 15 minutes",
        desc: "Cron-style schedule for the ReapJob recurring task"

      def start
        @app_namespace = portal_option(:dest, prompt: "Select destination portal").camelize

        template "app/controllers/runs_controller.rb", controller_path

        register_resource_in_routes(routes_path, "Plutonium::Interaction::Run")

        schedule_reap_job
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      attr_reader :app_namespace

      # main_app is a valid destination (see PackageSelector#available_portals),
      # and it has neither a packages/ tree nor a Concerns::Controller to include.
      def main_app? = app_namespace == "MainApp"

      def controller_path
        return "app/controllers/runs_controller.rb" if main_app?

        "packages/#{package_namespace}/app/controllers/#{package_namespace}/runs_controller.rb"
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
          unless add_recurring_tasks(reap_job_task_yaml, marker: "reap_stalled_interaction_runs")
            log :skip, "ReapJob not scheduled (config/recurring.yml missing or already scheduled)"
          end
        else
          log :info, "solid_queue not found — schedule Plutonium::Interaction::Runs::ReapJob yourself (see docs)"
        end
      end

      def reap_job_task_yaml
        <<~YAML
          reap_stalled_interaction_runs:
            class: Plutonium::Interaction::Runs::ReapJob
            schedule: "#{options[:schedule]}"
        YAML
      end
    end
  end
end
