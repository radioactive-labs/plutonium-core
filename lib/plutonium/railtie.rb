# frozen_string_literal: true

module Plutonium
  class Railtie < Rails::Railtie
    # add railties here

    initializer "plutonium.achieve_criticality" do
      # get the ball rolling
      Plutonium::Reactor::Core.achieve_criticality!
    end
  end
end
