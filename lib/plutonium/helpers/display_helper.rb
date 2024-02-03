module Plutonium
  module Helpers
    module DisplayHelper
      def display_field(value:, helper: nil, **options)
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
        title = (title != false) ? title || value : nil
        rendered = helper.present? ? send(helper, value, **) : value
        tag.span rendered, title:
      end

      def display_association_value(association)
        link_to display_name_of(association), adapt_route_args(association, use_parent: false),
          class: "text-decoration-none"
      end

      def display_numeric_value(value)
        number_with_delimiter value
      end

      def display_boolean_value(value)
        tag.input type: :checkbox, class: "form-check-input", checked: value, disabled: true
      end

      def display_url_value(value)
        link_to nil, value, class: "text-decoration-none", target: :blank
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

      def display_attachment_value(value, **, &block)
        attachment_preview(value, **, &block)
      end
    end
  end
end
