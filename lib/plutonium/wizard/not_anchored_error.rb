# frozen_string_literal: true

module Plutonium
  module Wizard
    # Raised when a wizard requires an anchor record but none is available.
    class NotAnchoredError < StandardError; end
  end
end
