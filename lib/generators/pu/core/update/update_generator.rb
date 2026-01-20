# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    class UpdateGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Update Plutonium gem and npm package to the latest version"

      def start
        update_gem
        update_npm_package
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def update_gem
        say_status :update, "Updating plutonium gem...", :green
        run "bundle update plutonium"
      end

      def update_npm_package
        gem_version = installed_gem_version

        say_status :update, "Updating @radioactive-labs/plutonium to #{gem_version}...", :green
        run "yarn add @radioactive-labs/plutonium@^#{gem_version}"
      end

      def installed_gem_version
        # Parse version from Gemfile.lock after bundle update
        lockfile = "Gemfile.lock"
        return nil unless File.exist?(lockfile)

        content = File.read(lockfile)
        match = content.match(/plutonium \((\d+\.\d+\.\d+)\)/)
        match[1] if match
      end
    end
  end
end
