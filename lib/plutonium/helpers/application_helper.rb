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
        resource_class.model_name.human.pluralize(count)
      end

      def resource_name_plural(resource_class)
        resource_name resource_class, 2
      end
    end
  end
end
