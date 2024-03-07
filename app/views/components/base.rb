require "view_component"
require "dry-initializer"

module Plutonium::UI
  class Base < ViewComponent::Base
    extend Dry::Initializer
    include Plutonium::Helpers::ComponentHelper
  end
end

# Require components
Dir.glob(File.expand_path("**/*.rb", __dir__)) { |component| load component unless component == __FILE__ }
