# frozen_string_literal: true

require "plutonium_generators"

module Pu
  module Core
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up the base requirements for Plutonium"

      def start
        setup_packaging_system
        install_required_gems
        setup_app
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def setup_packaging_system
        copy_file "config/packages.rb"
        create_file "packages/.keep"
        insert_into_file "config/application.rb", "\nrequire_relative \"packages\"\n", after: /Bundler\.require.*\n/
        # insert_into_file "config/application.rb", indent("Plutonium.configure_rails config\n\n", 4), after: /.*< Rails::Application\n/
      end

      def setup_app
        directory "config"
        directory "app"
      end

      def install_required_gems
        # invoke "pu:gem:simple_form"
        # invoke "pu:gem:pagy"
        # invoke "pu:gem:rabl"
      end
    end
  end
end
