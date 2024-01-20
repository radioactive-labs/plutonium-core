module Plutonium
  module Reactor
    module Engine
      extend ActiveSupport::Concern
      include Plutonium::Packaging::Package

      included do
        initializer "plutonium.reactor.disable_turbo" do
          Rails.autoloaders.once.do_not_eager_load("#{Turbo::Engine.root}/app/channels")
        end
      end
    end
  end
end
