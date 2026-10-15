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

        # @return [Integer] how many pre_check rejections a run stores. The rest
        #   are counted and reported as one "and N more" entry, so a file that is
        #   bad on every row cannot write tens of thousands of entries into the
        #   errors_log column (and onto the progress page). Must be a positive Integer.
        attr_accessor :max_rejections

        # @return [ActiveSupport::Duration] how long a run stays in the running
        #   banner after it finishes, for the user who started it. A dispatch
        #   sends that user back to the index, and a short run (or one its
        #   pre_check rejected) settles before the page loads; without this it
        #   would never show there at all.
        attr_accessor :recent_runs_window

        def initialize
          @enabled = false
          @queue = :default
          @stall_after = 1.hour
          @max_rejections = 100
          @recent_runs_window = 10.minutes
        end
      end
    end
  end
end
