# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up the base requirements for Plutonium"

      def start
        setup_packages
        setup_app
        eject_views
        setup_active_record
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def setup_packages
        copy_file "config/packages.rb"
        create_file "packages/.keep"
        insert_into_file "config/application.rb", "\nrequire_relative \"packages\"\n", after: /Bundler\.require.*\n/
      end

      def setup_app
        directory "config"
        directory "app"
      end

      def eject_views
        invoke "pu:eject:layout", [], dest: "main_app",
          force: options[:force],
          skip: options[:skip]
      end

      def setup_active_record
        inject_into_class(
          "app/models/application_record.rb",
          "ApplicationRecord",
          "  include Plutonium::Resource::Record\n\n"
        )
      end
    end
  end
end
