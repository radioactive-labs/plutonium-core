module Plutonium
  module Helpers
    module ApplicationHelper
      # def tooltip(text)
      #   text = sanitize text
      #   "title=\"#{text}\" data-controller=\"tooltip\" data-bs-title=\"#{text}\"".html_safe
      # end

      def resource_name(resource_class, count = 1)
        resource_class.model_name.human.pluralize(count)
      end

      def resource_name_plural(resource_class)
        resource_name resource_class, 2
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
