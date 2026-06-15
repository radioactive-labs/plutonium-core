# frozen_string_literal: true

module Plutonium
  module Wizard
    # Configuration for the Plutonium wizard subsystem.
    #
    # Exposed via {Plutonium::Configuration#wizards}.
    class Configuration
      # @return [Boolean] whether the wizard subsystem (and its migrations) is enabled
      attr_accessor :enabled

      # @return [ActiveSupport::Duration] how long completed/abandoned sessions are kept
      attr_accessor :cleanup_after

      # @return [Symbol] which database wizard tables live in
      attr_accessor :database

      # Initialize a new wizard Configuration instance with default values.
      def initialize
        @enabled = false
        @cleanup_after = 30.days
        @database = :primary
      end
    end
  end
end
