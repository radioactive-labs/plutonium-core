require "simple_form"

module Plutonium::UI
  class FormBuilder < SimpleForm::FormBuilder
    def input(attribute_name, options = {}, &block)
      label_class = options.dig(:label_html, :class)
      if object.errors[attribute_name].present?
        # Don't show the hint
        options.delete(:hint)
        # Apply error class if there are errors
        label_class = [label_class, "block mb-2 text-sm font-medium text-red-700 dark:text-red-500"].compact.join(" ")
      elsif object.persisted? || !object.errors.empty?
        # Apply success class if the object is persisted, has been validated (errors are not empty), and the field has no errors
        label_class = [label_class, "block mb-2 text-sm font-medium text-green-700 dark:text-green-500"].compact.join(" ")
      end

      options[:label_html] ||= {}
      options[:label_html][:class] = label_class

      super(attribute_name, options, &block)
    end

    def hint(...)
      return if object.errors[attribute_name].present?

      super(...)
    end

    def error_notification(options = {})
      translate_error_notification = lambda {
        lookups = []
        lookups << :"#{object_name}"
        lookups << :default_message
        lookups << "Please review the problems below:"
        I18n.t(lookups.shift, scope: :"simple_form.error_notification", default: lookups)
      }

      (options.delete(:message) || translate_error_notification.call).html_safe
    end
  end
end
