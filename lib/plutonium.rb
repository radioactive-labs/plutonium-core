require "active_support"
require_relative "plutonium/version"

module Plutonium
  extend ActiveSupport::Autoload

  class Error < StandardError; end

  def self.root
    File.expand_path("../", __dir__)
  end

  autoload :App
  autoload :Package
  autoload :Core
  autoload :Helpers
end

# Add a shorter alias
# Pu = Plutonium
