# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class SolidQueueGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresSqlite
      include PlutoniumGenerators::Concerns::MountsEngines

      desc "Set up Solid Queue for background jobs with SQLite"

      class_option :database, type: :string, default: "queue",
        desc: "Database name for Solid Queue"
      class_option :route, type: :string, default: "/manage/jobs",
        desc: "Route path for Mission Control Jobs UI"
      class_option :skip_mission_control, type: :boolean, default: false,
        desc: "Skip Mission Control Jobs UI"

      def start
        @db_name = options[:database]

        bundle "solid_queue"
        add_sqlite_database(@db_name)
        run_solid_queue_install
        prepare_database(@db_name)
        configure_application
        create_jobs_script
        configure_procfile
        configure_kamal
        setup_mission_control unless options[:skip_mission_control]
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def run_solid_queue_install
        Bundler.with_unbundled_env do
          run "bin/rails generate solid_queue:install", env: {"DATABASE" => @db_name}
        end
        # Restore files modified by solid_queue:install
        run "git checkout -- config/environments/production.rb 2>/dev/null || true"
        run "git checkout -- config/puma.rb 2>/dev/null || true"
      end

      def configure_application
        create_file "config/initializers/solid_queue.rb", <<~RUBY
          # frozen_string_literal: true

          Rails.application.configure do
            config.active_job.queue_adapter = :solid_queue
            config.solid_queue.connects_to = {database: {writing: :#{@db_name}}}
            config.solid_queue.silence_polling = true
          end
        RUBY
      end

      def create_jobs_script
        jobs_script = "bin/jobs"
        return if File.exist?(File.expand_path(jobs_script, destination_root))

        create_file jobs_script, <<~BASH
          #!/usr/bin/env bash
          set -e
          exec bundle exec rake solid_queue:start
        BASH
        chmod jobs_script, 0o755
      end

      def configure_kamal
        deploy_file = "config/deploy.yml"
        return unless File.exist?(File.expand_path(deploy_file, destination_root))
        return if file_includes?(deploy_file, "job:")

        insert_into_file deploy_file, after: /^servers:.*\n/ do
          <<~YAML
            job:
              hosts:
                - <%= ENV['DEPLOY_HOST'] %>
              cmd: bin/jobs
          YAML
        end
      end

      def configure_procfile
        procfile = "Procfile.dev"
        return unless File.exist?(File.expand_path(procfile, destination_root))
        return if file_includes?(procfile, "jobs:")

        append_to_file procfile, "jobs: bin/jobs\n"
      end

      def setup_mission_control
        bundle "mission_control-jobs"
        configure_mission_control
        mount_engine %(mount MissionControl::Jobs::Engine, at: "#{options[:route]}"), authenticated: true
      end

      def configure_mission_control
        # Disable built-in HTTP Basic Auth - using route constraints instead
        environment "config.mission_control.jobs.http_basic_auth_enabled = false"
      end
    end
  end
end
