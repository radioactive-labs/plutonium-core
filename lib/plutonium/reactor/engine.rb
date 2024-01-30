module Plutonium
  module Reactor
    module Engine
      extend ActiveSupport::Concern
      include Plutonium::Packaging::Package

      included do
        initializer "p8.reactor.disable_turbo" do
          Rails.autoloaders.once.do_not_eager_load("#{Turbo::Engine.root}/app/channels")
        end

        # initializer "p8.reactor.reloader" do |app|
        #   Plutonium::Reloader.new.tap do |reloader|
        #     reloader.execute
        #     app.reloaders << reloader
        #     app.reloader.to_run { reloader.execute }
        #   end
        # end

        initializer "p8.reactor.configure_pagy" do
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
