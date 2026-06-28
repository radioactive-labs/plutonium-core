# frozen_string_literal: true

module Plutonium
  module Wizard
    # Raised when a wizard requires an anchor record but none is available.
    class NotAnchoredError < StandardError; end

    # Raised when the `wizard_class` route default does not resolve to a
    # Plutonium::Wizard::Base subclass (a misconfigured mount, or a tampered
    # path parameter).
    class UnknownWizardError < StandardError; end

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
