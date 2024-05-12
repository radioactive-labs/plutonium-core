require "active_support"
require "active_model"

module Plutonium
  module Config
    # @return [Boolean] Are we developing plutonium? This is separate from Rails development.
    mattr_accessor :development
    @@development = ActiveModel::Type::Boolean.new.cast(ENV["PLUTONIUM_DEV"]).present?

    # @return [Boolean] Should hotreload be enabled? Enabled by default in Rails development.
    mattr_accessor :enable_hotreload
    @@enable_hotreload = defined?(Rails.env) && Rails.env.development?

    mattr_accessor :cache_discovery
    @@cache_discovery = defined?(Rails.env) && !Rails.env.development?

    mattr_accessor :stylesheet_tag
    @@stylesheet_tag = ->(view_context) {
      "<link rel=\"stylesheet\" href=\"#{Plutonium.stylesheet_link}\" />"
    }

    mattr_accessor :script_tag
    @@script_tag = ->(view_context) {
      "<script src=\"#{Plutonium.script_link}\"></script>"
    }
  end
end
