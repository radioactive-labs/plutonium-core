module Plutonium
  module Helpers
    module ApplicationHelper
      # def tooltip(text)
      #   text = sanitize text
      #   "title=\"#{text}\" data-controller=\"tooltip\" data-bs-title=\"#{text}\"".html_safe
      # end

      def page_title(title)
        [title.presence, Rails.application.class.module_parent.name].compact.join(" | ")
      end

      def resource_name(resource_class, count = 1)
        resource_class.to_s.demodulize.pluralize(count).titleize
      end

      def resource_name_plural(resource_class)
        resource_name resource_class, 2
      end

      def attribute_name(_resource_class, name)
        name.to_s.titleize
      end
    end
  end
end
