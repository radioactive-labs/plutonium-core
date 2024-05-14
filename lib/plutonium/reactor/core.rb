# Be sure to restart your server when you modify this file.
# This is a glorified initializer

module Plutonium
  module Reactor
    class Core
      def self.achieve_criticality!
        # Eager load the framework
        # Plutonium::ZEITWERK_LOADER.eager_load

        start_reloader! if Rails.application.config.plutonium.enable_hotreload
      end

      def self.start_reloader!
        puts "=> [plutonium] starting reloader"
        # TODO: see which parts of this can be moved into zeitwerk

        # GLORIOUS hotreload!!!
        @listener&.stop
        @listener = begin
          require "listen"

          reload_paths = []

          if Plutonium.development?
            reload_paths << Plutonium.lib_root.to_s
            reload_paths << Plutonium.root.join("app", "views", "components").to_s
            reload_paths << Plutonium.root.join("config", "initializers").to_s
          end

          # we want to always watch packages for changes to engines
          packages_dir = Rails.root.join("packages/").to_s
          reload_paths << packages_dir if File.directory?(packages_dir)

          listener = Listen.to(*reload_paths, only: /\.rb$/) do |modified, added, removed|
            (modified + added).each do |file|
              Plutonium.logger.debug "[plutonium] change detected: #{file}"

              if file == __FILE__
                load file
                Plutonium::Reactor::Core.achieve_criticality!
              elsif file.starts_with?(packages_dir)
                # if package file was added, ignore it
                # otherwise rails gets mad at us since engines cannot be loaded after initial boot
                # TODO: check if guard has apis to control reloading dynamically
                next if added.include? file

                case File.basename(file)
                when "engine.rb"
                  # rails engines are loaded once,
                  # so in order to detect resource registration changes, we need to handle reloads ourselves

                  # load the engine and reload routes to pick up any registration changes
                  Plutonium.logger.debug "[plutonium] reloading #{file}"
                  load file
                  Rails.application.reload_routes!
                else
                  # non engine package files are reloaded by rails automatically
                end
              else
                Plutonium.logger.debug "[plutonium] reloading framework"
                Plutonium::ZEITWERK_LOADER.reload
                load Plutonium.root.join("app", "views", "components", "base.rb")
                load file # this just a lazy way to ensure we load files that do not contain constants like initializers
              end
            rescue => e
              Plutonium.logger.error "\n[plutonium] reload failed #{file}\n\n#{e}\n"
              Plutonium.logger.error e.backtrace.join("\n")
            end
          end
          listener.start
          listener
        end
      end
    end
  end
end
