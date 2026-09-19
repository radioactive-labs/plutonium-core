# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Docker
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Set up docker for project"

      # Fallbacks when the tool is not on PATH at generation time.
      NODE_LTS_VERSION = "22.23.2"
      YARN_CLASSIC_VERSION = "1.22.22"
      BUN_VERSION = "1.4.2"

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

      # The JavaScript toolchain is chosen the same way jsbundling-rails will
      # choose it at `assets:precompile` inside the image, and versions come
      # from the machine generating the Dockerfile (or NODE_VERSION /
      # YARN_VERSION / BUN_VERSION), like Rails' own template.
      def using_bun?
        js_package_manager == :bun
      end

      def dockerfile_node_version
        ENV.fetch("NODE_VERSION") { node_version || NODE_LTS_VERSION }
      end

      def dockerfile_yarn_version
        ENV.fetch("YARN_VERSION") { yarn_version || YARN_CLASSIC_VERSION }
      end

      def dockerfile_bun_version
        ENV.fetch("BUN_VERSION") { bun_version || BUN_VERSION }
      end

      # Yarn 2+ is installed through corepack, and its lockfile flag is
      # --immutable rather than yarn 1's --frozen-lockfile.
      def yarn_through_corepack?
        js_package_manager == :yarn && dockerfile_yarn_version.to_i >= 2
      end

      def js_lockfile_copy
        case js_package_manager
        when :bun then "package.json bun.lock*"
        when :pnpm then "package.json pnpm-lock.yaml"
        when :npm then "package.json package-lock.json"
        # .yarnrc.yml carries nodeLinker for yarn 2+; the glob keeps the COPY
        # valid on yarn 1 apps that have none.
        else "package.json yarn.lock .yarnrc.yml*"
        end
      end

      def js_frozen_install_command
        case js_package_manager
        when :bun then "bun install --frozen-lockfile"
        when :pnpm then "pnpm install --frozen-lockfile"
        when :npm then "npm ci"
        else "yarn install --#{yarn_through_corepack? ? "immutable" : "frozen-lockfile"}"
        end
      end
    end
  end
end
