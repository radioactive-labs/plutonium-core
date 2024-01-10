# frozen_string_literal: true

# Validates that a file is attached
#
# Example:
#
#   validates :logo, attached: true
#
module ActiveModel
  module Validations
    class AttachedValidator < EachValidator
      def validate_each(record, attribute, value)
        record.errors.add(attribute, (options[:message] || 'must be attached')) unless value.attached?
      end
    end
  end
end
