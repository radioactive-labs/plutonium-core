require "view_component"

module Plutonium
  class Railtie < Rails::Railtie
    config.plutonium = ActiveSupport::OrderedOptions.new

    initializer "plutonium.append_assets_path" do |app|
      config.to_prepare do
        Rails.application.config.assets.paths << Plutonium.root.join("app/assets/build").to_s
      end
    end

    initializer "plutonium.asset_server" do
      # setup a middleware to serve our assets
      config.app_middleware.insert_before(
        ActionDispatch::Static,
        Rack::Static,
        urls: ["/plutonium-assets"],
        root: Plutonium.root.join("public"),
        cascade: true,
        header_rules: [
          # Cache all static files in public caches (e.g. Rack::Cache) as well as in the browser
          [:all, {"cache-control" => "public, max-age=31536000"}]
        ]
      )
    end

    initializer "plutonium.view_components_capture_compat" do
      config.view_component.capture_compatibility_patch_enabled = true
    end
  end
end
