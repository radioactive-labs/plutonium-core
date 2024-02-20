require "active_support"
require_relative "plutonium/version"
require_relative "plutonium/railtie"

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

  autoload :Config

  eager_autoload do
    autoload :Packaging
    autoload :Reactor
    autoload :Core
    autoload :Policy
    autoload :Helpers
    autoload :Auth
  end
end
