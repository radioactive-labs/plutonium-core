require "active_support"

module Plutonium
  module Config
    # @return [Boolean] Are we developing plutonium? This is separate from Rails development.
    mattr_accessor :development
    @@development = defined?(Rails.env) && Rails.env.development?

    # @return [Boolean] Should hotreload be enabled? Enabled by default in Rails development.
    mattr_accessor :enable_hotreload
    @@enable_hotreload = defined?(Rails.env) && Rails.env.development?

    mattr_accessor :cache_discovery
    @@cache_discovery = defined?(Rails.env) && !Rails.env.development?
  end
end
