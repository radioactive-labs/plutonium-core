# frozen_string_literal: true

module Plutonium
  module StructuredInputs
    # Normalises an extracted structured-input value before it is stored.
    #
    # The form's `extract_input` already yields a `Hash` (single) or an
    # `Array<Hash>` (repeater), so the only work left is to symbolise keys and,
    # for repeaters, drop rows the user left entirely blank.
    module ParamCleaner
      module_function

      # @param value [Hash, Array, nil] the extracted param for this input
      # @param repeat [Boolean, Integer] truthy => array (repeater), else hash
      # @return [Hash, Array<Hash>]
      def call(value, repeat:)
        repeat ? clean_collection(value) : clean_one(value)
      end

      def clean_one(value)
        value.is_a?(Hash) ? symbolize(value) : {}
      end

      def clean_collection(value)
        Array(value)
          .select { |row| row.is_a?(Hash) }
          .map { |row| symbolize(row) }
          .reject { |row| row.values.all? { |v| v.to_s.strip.empty? } }
      end

      def symbolize(row)
        row.to_h.transform_keys(&:to_sym)
      end
    end
  end
end
