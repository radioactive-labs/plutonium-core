require "active_support"

module Plutonium
  module Config
    mattr_accessor :reload_files
    @@reload_files = defined?(Rails.env) && Rails.env.local?

    mattr_accessor :cache_discovery
    @@cache_discovery = defined?(Rails.env) && !Rails.env.development?
  end
end
