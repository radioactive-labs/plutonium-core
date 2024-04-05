require "active_model"

module ActiveModel
  module Validations
    # Validates that the value is a url
    #
    # Example:
    #
    #   validates :website_url, url: true
    #
    class UrlValidator < EachValidator
      URL_PATTERN = URI::DEFAULT_PARSER.make_regexp(%w[http https]).freeze

      attr_reader :record, :attribute, :value

      def validate_each(record, attribute, value)
        @record = record
        @attribute = attribute
        @value = value

        return if skip?
        return unless validate_url

        nil unless maybe_validate_image_url
      end

      private

      def skip?
        return true if value.nil? && options[:allow_nil]

        true if value.blank? && options[:allow_blank]
      end

      def validate_url
        return true if URL_PATTERN.match?(value)

        record.errors.add attribute, (options[:message] || "is not a valid URL")
        false
      end

      def maybe_validate_image_url
        return true unless options[:image].present?
        return true unless FastImage.type(value).nil?

        record.errors.add(attribute, (options[:message] || "is not a valid image URL"))
        false
      end
    end
  end
end
