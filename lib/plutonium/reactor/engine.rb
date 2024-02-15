module Plutonium
  module Reactor
    module Engine
      extend ActiveSupport::Concern
      include Plutonium::Packaging::Package

      included do
        initializer "p8.reactor.disable_turbo" do
          Rails.autoloaders.once.do_not_eager_load("#{Turbo::Engine.root}/app/channels")
        end

        initializer "p8.reactor.reloader" do |app|
          next unless Plutonium::Config.reload_files

          @listener ||= begin
            require 'listen'

            listener = Listen.to(Plutonium.lib_root.to_s, only: /\.rb$/) do |modified, added, removed|
              (modified + added).each { |f| load f}
            end
            listener.start
            listener
          end
        end

        initializer "p8.reactor.pagy" do
          require "pagy"

          require "pagy/extras/bootstrap"
          require "pagy/extras/overflow"
          require "pagy/extras/trim"
          require "pagy/extras/headers"
        end
      end
    end
  end
end
