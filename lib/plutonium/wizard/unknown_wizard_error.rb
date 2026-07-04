# frozen_string_literal: true

module Plutonium
  module Wizard
    # Raised when the `wizard_class` route default does not resolve to a
    # Plutonium::Wizard::Base subclass (a misconfigured mount, or a tampered
    # path parameter).
    class UnknownWizardError < StandardError; end
  end
end
