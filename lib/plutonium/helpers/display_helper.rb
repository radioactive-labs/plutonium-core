module Plutonium
  module Helpers
    module DisplayHelper
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

      def display_field(value:, helper: nil, **options)
        return "-" unless value.present?

        stack_multiple = options.key?(:stack_multiple) ? options.delete(:stack_multiple) : helper != :display_name_of

        # clean options list
        options.select! { |k, _v| !k.starts_with? "pu_" }

        if value.respond_to?(:each) && stack_multiple
          tag.ul class: "list-unstyled m-0" do
            value.each do |val|
              rendered = display_field_value(value: val, helper:, **options)
              concat tag.li(rendered)
            end
          end
        else
          rendered = display_field_value(value:, helper:, **options)
          tag.span rendered
        end
      end

      def display_datetime_value(value)
        timeago value
      end

      def display_field_value(value:, helper: nil, title: nil, **)
        title = (title != false) ? title || display_name_of(value) : nil
        rendered = helper.present? ? send(helper, value, **) : value
        tag.span rendered, title:
      end

      def display_association_value(association)
        display_name = display_name_of(association)
        link_to display_name, resource_url_for(association, parent: nil),
          class: "font-medium text-primary-600 dark:text-primary-500"
      rescue NoMethodError
        display_name
      end

      def display_numeric_value(value)
        number_with_delimiter value
      end

      def display_boolean_value(value)
        tag.input type: :checkbox, class: "form-check-input", checked: value, disabled: true
      end

      def display_url_value(value)
        link_to nil, value, class: "font-medium text-primary-600 dark:text-primary-500", target: :blank
      end

      def display_name_of(obj, separator: ", ")
        return unless obj.present?

        # If this is an array, display for each
        return obj.map { |i| display_name_of i, separator: }.join(separator) if obj.is_a? Array

        # Fallback to retrieving the value from a predefined list
        %i[to_label name title].each do |method|
          name = obj.send(method) if obj.respond_to?(method)
          return name if name.present?
        end

        # Maybe this is a record?
        return "#{resource_name(obj.class)} ##{obj.id}" if obj.respond_to?(:id)

        # Oh well. Just convert it to a string.
        obj.to_s
      end

      def display_clamped_quill(value)
        clamp_content quill(value)
      end

      def display_attachment_value(value, **, &)
        attachment_preview(value, **, &)
      end
    end
  end
end
