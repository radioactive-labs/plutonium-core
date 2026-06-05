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
        sync_skills_if_present
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def sync_skills_if_present
        return unless File.file?(Rails.root.join(".claude", "skills", "plutonium", "SKILL.md"))

        say_status :update, "Syncing Plutonium Claude skills...", :green
        # Shell out to a fresh process so the sync reads the newly-installed
        # gem's skills. Invoking in-process would reuse the already-loaded
        # (pre-update) gem, whose Plutonium.root still points at the old skills.
        #
        # Must run unbundled: this process was booted with the pre-update gem,
        # and its bundler environment (BUNDLE_GEMFILE, RUBYOPT=-rbundler/setup,
        # the pinned load path) is inherited by the subprocess. Without clearing
        # it, the "fresh" bin/rails re-uses the old locked gem set and syncs the
        # stale skills anyway. with_unbundled_env lets it re-resolve from the
        # updated Gemfile.lock and load the new gem.
        Bundler.with_unbundled_env do
          run "bin/rails generate pu:skills:sync"
        end
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
