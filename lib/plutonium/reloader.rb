# frozen_string_literal: true

require "active_support/notifications"

module Plutonium
  # Reloader class for Plutonium
  #
  # This class is responsible for managing the reloading of Plutonium components
  # and related files during development.
  class Reloader
    class << self
      # Start the reloader
      #
      # @return [void]
      def start!
        puts "=> [plutonium] starting reloader"

        ActiveSupport::Notifications.instrument("plutonium.reloader.start") do
          @listener&.stop
          @listener = initialize_listener
        end
      end

      private

      # Initialize the file listener
      #
      # @return [Listen::Listener, nil] the initialized listener or nil if no paths to watch
      def initialize_listener
        require "listen"

        reload_paths = gather_reload_paths
        return if reload_paths.empty?

        Listen.to(*reload_paths, only: /\.rb$/) { |modified, added, removed|
          handle_file_changes(modified, added, removed)
        }.tap(&:start)
      end

      # Gather paths to be watched for changes
      #
      # @return [Array<String>] list of paths to watch
      def gather_reload_paths
        reload_paths = []

        if Plutonium.configuration.development?
          reload_paths.concat([
            Plutonium.lib_root.to_s,
            Plutonium.root.join("app", "views", "components").to_s,
            Plutonium.root.join("config", "initializers").to_s
          ])
        end

        packages_dir = Rails.root.join("packages").to_s
        reload_paths << packages_dir if File.directory?(packages_dir)

        reload_paths
      end

      # Handle file changes detected by the listener
      #
      # @param modified [Array<String>] list of modified files
      # @param added [Array<String>] list of added files
      # @param removed [Array<String>] list of removed files
      # @return [void]
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

      # Check if the file is within the packages directory
      #
      # @param file [String] path to the file
      # @return [Boolean] true if the file is within the packages directory
      def file_starts_with_packages_dir?(file)
        file.start_with?(Rails.root.join("packages").to_s)
      end

      # Handle changes to files within the packages directory
      #
      # @param file [String] path to the changed file
      # @param added [Array<String>] list of added files
      # @return [void]
      def handle_package_file_changes(file, added)
        return if added.include?(file)

        case File.basename(file)
        when "engine.rb"
          reload_engine_and_routes(file)
        end
      end

      # Reload engine and routes
      #
      # @param file [String] path to the engine file
      # @return [void]
      def reload_engine_and_routes(file)
        Plutonium.logger.debug "[plutonium] reloading: engine+routes"
        load file
        Rails.application.reload_routes!
      end

      # Reload the framework and file
      #
      # @param file [String] path to the file
      # @return [void]
      def reload_framework_and_file(file)
        Plutonium.logger.debug "[plutonium] reloading: app+framework"
        Rails.application.reloader.reload!
        Plutonium::ZEITWERK_LOADER.reload
        reload_components
      end

      # Reload components
      #
      # @return [void]
      def reload_components
        Object.send(:remove_const, "PlutoniumUi")
        load Plutonium.root.join("app", "views", "components", "base.rb")
      end

      # Reload a single file
      #
      # @param file [String] path to the file
      # @return [Boolean] true if the file was successfully loaded
      def reload_file(file)
        load(file)
      end

      # Log reload failure
      #
      # @param file [String] path to the file that failed to reload
      # @param error [StandardError] the error that occurred during reloading
      # @return [void]
      def log_reload_failure(file, error)
        Plutonium.logger.error "\n[plutonium] reloading failed\n\n#{error.message}\n"
      end
    end
  end
end
