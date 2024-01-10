require "active_support"
require_relative "plutonium/version"

module Plutonium
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
