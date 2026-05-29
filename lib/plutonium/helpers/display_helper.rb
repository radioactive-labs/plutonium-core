module Plutonium
  module Helpers
    module DisplayHelper
      def resource_name(resource_class, count = 1)
        resource_class.model_name.human.pluralize(count)
      end

      def resource_name_plural(resource_class)
        resource_name resource_class, 2
      end

      # Returns the appropriate label for a resource (singular for singular resources, plural otherwise)
      def resource_label(resource_class)
        is_singular = current_engine.routes.singular_resource_route?(resource_class.model_name.plural)
        resource_name(resource_class, is_singular ? 1 : 2)
      end

      # Returns a human-readable name for a nested collection using the association name.
      # Falls back to resource_name_plural if not in a nested context.
      # Uses I18n via human_attribute_name for proper localization.
      # e.g., "Authored Comments" for has_many :authored_comments
      def nestable_resource_name_plural(resource_class)
        if current_parent && current_nested_association
          current_parent.class.human_attribute_name(current_nested_association).titleize
        else
          resource_name_plural(resource_class)
        end
      end

      def display_datetime_value(value)
        timeago value
      end

      def display_name_of(obj, separator: ", ")
        return unless obj.present?

        # If this is an array, display for each
        return obj.map { |i| display_name_of i, separator: }.join(separator) if obj.is_a? Array

        # Fallback to retrieving the value from a predefined list
        %i[to_label name title].each do |method|
          name = obj.public_send(method) if obj.respond_to?(method)
          return name if name.present?
        end

        # Maybe this is a record?
        return "#{resource_name(obj.class)} ##{obj.id}" if obj.respond_to?(:id)

        # Oh well. Just convert it to a string.
        obj.to_s
      end
    end
  end
end
