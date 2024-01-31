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
    root.join("lib", "plutonium")
  end

  def self.configure_rails(config)
    # Serve up our assets
    config.middleware.insert_before(
      ActionDispatch::Static,
      Rack::Static,
      urls: ["/plutonium-assets"],
      root: Plutonium.root.join("public"),
      cascade: true
    )
  end

  autoload :Reloader

  eager_autoload do
    autoload :Packaging
    autoload :Reactor
    autoload :Core
    autoload :Policy
    autoload :Helpers
    autoload :SimpleForm
    autoload :Auth
  end

  mattr_accessor :cache_discovery
  @@cache_discovery = defined?(Rails.env) && !Rails.env.development?
end

# Add a shorter alias
# Pu = Plutonium
