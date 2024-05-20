# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Service
    class PostgresGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up postgres for project"

      def start
        template "database.yml", "config/database.yml", force: true
        bin_directory
        add_compose_env :POSTGRES_HOST, service
        add_compose_dependency service
        add_compose_service service, compose_config
        add_docker_dependency docker_deps
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def service
        :postgres
      end

      def compose_config
        <<~COMPOSE
          postgres:
            image: postgres:15 # postgres
            # postgres properties
            environment: # postgres
              POSTGRES_MULTIPLE_DATABASES: #{db_prefix}_development,#{db_prefix}_test # postgres
              POSTGRES_USER: postgres # postgres
              POSTGRES_PASSWORD: postgres # postgres
            volumes: # postgres
            - "./.volumes/postgres/data:/var/lib/postgresql/data" # postgres
            - "./bin/initdb.d:/docker-entrypoint-initdb.d" # postgres
        COMPOSE
      end

      def docker_deps
        <<~DEPS
          # Install packages needed for postgres
          RUN apt-get update -qq && \\
              apt-get install --no-install-recommends -y curl postgresql-client && \\
              rm -rf /var/lib/apt/lists /var/cache/apt/archives
        DEPS
      end

      def db_prefix
        Plutonium.application_name.underscore
      end
    end
  end
end
