module Plutonium
  module UI
    class Input
      attr_reader :name, :options

      def initialize(name, **options)
        @name = name
        @options = options
      end

      def self.build(name, type:, **options)
        multiple = options[:multiple]

        definition = {}
        case type
        when :string, :text, :citext
          definition = {
            input_html: {
              data: {controller: "textarea-autogrow"}
            }
          }
        when :datetime, :timestamp, :time, :date
          definition = {
            html5: true
          }
        when :slim_select
          definition = {
            wrapper: :slim_select,
            input_html: {multiple:}
          }

          if multiple
            placeholder = options[:placeholder] || "Select #{name.to_s.humanize(capitalize: false).pluralize}"
            definition.deep_merge! input_html: {
              data: {
                slim_select_placeholder_value: placeholder,
                slim_select_close_on_select_value: false
              }
            }
          else
            placeholder = options[:placeholder] || "Select #{name.to_s.humanize(capitalize: false)}"
            definition.deep_merge! include_blank: placeholder,
              input_html: {
                data: {slim_select_allow_deselect_value: true}
              }
          end
        when :quill
          definition = {wrapper: :quill}
        when :money
          currency = options.delete(:currency) || "$"
          definition = {wrapper: :input_group, prepend: currency}
        when :attachment
          type = :file
          definition = {
            input_html: {multiple:},
            attachment: true,
            direct_upload: true
          }
        end

        options = definition.deep_merge options

        new name, **options
      end

      def self.for_attribute(model_class, name, type: nil, **options)
        column = model_class.column_for_attribute name if model_class.respond_to? :column_for_attribute
        if model_class.respond_to? :reflect_on_association
          attachment = model_class.reflect_on_association(:"#{name}_attachment") || model_class.reflect_on_association(:"#{name}_attachments")
        end

        type ||= :slim_select if options.key? :collection

        if attachment.present?
          type ||= :attachment
          options[:multiple] = true if options[:multiple].nil? && attachment.macro == :has_many
        elsif column.present?
          type ||= column.type
          options[:multiple] = column.array? if options[:multiple].nil? && column.respond_to?(:array?)
        end

        build name, type:, **options
      end
    end
  end
end
