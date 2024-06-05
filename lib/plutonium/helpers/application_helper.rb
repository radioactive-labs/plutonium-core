module Plutonium
  module Helpers
    module ApplicationHelper
      def application_name
        Plutonium.application_name
      end

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
