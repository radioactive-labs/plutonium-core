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

      # @return [Boolean] encrypt every wizard's staged `data` at rest by default.
      #   Off by default because it needs ActiveRecord encryption keys configured;
      #   a wizard may still opt in (`encrypt_data`) or out (`encrypt_data false`)
      #   individually regardless of this default.
      attr_accessor :encrypt_data

      # Initialize a new wizard Configuration instance with default values.
      def initialize
        @enabled = false
        @cleanup_after = 14.days
        @database = :primary
        @encrypt_data = false
      end
    end
  end
end
