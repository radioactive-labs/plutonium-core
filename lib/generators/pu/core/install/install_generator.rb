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
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def setup_packages
        copy_file "config/packages.rb"
        create_file "packages/.keep"
        insert_into_file "config/application.rb", "\nrequire_relative \"packages\"\n", after: /Bundler\.require.*\n/
        # insert_into_file "config/application.rb", indent("Plutonium.configure_rails config\n\n", 4), after: /.*< Rails::Application\n/
      end

      def setup_app
        directory "config"
        directory "app"

        environment "# config.plutonium.assets.favicon = \"favicon.ico\""
        environment "# config.plutonium.assets.logo = \"logo.png\""
      end

      def eject_views
        invoke "pu:eject:layout", [], dest: "main_app",
          force: options[:force],
          skip: options[:skip]
      end
    end
  end
end
