# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class SolidErrorsGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresSqlite
      include PlutoniumGenerators::Concerns::MountsEngines

      desc "Set up Solid Errors for error tracking with SQLite"

      class_option :database, type: :string, default: "errors",
        desc: "Database name for Solid Errors"
      class_option :route, type: :string, default: "/manage/errors",
        desc: "Route path for Solid Errors UI"

      def start
        @db_name = options[:database]

        bundle "solid_errors"
        add_sqlite_database(@db_name)
        run_solid_errors_install
        configure_application
        prepare_database(@db_name)
        mount_solid_errors_engine
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def run_solid_errors_install
        Bundler.with_unbundled_env do
          run "bin/rails generate solid_errors:install", env: {"DATABASE" => @db_name}
        end
        run "git checkout -- config/environments/production.rb 2>/dev/null || true"
      end

      def configure_application
        create_file "config/initializers/solid_errors.rb", <<~RUBY
          # frozen_string_literal: true

          Rails.application.configure do
            config.solid_errors.connects_to = {database: {writing: :#{@db_name}}}
            config.solid_errors.send_emails = ENV["SOLID_ERRORS_SEND_EMAILS"].present?
            config.solid_errors.email_from = ENV["SOLID_ERRORS_EMAIL_FROM"]
            config.solid_errors.email_to = ENV["SOLID_ERRORS_EMAIL_TO"]
            config.solid_errors.username = ENV.fetch("SOLID_ERRORS_USERNAME", nil)
            config.solid_errors.password = ENV.fetch("SOLID_ERRORS_PASSWORD", nil)
          end
        RUBY
      end

      def mount_solid_errors_engine
        mount_engine %(mount SolidErrors::Engine, at: "#{options[:route]}"), authenticated: true
      end
    end
  end
end
