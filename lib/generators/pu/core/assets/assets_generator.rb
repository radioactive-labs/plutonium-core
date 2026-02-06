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
        replace_build_script
        import_styles
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def copy_tailwind_config
        copy_file "tailwind.config.js", force: true
        copy_file "postcss.config.js", force: true
      end

      def install_dependencies
        [
          "@radioactive-labs/plutonium",
          "postcss", "postcss-cli", "postcss-import",
          "@tailwindcss/postcss", "@tailwindcss/forms", "@tailwindcss/typography",
          "cssnano", "marked",
          "flowbite-typography"
        ].each do |package|
          run "yarn add #{package}"
        end

        run "yarn upgrade tailwindcss --latest"
      end

      def configure_application
        insert_into_file "app/javascript/controllers/index.js", <<~EOT

          import { registerControllers } from "@radioactive-labs/plutonium"
          registerControllers(application)
        EOT

        insert_into_file "app/assets/stylesheets/application.tailwind.css", <<~EOT, after: /@import "tailwindcss";\n/
          @config '../../../tailwind.config.js';
        EOT

        configure_plutonium "config.assets.stylesheet = \"application\""
        configure_plutonium "config.assets.script = \"application\""
      end

      def replace_build_script
        package_json = File.read("package.json")
        package = JSON.parse(package_json)

        package["scripts"] ||= {}
        package["scripts"]["build"] = "esbuild app/javascript/*.* --bundle --sourcemap --format=esm --outdir=app/assets/builds --public-path=/assets"
        package["scripts"]["build:css"] = "postcss ./app/assets/stylesheets/application.tailwind.css -o ./app/assets/builds/application.css"

        File.write("package.json", JSON.pretty_generate(package) + "\n")
      end

      def import_styles
        prepend_to_file "app/assets/stylesheets/application.tailwind.css",
          "@import \"gem:plutonium/src/css/plutonium.css\";\n\n"
      end
    end
  end
end
