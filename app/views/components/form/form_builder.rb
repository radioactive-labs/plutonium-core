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
      # Overriding this because we want an unstyled error notification
      translate_error_notification = lambda {
        lookups = []
        lookups << :"#{object_name}"
        lookups << :default_message
        lookups << "Please review the problems below:"
        I18n.t(lookups.shift, scope: :"plutonium.error_notification", default: lookups)
      }

      (options.delete(:message) || translate_error_notification.call).html_safe
    end

    def submit_default_value
      object = convert_to_model(@object)
      key = if object
        object.persisted? ? :update : :create
      else
        :submit
      end

      model = if object.respond_to?(:model_name)
        object.model_name.human
      else
        @object_name.to_s.humanize
      end

      defaults = []
      # Object is a model and it is not overwritten by as and scope option.
      defaults << if object.respond_to?(:model_name) && object_name.to_s == model.downcase
        :"helpers.submit.#{object.model_name.i18n_key}.#{key}"
      else
        :"helpers.submit.#{object_name}.#{key}"
      end
      defaults << :"helpers.submit.#{key}"
      defaults << "#{key.to_s.humanize} #{model}"

      I18n.t(defaults.shift, model: model, default: defaults)
    end
  end
end
