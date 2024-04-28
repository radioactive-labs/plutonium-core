# Be sure to restart your server when you modify this file.
# This is a glorified initializer

module Plutonium
  module Reactor
    class Core
      def self.achieve_criticality!
        # Eager load the framework
        # Plutonium::ZEITWERK_LOADER.eager_load

        # Load view components
        load Plutonium.root.join("app", "views", "components", "base.rb")

        # Load initializers
        Dir.glob(Plutonium.root.join("config", "initializers", "**", "*.rb")) { |file| load file }

        start_reloader!
      end

      def self.start_reloader!
        # TODO: see which parts of this can be moved into zeitwerk
        return unless Plutonium::Config.enable_hotreload

        # GLORIOUS hotreload!!!
        @listener ||= begin
          require "listen"

          reload_paths = []

          if Plutonium::Config.development
            reload_paths << Plutonium.lib_root.to_s
            reload_paths << Plutonium.root.join("app", "views", "components").to_s
            reload_paths << Plutonium.root.join("config", "initializers").to_s
          end

          # we want to always watch packages for changes to engines
          packages_dir = Rails.root.join("packages/").to_s
          reload_paths << packages_dir if File.directory?(packages_dir)

          listener = Listen.to(*reload_paths, only: /\.rb$/) do |modified, added, removed|
            (modified + added).each do |file|
              next if file == __FILE__ # reloading this file does nothing

              if file.starts_with?(packages_dir)
                # if package file was added, ignore it
                # otherwise rails gets mad at us since engines cannot be loaded after initial boot
                # TODO: check if guard has apis to control reloading dynamically
                next if added.include? file

                case File.basename(file)
                when "engine.rb"
                  # rails engines are loaded once,
                  # so in order to detect resource registration changes, we need to handle reloads ourselves

                  # load the engine and reload routes to pick up any registration changes
                  Rails.logger.debug "\nplutonium: reloaded #{file}\n"
                  load file
                  Rails.application.reload_routes!
                else
                  # non engine package files are reloaded by rails automatically
                end
              else
                Plutonium::ZEITWERK_LOADER.reload
                load Plutonium.root.join("app", "views", "components", "base.rb")
                load file # this just a lazy way to ensure we load files that do not contain constants like initializers
              end
              Rails.logger.debug "\n\nplutonium: reload #{file}\n"
            rescue => e
              Rails.logger.error "\n\nplutonium: reload failed #{file}\n\n#{e}\n"
            end
          end
          listener.start
          listener
        end
      end
    end
  end
end
