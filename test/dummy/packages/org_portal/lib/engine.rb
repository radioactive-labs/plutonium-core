module OrgPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
    # add concerns above.

    config.after_initialize do
      scope_to_entity ::Organization, strategy: :path
      # add directives above.
    end
  end
end
