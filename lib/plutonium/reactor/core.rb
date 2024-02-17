module Plutonium
  module Reactor
    class Core
      def self.achieve_criticality!
        # TODO: clean this mess up

        require "pagy"
        require "pagy/extras/bootstrap"
        require "pagy/extras/overflow"
        require "pagy/extras/trim"
        require "pagy/extras/headers"

        # this is required to circumvent an issue with turbo loading action cable even if it is not included
        # in rails
        Rails.autoloaders.once.do_not_eager_load("#{Turbo::Engine.root}/app/channels")

        return unless Plutonium::Config.reload_files

        # GLORIOUS hot reloading!!!
        @listener ||= begin
          require "listen"

          plutonium_lib_dir = Plutonium.lib_root.to_s
          packages_dir = Rails.root.join("packages/").to_s
          listener = Listen.to(plutonium_lib_dir, packages_dir, only: /\.rb$/) do |modified, added, removed|
            (modified + added).each do |file|
              if file.starts_with?(packages_dir)
                # if package file was added, ignore it
                # otherwise rails gets mad at us since engines cannot be loaded after initial boot
                # TODO: check if guard has apis to control reloading dynamically
                next if added.include? file

                case File.basename(file)
                when "engine.rb"
                  # reload engines. due to how we load packages, rails does not support
                  load file
                  # reload routes to pick up any registration changes
                  Rails.application.reload_routes!
                else
                  # non engine package files are reloaded by rails automatically
                end
              else
                load file
              end
            end
          end
          listener.start
          listener
        end
      end
    end
  end
end
