# frozen_string_literal: true

module Plutonium
  module Interaction
    module Async
      # Configuration for async interactions. Mirrors
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

        # @return [Symbol, nil] the storage backend used to stage an attachment
        #   attribute into the run's options — `:active_storage` or `:shrine`.
        #   `nil` falls back to `config.attachment_backend`, then to auto-detection.
        #
        #   A file cannot ride the options column: it is JSON, and the request's
        #   tempfile is gone by the time the job runs. So an attachment attribute is
        #   uploaded to the backend's cache at dispatch and carried as its token.
        #   This is the knob for which backend does that, for runs alone.
        attr_accessor :attachment_backend

        def initialize
          @enabled = false
          @queue = :default
          @stall_after = 1.hour
        end
      end
    end
  end
end
