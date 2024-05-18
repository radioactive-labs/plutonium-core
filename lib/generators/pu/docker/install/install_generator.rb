# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Docker
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up docker for project"

      def start
        in_root do
          template "Dockerfile", force: true
          template "Dockerfile.dev", force: true
          template "docker-compose.yml", force: true
          proc_file :web, "env RUBY_DEBUG_OPEN=true bin/rails server -b '0.0.0.0'", env: :dev
          bin_directory
          gitignore ".volumes"
          dockerignore ".volumes"
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def ruby_version
        @ruby_version ||= File.read(".ruby-version").strip
      end
    end
  end
end
