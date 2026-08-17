# frozen_string_literal: true

module Plutonium
  module Interaction
    # A persisted interaction run.
    #
    # STI base: authors subclass to define execution and failure policy, and the
    # subclass name lands in +type+. Options are JSON, so an async action costs
    # no migration.
    #
    # This class deliberately holds NO execution logic — that lives in the
    # runs executor. It is the record; the executor is the behaviour. Keeping
    # them apart is what lets the job rebuild an authorization context around
    # the work without the model knowing anything about policies.
    class Run < ActiveRecord::Base
      self.table_name = "plutonium_interaction_runs"

      STATES = %w[pending running completed failed].freeze
      IN_PROGRESS_STATES = %w[pending running].freeze
      FAILURE_POLICIES = %i[halt continue transactional].freeze

      # Failure policy, declared by subclasses via +on_failure+ and consumed by
      # the executor. A class_attribute rather than a plain class ivar so a
      # deep STI hierarchy (B < A < Run) inherits what A declared.
      class_attribute :failure_policy, instance_writer: false, default: :halt

      belongs_to :initiator, polymorphic: true
      # Nullable by design: only entity-scoped portals have a tenant. nil means
      # "no tenant", NOT "tenant unknown".
      belongs_to :scoped_entity, polymorphic: true, optional: true

      validates :state, inclusion: {in: STATES}

      scope :in_progress, -> { where(state: IN_PROGRESS_STATES) }
      scope :for_target, ->(klass) { where(target_type: klass.to_s) }

      # Declares how the executor reacts to a target failure. Rejects an unknown
      # policy at class-definition time rather than letting a typo surface as
      # surprise behaviour deep inside a background job.
      #
      # @param policy [Symbol] one of {FAILURE_POLICIES}
      # @return [void]
      def self.on_failure(policy)
        unless FAILURE_POLICIES.include?(policy)
          raise ArgumentError,
            "unknown failure policy: #{policy.inspect} (expected one of #{FAILURE_POLICIES.map(&:inspect).join(", ")})"
        end

        self.failure_policy = policy
      end

      def start! = update!(state: "running", started_at: Time.current)

      def finish! = update!(state: "completed", finished_at: Time.current)

      def fail!(message = nil)
        record_target_failure!(id: nil, message: message) if message
        update!(state: "failed", finished_at: Time.current)
      end

      def in_progress? = IN_PROGRESS_STATES.include?(state)

      # nil means INDETERMINATE, not zero: opaque work has no denominator, and
      # the progress UI renders a spinner rather than a 0% bar.
      #
      # @return [Float, nil]
      def progress_fraction
        return nil if progress_total.nil? || progress_total.zero?

        progress_done.to_f / progress_total
      end

      # Appends a failure to +errors_log+ and persists immediately, preserving
      # prior entries. It writes rather than staging because the information it
      # carries — which targets the run could not act on — must survive an early
      # return, a rescue that never reaches {#fail!}, or a caller that simply
      # forgets to save. A silently-dropped entry is indistinguishable from a
      # clean run, which is the one thing an operator must never be told.
      #
      # A nil +id+ is the RUN-LEVEL sentinel: the failure is the whole run's
      # (see {#fail!}), not one target's. Readers grouping the log by target
      # must treat nil as its own bucket rather than a target id.
      def record_target_failure!(id:, message:)
        update!(errors_log: errors_log + [{"target_id" => id, "message" => message}])
      end

      # Which shape of work this is, decided by what the subclass implements
      # rather than a mode flag — one less thing for an author to keep in sync.
      def targeted? = respond_to?(:perform_on)
    end
  end
end
