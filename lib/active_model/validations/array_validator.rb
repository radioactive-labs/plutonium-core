# frozen_string_literal: true

# Based on https://gist.github.com/ssimeonov/6519423
#
# Validates the values of an Array with other validators.
# Generates error messages that include the index and value of
# invalid elements.
#
# Example:
#
#   validates :values, array: { presence: true, inclusion: { in: %w{ big small } } }
#
module ActiveModel
  module Validations
    class ArrayValidator < EachValidator
      attr_reader :record, :attribute, :proxy_attribute

      def validate_each(record, attribute, values)
        @record = record
        @attribute = attribute

        # Cache any existing errors temporarily.
        @existing_errors = record.errors.delete(attribute) || []

        # Run validations
        validate_each_internal values

        # Restore any existing errors.
        return if @existing_errors.blank?

        @existing_errors.each { |e| record.errors.add attribute, e }
      end

      private

      def validate_each_internal(values)
        [values].flatten.each_with_index do |value, index|
          options.except(:if, :unless, :on, :strict).each do |key, args|
            validator_options = { attributes: attribute }
            validator_options.merge!(args) if args.is_a?(Hash)

            next if skip? value, validator_options

            validator = validator_class_for(key).new(validator_options)
            validator.validate_each(record, attribute, value)
          end
          maybe_normalize_errors index
        end
      end

      def maybe_normalize_errors(index)
        errors = record.errors.delete attribute
        return if errors.nil?

        @existing_errors += errors.map { |e| "item #{index + 1} #{e}" }
      end

      def skip?(value, validator_options)
        return true if value.nil? && validator_options[:allow_nil]

        true if value.blank? && validator_options[:allow_blank]
      end

      def validator_class_for(key)
        validator_class_name = "#{key.to_s.camelize}Validator"
        begin
          validator_class_name.constantize
        rescue NameError
          "ActiveModel::Validations::#{validator_class_name}".constantize
        end
      end
    end
  end
end
