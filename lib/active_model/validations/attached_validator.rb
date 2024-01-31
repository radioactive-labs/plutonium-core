# frozen_string_literal: true

module ActiveModel
  module Validations
    # Validates that a file is attached
    #
    # Example:
    #
    #   validates :logo, attached: true
    #
    class AttachedValidator < EachValidator
      def validate_each(record, attribute, value)
        record.errors.add(attribute, (options[:message] || "must be attached")) unless value.attached?
      end
    end
  end
end
