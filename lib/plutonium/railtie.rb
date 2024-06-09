require "view_component"

module Plutonium
  class Railtie < Rails::Railtie
    config.plutonium = ActiveSupport::OrderedOptions.new
    config.plutonium.cache_discovery = defined?(Rails.env) && !Rails.env.development?
    config.plutonium.enable_hotreload = defined?(Rails.env) && Rails.env.development?

    config.plutonium.assets = ActiveSupport::OrderedOptions.new
    config.plutonium.assets.logo = "plutonium.png"
    config.plutonium.assets.favicon = "plutonium.ico"
    config.plutonium.assets.stylesheet = "plutonium.css"
    config.plutonium.assets.script = "plutonium.min.js"

    # If you don't want to precompile Plutonium's assets (eg. because you're using webpack),
    # you can do this in an intiailzer:
    #
    # config.after_initialize do
    #   config.assets.precompile -= Plutonium::Railtie::PRECOMPILE_ASSETS
    # end
    PRECOMPILE_ASSETS = %w[plutonium.js plutonium.js.map plutonium.min.js plutonium.min.js.map plutonium.css]

    initializer "plutonium.assets" do
      next unless Rails.application.config.respond_to?(:assets)

      Rails.application.config.assets.precompile += PRECOMPILE_ASSETS
      Rails.application.config.assets.paths << Plutonium.root.join("app/assets").to_s
    end

    initializer "plutonium.load_components" do
      load Plutonium.root.join("app", "views", "components", "base.rb")
    end

    initializer "plutonium.initializers" do
      Dir.glob(Plutonium.root.join("config", "initializers", "**", "*.rb")) { |file| load file }
    end

    initializer "plutonium.asset_server" do
      next unless Plutonium.development?

      puts "=> [plutonium] starting assets server"
      # setup a middleware to serve our assets
      config.app_middleware.insert_before(
        ActionDispatch::Static,
        Rack::Static,
        urls: ["/build"],
        root: Plutonium.root.join("src").to_s,
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

    rake_tasks do
      load "tasks/create_rodauth_admin.rake"
    end

    config.after_initialize do
      Plutonium::Reloader.start! if Rails.application.config.plutonium.enable_hotreload
      Plutonium::ZEITWERK_LOADER.eager_load if Rails.env.production?
    end
  end
end
