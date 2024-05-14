require "active_support"
require "active_model"

module Plutonium
  module Config
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
