# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    class AssetsGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Setup plutonium assets"

      def start
        verify_prerequisites
        install_dependencies
        copy_tailwind_config
        configure_application
        replace_build_script
        import_styles
        fix_layout_stylesheet_tag
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      # The asset pipeline assumes the app was generated with esbuild + Tailwind + Stimulus.
      # Without those, `application.tailwind.css` (Tailwind) and/or
      # `app/javascript/controllers/index.js` (Stimulus) don't exist, and the generator
      # later crashes with a cryptic inject_into_file error. Fail early listing every
      # missing file with a fix.
      def verify_prerequisites
        required = [
          "app/assets/stylesheets/application.tailwind.css",
          "app/javascript/controllers/index.js"
        ]
        missing = required.reject { |path| File.exist?(path) }
        return if missing.empty?

        error <<~MSG
          Plutonium assets require a Rails app generated with esbuild, Tailwind, and Stimulus.
          Missing files:
            - #{missing.join("\n  - ")}

          Re-create the app with the required flags:
            rails new myapp -a propshaft -j esbuild -c tailwind \\
              -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
        MSG
      end

      def copy_tailwind_config
        copy_file "tailwind.config.js", force: true
        copy_file "postcss.config.js", force: true
      end

      # Every package goes through one `add` built for the app's package manager
      # (bun, yarn 1, yarn 2+, npm or pnpm; see Concerns::JsPackageManager).
      # Versions ride inline because `pkg@latest` and `pkg@^x.y.z` are the one
      # spelling all of them share; yarn 1's `upgrade --latest` does not exist
      # on yarn 2+, and running yarn inside a bun app leaves two lockfiles.
      def install_dependencies
        ensure_yarn_node_modules_linker

        command = js_add_command(npm_packages)
        return if run(command)

        say_status :warn,
          "`#{command}` failed — your app may not boot until you re-run it",
          :yellow
      end

      def npm_packages
        [
          # Pinned to the gem so the two halves never drift; pu:core:update
          # keeps them together afterwards.
          "@radioactive-labs/plutonium@^#{Plutonium::VERSION}",
          # cssbundling-rails already installs the latest Tailwind on new apps;
          # apps created on Tailwind 3 are moved to 4 here.
          "tailwindcss@latest",
          "postcss", "postcss-cli", "postcss-import",
          "@tailwindcss/postcss", "@tailwindcss/forms", "@tailwindcss/typography",
          "cssnano", "marked",
          "flowbite-typography"
        ]
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

      # Rails 8 generates layouts with `stylesheet_link_tag :app` which includes all
      # stylesheets in the asset paths. With cssbundling-rails, this causes both the
      # built CSS and the source CSS to be served, leading to errors when the browser
      # tries to load the unprocessed source file containing PostCSS directives.
      def fix_layout_stylesheet_tag
        layout_file = "app/views/layouts/application.html.erb"
        return unless File.exist?(layout_file)

        gsub_file layout_file, /stylesheet_link_tag\s+:app\b/, 'stylesheet_link_tag "application"'
      end
    end
  end
end
