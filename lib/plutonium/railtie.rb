# frozen_string_literal: true

module Plutonium
  class Railtie < Rails::Railtie
    initializer "plutonium.assets_server" do
      # setup a middleware to serve our assets
      config.app_middleware.insert_before(
        ActionDispatch::Static,
        Rack::Static,
        urls: ["/plutonium-assets"],
        root: Plutonium.root.join("public"),
        cascade: true
      )
    end
  end
end
