# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    class AssetsGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Setup plutonium assets"

      def start
        install_dependencies
        copy_tailwind_config
        configure_application
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def copy_tailwind_config
        copy_file "tailwind.config.js"
      end

      def install_dependencies
        `yarn add @radioactive-labs/plutonium`
        `yarn add flowbite @tailwindcss/forms`
      end

      def configure_application
        insert_into_file "app/javascript/controllers/index.js", <<~EOT

          import { registerControllers } from "@radioactive-labs/plutonium"
          registerControllers(application)
        EOT

        environment "config.plutonium.assets.stylesheet = \"application\""
        environment "config.plutonium.assets.script = \"application\""
      end
    end
  end
end
