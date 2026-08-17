# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # Configuration for persisted interaction runs. Mirrors
      # Plutonium::Wizard::Configuration: `enabled` gates both the subsystem and
      # its migrations (see Plutonium::Migrations).
      class Configuration
        # @return [Boolean] whether runs (and their migrations) are enabled
        attr_accessor :enabled

        # @return [Symbol] ActiveJob queue for run jobs
        attr_accessor :queue

        def initialize
          @enabled = false
          @queue = :default
        end
      end
    end
  end
end
