require "view_component"
require "dry-initializer"
require "active_support/notifications"

load File.join(__dir__, "attributes.rb")

module PlutoniumUi
  # Base class for all Plutonium UI components.
  # This class inherits from `ViewComponent::Base` and includes additional functionality
  # provided by `Dry::Initializer` for managing component options, and the
  # `PlutoniumUi::Attributes` module for handling UI attributes.
  #
  # It also includes `Plutonium::Helpers::ComponentHelper` for additional helper methods
  # and delegates missing methods to the Rails helpers.
  class Base < ViewComponent::Base
    extend Dry::Initializer
    include Plutonium::Helpers::ComponentHelper
    include PlutoniumUi::Attributes

    delegate_missing_to :helpers
  end
end

ActiveSupport::Notifications.instrument("plutonium.components.load") do
  # Require all component files within the same directory and subdirectories
  Dir.glob(File.expand_path("**/*.rb", __dir__)) do |component_file_path|
    load component_file_path unless component_file_path == __FILE__
  end
end
