# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Core
    class UpdateGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Update Plutonium gem and npm package to the latest version"

      SHELL_PIN_THRESHOLD = "0.49.1"

      def start
        @previous_gem_version = installed_gem_version
        update_gem
        update_npm_package
        sync_skills_if_present
        pin_shell_to_classic
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def sync_skills_if_present
        return unless File.file?(Rails.root.join(".claude", "skills", "plutonium", "SKILL.md"))

        say_status :update, "Syncing Plutonium Claude skills...", :green
        Rails::Generators.invoke("pu:skills:sync", [], destination_root: Rails.root)
      end

      # Pin the shell config to :classic on apps upgrading from a version
      # that predates the shell change so the upgrade is invisible. Newer
      # apps installed after the shell change get :modern from the install
      # template and shouldn't be flipped.
      def pin_shell_to_classic
        return unless @previous_gem_version
        return unless SemanticRange.satisfies?(@previous_gem_version, "<=#{SHELL_PIN_THRESHOLD}")

        initializer = Rails.root.join("config", "initializers", "plutonium.rb")
        return unless File.file?(initializer)
        return if File.read(initializer).match?(/^\s*config\.shell\s*=/)

        say_status :update, "Pinning Plutonium shell to :classic...", :green
        configure_plutonium "config.shell = :classic"
      end

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
