module DemoPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    # add concerns above.

    config.after_initialize do
      # add directives above.
    end
  end
end
