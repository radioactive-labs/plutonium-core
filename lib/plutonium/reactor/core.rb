# Be sure to restart your server when you modify this file.
# This is a glorified initializer

module Plutonium
  module Reactor
    class Core
      def self.achieve_criticality!
        # Load initializers
        Dir.glob(Plutonium.lib_root.join("initializers", "**", "*.rb")) { |file| load file }

        start_reloader!
      end

      def self.start_reloader!
        return unless Plutonium::Config.enable_hotreload

        # GLORIOUS hotreload!!!
        @listener ||= begin
          require "listen"

          reload_paths = []

          if Plutonium::Config.development
            reload_paths << Plutonium.lib_root.to_s
            reload_paths << Plutonium.root.join("app/views/components").to_s
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
                  load file
                  Rails.application.reload_routes!
                else
                  # non engine package files are reloaded by rails automatically
                end
              else
                load file
              end
            rescue => e
              Rails.logger.error "\npu.hotreloader: failed to reload #{file}\n\n#{e}\n"
            end
          end
          listener.start
          listener
        end
      end
    end
  end
end
