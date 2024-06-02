require "view_component"
require "dry-initializer"

require_relative "attributes"

module Plutonium
  module Ui
    # Base class for all Plutonium UI components.
    # This class inherits from `ViewComponent::Base` and includes additional functionality
    # provided by `Dry::Initializer` for managing component options, and the
    # `Plutonium::Ui::Attributes` module for handling UI attributes.
    #
    # It also includes `Plutonium::Helpers::ComponentHelper` for additional helper methods
    # and delegates missing methods to the Rails helpers.
    class Base < ViewComponent::Base
      extend Dry::Initializer
      include Plutonium::Helpers::ComponentHelper
      include Plutonium::Ui::Attributes

      delegate_missing_to :helpers

      private

      # Renders an icon using the Plutonium Icons library.
      #
      # @param icon [Symbol, String] The name or identifier of the icon to render.
      # @return [String] The HTML-safe string for the rendered icon.
      def render_icon(icon, **)
        Plutonium::Icons.render(icon, **)
      end
    end
  end
end

# Require all component files within the same directory and subdirectories
Dir.glob(File.expand_path("**/*.rb", __dir__)) do |component|
  load component unless component == __FILE__
end
