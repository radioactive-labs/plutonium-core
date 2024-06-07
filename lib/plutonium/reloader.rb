require "active_support/notifications"

# Be sure to restart your server when you modify this file.

module Plutonium
  class Reloader
    class << self
      def start!
        puts "=> [plutonium] starting reloader"

        ActiveSupport::Notifications.instrument("plutonium.reloader.start") do
          # Task code here
          @listener&.stop
          @listener = initialize_listener
        end
      end

      private

      def initialize_listener
        require "listen"

        reload_paths = gather_reload_paths
        return unless reload_paths.any?

        listener = Listen.to(*reload_paths, only: /\.rb$/) do |modified, added, removed|
          handle_file_changes(modified, added, removed)
        end
        listener.start
        listener
      end

      def gather_reload_paths
        reload_paths = []

        if Plutonium.development?
          reload_paths << Plutonium.lib_root.to_s
          reload_paths << Plutonium.root.join("app", "views", "components").to_s
          reload_paths << Plutonium.root.join("config", "initializers").to_s
        end

        packages_dir = Rails.root.join("packages/").to_s
        reload_paths << packages_dir if File.directory?(packages_dir)

        reload_paths
      end

      def handle_file_changes(modified, added, removed)
        (modified + added).each do |file|
          Plutonium.logger.debug "[plutonium] change detected: #{file}"

          if file == __FILE__
            reload_file(file)
            start!
          elsif file_starts_with_packages_dir?(file)
            handle_package_file_changes(file, added)
          else
            reload_framework_and_file(file)
          end
        rescue => e
          log_reload_failure(file, e)
        end
      end

      def file_starts_with_packages_dir?(file)
        packages_dir = Rails.root.join("packages/").to_s
        file.starts_with?(packages_dir)
      end

      def handle_package_file_changes(file, added)
        return if added.include?(file)

        case File.basename(file)
        when "engine.rb"
          reload_engine_and_routes(file)
        else
          # Non-engine package files are reloaded by Rails automatically
        end
      end

      def reload_engine_and_routes(file)
        Plutonium.logger.debug "[plutonium] reloading: engine+routes"
        load file
        Rails.application.reload_routes!
      end

      def reload_framework_and_file(file)
        # Ensure that the file loads correctly before we do any reloading
        load file

        Plutonium.logger.debug "[plutonium] reloading: app+framework"
        Rails.application.reloader.reload!
        Plutonium::ZEITWERK_LOADER.reload
        load Plutonium.root.join("app", "views", "components", "base.rb")
        # Ensure files that do not contain constants are loaded again e.g. initializers
        load file
      end

      def reload_file(file)
        load file
      end

      def log_reload_failure(file, error)
        Plutonium.logger.error "\n[plutonium] reloading failed\n\n#{error.message}\n"
      end
    end
  end
end
