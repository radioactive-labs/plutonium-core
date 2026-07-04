# frozen_string_literal: true

module Plutonium
  module Wizard
    # Raised when a wizard step fails. Carries the attribute the error should be
    # attached to (defaults to +:base+) so it can be surfaced on a form.
    class StepError < StandardError
      # @return [Symbol] the attribute the error applies to
      attr_reader :attribute

      # @param message [String, nil] the error message
      # @param attribute [Symbol] the attribute the error applies to
      def initialize(message = nil, attribute: :base)
        @attribute = attribute
        super(message)
      end
    end
  end
end
