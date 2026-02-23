# frozen_string_literal: true

module OrgPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end
