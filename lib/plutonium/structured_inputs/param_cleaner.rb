# frozen_string_literal: true

module Plutonium
  module StructuredInputs
    # Turns submitted structured-input params into the stored value.
    module ParamCleaner
      DESTROY_VALUES = [1, "1", true, "true"].freeze

      module_function

      # @param value [Hash, Array, nil] the extracted param for this input
      # @param repeat [Boolean, Integer] truthy => array (repeater), else hash
      # @return [Hash, Array<Hash>]
      def call(value, repeat:)
        repeat ? clean_collection(value) : clean_one(value)
      end

      def clean_one(value)
        return {} unless value.is_a?(Hash)
        strip(value)
      end

      def clean_collection(value)
        rows = value.is_a?(Hash) ? value.values : Array(value)
        rows
          .filter_map { |row| row.is_a?(Hash) ? row : nil }
          .reject { |row| destroy?(row) }
          .map { |row| strip(row) }
          .reject { |row| row.values.all? { |v| v.to_s.strip.empty? } }
      end

      def destroy?(row)
        DESTROY_VALUES.include?(row[:_destroy] || row["_destroy"])
      end

      # Drop _destroy and symbolize keys.
      def strip(row)
        row.to_h.except(:_destroy, "_destroy").transform_keys(&:to_sym)
      end
    end
  end
end
