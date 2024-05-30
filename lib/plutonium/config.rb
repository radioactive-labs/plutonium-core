require "active_support"
require "active_model"

module Plutonium
  module Config
    mattr_accessor :stylesheet_tag
    @@stylesheet_tag = ->(view_context) {
      "<link rel=\"stylesheet\" href=\"#{Plutonium.stylesheet_link}\" data-turbo-track=\"reload\" />".html_safe
    }

    mattr_accessor :script_tag
    @@script_tag = ->(view_context) {
      "<script src=\"#{Plutonium.script_link}\" data-turbo-track=\"reload\"></script>".html_safe
    }

    mattr_accessor :favicon_tag
    @@favicon_tag = ->(view_context) {
      "<link rel=\"icon\" type=\"image/x-icon\" href=\"#{Plutonium.favicon_link}\">".html_safe
    }

    mattr_accessor :logo_tag
    @@logo_tag = ->(view_context, classname:) {
      "<img src=\"#{Plutonium.logo_link}\" class=\"#{classname}\" alt=\"#{Plutonium.application_name} Logo\" />".html_safe
    }
  end
end
