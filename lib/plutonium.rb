require "active_support"
require_relative "plutonium/version"

module Plutonium
  require_relative "active_model/validations/array_validator"
  require_relative "active_model/validations/attached_validator"
  require_relative "active_model/validations/url_validator"

  extend ActiveSupport::Autoload

  class Error < StandardError; end

  def self.root
    File.expand_path("../", __dir__)
  end

  def self.lib_root
    File.expand_path("lib/plutonium/", root)
  end


  autoload :App
  autoload :Package
  autoload :Core
  # autoload :Policy
  # autoload :Helpers
  # autoload :Builders
  autoload :SimpleForm
end

# Add a shorter alias
# Pu = Plutonium
