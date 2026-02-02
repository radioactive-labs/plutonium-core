# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class SetupGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Set up SQLite with proper configuration"

      RAILS_8_VERSION = ::Gem::Version.new("8.0.0")

      def start
        ensure_sqlite3_version

        # Add enhanced adapter for Rails 7
        if rails_version < RAILS_8_VERSION
          bundle "activerecord-enhancedsqlite3-adapter", version: "~> 0.8.0"
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      SQLITE3_MIN_VERSION = ::Gem::Version.new("2.0.0")

      def ensure_sqlite3_version
        current = installed_gem_version("sqlite3")
        if current.nil?
          bundle "sqlite3", version: "~> 2.0"
        elsif current < SQLITE3_MIN_VERSION
          log :bundle, "updating sqlite3 from #{current} to ~> 2.0"
          gsub_file "Gemfile", /^gem ["']sqlite3["'].*$/, 'gem "sqlite3", "~> 2.0"'
          bundle!
        end
      end

      def installed_gem_version(gem_name)
        lockfile = File.join(destination_root, "Gemfile.lock")
        return nil unless File.exist?(lockfile)

        content = File.read(lockfile)
        match = content.match(/#{gem_name} \((\d+\.\d+\.\d+)/)
        ::Gem::Version.new(match[1]) if match
      end

      def rails_version
        @rails_version ||= ::Gem::Version.new(Rails::VERSION::STRING).release
      end
    end
  end
end
