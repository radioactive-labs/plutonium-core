# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module Serializer
      private

      def serialize_value(value)
        case value
        when Symbol
          ":#{value}"
        when String
          serialize_string value
        when Integer, Float, BigDecimal
          serialize_number value
        when Enumerable
          serialize_enumerable value
        when nil
          "nil"
        else
          # debug "Unable to serialize a value '#{value}:#{value.class}'"
          value
        end
      end

      def serialize_string(value)
        "'#{value.gsub("'", "\\\\'")}'"
      end

      def serialize_number(num)
        num.to_s.gsub(/(\d)(?=(\d\d\d)+(?!\d))/, '\\1_')
      end

      def serialize_enumerable(enum)
        "[#{enum.entries.map { |val| serialize_value val }.join ", "}]"
      end
    end
  end
end
