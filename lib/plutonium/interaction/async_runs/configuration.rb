# frozen_string_literal: true

module Plutonium
  module Interaction
    module AsyncRuns
      # Configuration for persisted interaction runs. Mirrors
      # Plutonium::Wizard::Configuration: `enabled` gates both the subsystem and
      # its migrations (see Plutonium::Migrations).
      class Configuration
        # @return [Boolean] whether runs (and their migrations) are enabled
        attr_accessor :enabled

        # @return [Symbol] ActiveJob queue for run jobs
        attr_accessor :queue

        # @return [ActiveSupport::Duration] how long a run may sit with no
        #   progress write before ReapJob considers it stalled
        attr_accessor :stall_after

        def initialize
          @enabled = false
          @queue = :default
          @stall_after = 1.hour
        end
      end
    end
  end
end
