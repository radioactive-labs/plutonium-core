require "active_support"
require "active_model"

module Plutonium
  module Config
    mattr_accessor :logo
    @@logo = "plutonium-logo.png"
  end
end
