# frozen_string_literal: true

require "view_component"

module Plutonium
  # Plutonium::Railtie integrates Plutonium with Rails applications.
  #
  # This Railtie sets up configurations, initializers, and tasks for Plutonium
  # to work seamlessly within a Rails environment.
  class Railtie < Rails::Railtie
    # Assets to be precompiled
    #
    # If you don't want to precompile Plutonium's assets (eg. because you're using webpack),
    # you can do this in an intiailzer:
    #
    # config.after_initialize do
    #   config.assets.precompile -= Plutonium::Railtie::PRECOMPILE_ASSETS
    # end
    PRECOMPILE_ASSETS = %w[
      plutonium.js plutonium.js.map plutonium.min.js plutonium.min.js.map
      plutonium.css plutonium.png plutonium.ico
    ].freeze

    initializer "plutonium.assets" do
      setup_asset_pipeline if Rails.application.config.respond_to?(:assets)
    end

    initializer "plutonium.load_components" do
      load_base_component
    end

    initializer "plutonium.initializers" do
      load_plutonium_initializers
    end

    initializer "plutonium.asset_server" do
      setup_development_asset_server if Plutonium.configuration.development?
    end

    initializer "plutonium.view_components_capture_compat" do
      config.view_component.capture_compatibility_patch_enabled = true
    end

    initializer "plutonium.action_dispatch_extensions" do
      extend_action_dispatch
    end

    rake_tasks do
      load "tasks/create_rodauth_admin.rake"
    end

    config.after_initialize do
      Plutonium::Reloader.start! if Plutonium.configuration.enable_hotreload
      Plutonium::ZEITWERK_LOADER.eager_load if Rails.env.production?
    end

    private

    def setup_asset_pipeline
      Rails.application.config.assets.precompile += PRECOMPILE_ASSETS
      Rails.application.config.assets.paths << Plutonium.root.join("app/assets").to_s
    end

    def load_base_component
      load Plutonium.root.join("app", "views", "components", "base.rb")
    end

    def load_plutonium_initializers
      Dir.glob(Plutonium.root.join("config", "initializers", "**", "*.rb")) { |file| load file }
    end

    def setup_development_asset_server
      puts "=> [plutonium] starting assets server"
      config.app_middleware.insert_before(
        ActionDispatch::Static,
        Rack::Static,
        urls: ["/build"],
        root: Plutonium.root.join("src").to_s,
        cascade: true,
        header_rules: [
          [:all, {"cache-control" => "public, max-age=31536000"}]
        ]
      )
    end

    def extend_action_dispatch
      ActionDispatch::Routing::Mapper.prepend Plutonium::Routing::MapperExtensions
      ActionDispatch::Routing::RouteSet.prepend Plutonium::Routing::RouteSetExtensions
      Rails::Engine.include Plutonium::Routing::ResourceRegistration
    end
  end
end
