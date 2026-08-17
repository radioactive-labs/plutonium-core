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
      # Before the belongs_to declarations below: Record::Associations decorates
      # belongs_to/has_many to generate the sgid accessors, so an association
      # declared above the include gets none. It is also what makes a run
      # registerable as a resource — Resource::Register refuses anything that
      # does not include this.
      include Plutonium::Resource::Record

      self.table_name = "plutonium_interaction_runs"

      STATES = %w[pending running completed failed].freeze
      IN_PROGRESS_STATES = %w[pending running].freeze
      FAILURE_POLICIES = %i[halt continue transactional].freeze

      # Routes, paths and helpers are all derived from model_name, and the
      # default would spell the gem's own namespace out in every URL
      # (/admin/plutonium/interaction/runs) and every helper
      # (plutonium_interaction_run_path). Pinned to the BASE class rather than
      # +self+ so every STI subclass routes to the one registered resource:
      # resource_url_for(a TestPostRun) has to find the Run's route config.
      MODEL_NAME = ActiveModel::Name.new(self, nil, "InteractionRun")

      def self.model_name = MODEL_NAME

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

      # Overrides the generic scope Record::AssociatedWith installs, which
      # resolves a tenant by walking reflections. Both of this table's links to
      # a tenant are POLYMORPHIC, and that walk skips polymorphic associations
      # (it cannot know the class) — so the generic version raises
      # "could not resolve the association" for every host tenant model.
      #
      # The tenant a run belongs to is not a fact about the object graph anyway:
      # it is the scope the run was DISPATCHED in, recorded on the row. Reading
      # it from the row is what makes the tenant filter mean the same thing here
      # as it did at dispatch, for any host tenant model, with no host-side
      # scope to define.
      #
      # A nil scoped_entity is therefore excluded from every tenant, which is
      # the correct direction: nil means "dispatched outside any tenant", so it
      # belongs to none of them.
      scope :associated_with, ->(entity) { where(scoped_entity: entity) }

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

      # What actually happened, as opposed to how the executor exited.
      #
      # A :continue run that could not apply some of its targets ends as
      # +completed+ (see Runs::Executor#perform_targets) — the author declared
      # partial application acceptable and the loop ran to the end. But
      # "completed" on its own is what a clean success looks like, so rendering
      # it alone would make a run that under-applied indistinguishable from one
      # that did everything asked of it. Every reader — badge, table column,
      # progress panel — goes through this instead of through +state+.
      #
      # @return [String]
      def outcome
        (state == "completed" && errors_log.any?) ? "completed_with_errors" : state
      end

      # @return [Integer] recorded target failures, run-level entries included
      def error_count = errors_log.size

      # Runs have no name or title, so Labeling would fall back to
      # "Interaction run #12" — true but silent about the only thing that
      # distinguishes one row from the next.
      # Demodulized: a host's run class is as likely to be
      # Billing::ReissueInvoicesRun as a top-level one, and the namespace adds
      # nothing to a label that already sits under the run's own breadcrumb.
      def to_label = "#{self.class.name.demodulize.titleize} ##{to_param}"

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
        record_target_failures!([{id: id, message: message}])
      end

      # Appends several failures in ONE write.
      #
      # The singular form persists on every call, so a loop over M ids is M
      # writes, each rewriting the whole errors_log JSON — O(M²) bytes. The
      # executor resolves every unavailable target in one pass before it performs
      # anything (see Runs::Executor#record_unresolved), and that batch is what
      # this exists for.
      #
      # @param entries [Array<Hash>] +{id:, message:}+ pairs
      def record_target_failures!(entries)
        return if entries.empty?

        appended = entries.map { |entry| {"target_id" => entry[:id], "message" => entry[:message]} }
        update!(errors_log: errors_log + appended)
      end

      # Which shape of work this is, decided by what the subclass implements
      # rather than a mode flag — one less thing for an author to keep in sync.
      def targeted? = respond_to?(:perform_on)

      # Opaque (untargeted) work. Subclasses override this, or +perform_on+ for
      # per-target work.
      #
      # Defined here so a subclass that implements NEITHER is diagnosed by name
      # rather than surfacing as a NoMethodError from inside the executor's loop,
      # where nothing in the message says which class is at fault.
      def perform
        raise NotImplementedError,
          "#{self.class} implements neither #perform nor #perform_on: define " \
          "#perform_on(record) for work over targets, or #perform for opaque work"
      end
    end
  end
end
