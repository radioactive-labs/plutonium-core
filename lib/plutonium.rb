require "active_support"
require_relative "plutonium/version"

module Plutonium
  # require_relative "active_model/validations/array_validator"
  # require_relative "active_model/validations/attached_validator"
  # require_relative "active_model/validations/url_validator"

  extend ActiveSupport::Autoload

  class Error < StandardError; end

  def self.root
    Pathname.new File.expand_path("../", __dir__)
  end

  def self.lib_root
    Pathname.new File.expand_path("lib/plutonium/", root)
  end

  def self.configure_rails(config)
    reactor_engine = "Core::Engine".constantize

    config.railties_order += Rails::Engine.descendants.select { |engine| engine.include? Plutonium::App }
    config.railties_order += Rails::Engine.descendants.select { |engine| engine.include? Plutonium::Package } - [reactor_engine]
    config.railties_order += [reactor_engine]

    config.middleware.insert_before(
      ActionDispatch::Static,
      Rack::Static,
      urls: ["/plutonium-assets"],
      root: Plutonium.root.join("public")
    )
  end

  autoload :Package
  autoload :Feature
  autoload :App
  autoload :Core
  autoload :Policy
  autoload :UI
  autoload :Helpers
  autoload :SimpleForm
  autoload :Builders
end

# Add a shorter alias
# Pu = Plutonium
