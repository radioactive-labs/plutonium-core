# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Service
    class SidekiqGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up sidekiq for project"

      def start
        bundle "sidekiq"
        bundle "sidekiq-failures"
        directory "app"
        directory "config"

        in_root do
          insert_into_file "app/jobs/application_job.rb", "\n  sidekiq_options failures: :exhausted\n", before: /^end/
        end

        add_compose_env :REDIS_QUEUE_URL, "redis://redis-queue/0"
        add_required_env_vars :REDIS_QUEUE_URL
        add_compose_dependency redis_service
        add_compose_service service, sidekiq_compose_config
        add_compose_service redis_service, redis_compose_config
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def service
        :sidekiq
      end

      def redis_service
        :"redis-queue"
      end

      def sidekiq_compose_config
        <<~COMPOSE
          sidekiq:
            <<: *app # sidekiq
            command: /bin/sh -c "bundle && sidekiq" # sidekiq
            # sidekiq properties
        COMPOSE
      end

      def redis_compose_config
        <<~COMPOSE
          redis-queue:
            image: redis # redis-queue
            command: bash -c "redis-server --maxmemory-policy noeviction" # redis-queue
            # redis-queue properties
        COMPOSE
      end
    end
  end
end
