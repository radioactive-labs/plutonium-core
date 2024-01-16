require "rails/engine"

module Plutonium
  module Reactor
    extend ActiveSupport::Concern
    include Package

    included do
      initializer "disable_turbo" do
        Rails.autoloaders.once.do_not_eager_load("#{Turbo::Engine.root}/app/channels")
      end
    end
  end
end
