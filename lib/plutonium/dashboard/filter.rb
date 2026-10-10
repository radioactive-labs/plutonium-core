# frozen_string_literal: true

module Plutonium
  module Dashboard
    # A page-level control every card reads, declared with `filter`. Its value
    # comes from the request's query string under the filter's key, and a value
    # that is not one of the choices reads as the default, so a hand-edited URL
    # can never reach a card block.
    class Filter
      attr_reader :key, :choices, :default

      # @param choices [Hash{#to_s => String}] value => label, in display order
      # @param default [#to_s, nil] one of the choices; the first when nil
      def initialize(key, choices:, default: nil, label: nil)
        @key = key.to_sym
        @choices = choices.to_h.transform_keys(&:to_s).freeze
        raise ArgumentError, "filter #{@key.inspect}: choices must not be empty" if @choices.empty?

        @default = (default.nil? ? @choices.keys.first : default.to_s)
        unless @choices.key?(@default)
          raise ArgumentError, "filter #{@key.inspect}: default #{default.inspect} is not one of #{@choices.keys.inspect}"
        end

        @label = label
      end

      # The control's accessible name.
      def label
        Plutonium::Translation.resolve(@label) || key.to_s.humanize
      end

      # The chosen value for this request.
      def value_from(params)
        value = params[key].to_s
        choices.key?(value) ? value : default
      end
    end
  end
end
