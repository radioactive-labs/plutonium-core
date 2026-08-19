# frozen_string_literal: true

module Plutonium
  module Interaction
    module Async
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

        self.table_name = "plutonium_async_runs"

        STATES = %w[pending running completed failed].freeze
        IN_PROGRESS_STATES = %w[pending running].freeze
        FAILURE_POLICIES = %i[halt continue transactional].freeze

        # Routes, paths and helpers are all derived from model_name, and the
        # default would spell the gem's own namespace out in every URL
        # (/admin/plutonium/interaction/runs) and every helper
        # (plutonium_async_run_path). Pinned to the BASE class rather than
        # +self+ so every STI subclass routes to the one registered resource:
        # resource_url_for(a TestPostRun) has to find the Run's route config.
        #
        # "Run" rather than the shorter "Run" on purpose: a bare "Run"
        # would squat the most generic name available and collide silently with a
        # host app's own Run model (CI runs, ML training runs, delivery runs) on
        # every axis that matters -- route path, controller name, param_key and
        # i18n key are all identical, and nothing in Resource::Register detects it.
        MODEL_NAME = ActiveModel::Name.new(self, nil, "AsyncRun")

        def self.model_name = MODEL_NAME

        # Failure policy, declared by subclasses via +on_failure+ and consumed by
        # the executor. A class_attribute rather than a plain class ivar so a
        # deep STI hierarchy (B < A < Run) inherits what A declared.
        class_attribute :failure_policy, instance_writer: false, default: :halt

        belongs_to :initiator, polymorphic: true
        # The nested-route parent, present only for a dispatch from a nested
        # route. Paired with +parent_association+; see the migration.
        belongs_to :parent, polymorphic: true, optional: true
        # Nullable by design: only entity-scoped portals have a tenant. nil means
        # "no tenant", NOT "tenant unknown".
        belongs_to :scoped_entity, polymorphic: true, optional: true

        validates :state, inclusion: {in: STATES}

        # Guarantees its own job gets enqueued once this row is durably visible
        # (same shape as InviteToken#send_invitation_email) — not done by the
        # caller, which would race a fast/inline job adapter against the commit.
        after_commit :enqueue_job, on: :create

        scope :in_progress, -> { where(state: IN_PROGRESS_STATES) }
        scope :for_target, ->(klass) { where(target_type: klass.to_s) }

        # In progress with no recorded activity since +before+ — see
        # Async::ReapJob. +last_activity_at+ is nil until a job actually claims
        # the run (see Async::Executor#claim!), so a run never picked up at all
        # falls back to +created_at+ — otherwise it would never match and a
        # dropped enqueue would sit "pending" forever, unreapable.
        scope :stalled, ->(before:) {
          in_progress.where("COALESCE(last_activity_at, created_at) < ?", before)
        }

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

        def start! = update!(state: "running", started_at: Time.current, last_activity_at: Time.current)

        def finish! = update!(state: "completed", finished_at: Time.current, last_activity_at: Time.current)

        def fail!(message = nil)
          record_target_failure!(id: nil, message: message) if message
          update!(state: "failed", finished_at: Time.current, last_activity_at: Time.current)
        end

        def in_progress? = IN_PROGRESS_STATES.include?(state)

        # What actually happened, as opposed to how the executor exited.
        #
        # A :continue run that could not apply some of its targets ends as
        # +completed+ (see Async::Executor#perform_targets) — the author declared
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

        # Human, I18n-aware name of the target resource class — "Post", not
        # "Blogging::Post" — for display (see Async::RunDefinition). Falls back to the
        # raw string for a target_type renamed/removed since this run was
        # dispatched, rather than raising on an old row. nil for opaque
        # (untargeted) work.
        #
        # @return [String, nil]
        def target_label
          return nil if target_type.nil?

          target_type.constantize.model_name.human
        rescue NameError
          target_type
        end

        # Runs have no name or title, so Labeling would fall back to
        # "Async run #12" — true but silent about the only thing that
        # distinguishes one row from the next.
        #
        # Demodulized: a host's run class is as likely to be
        # Billing::ReissueInvoicesRun as a top-level one, and the namespace adds
        # nothing to a label that already sits under the run's own breadcrumb.
        #
        # Except when demodulizing is what throws the name away. A run declared
        # by Dispatchable#async is Blogging::ArchivePosts::Run, and every
        # one of them would render "Run #12" — the failure mode this method
        # exists to avoid, reintroduced for the shape most authors will write.
        # For those, the enclosing segment IS the name, so it is folded back in.
        #
        # @return [String]
        def to_label
          parts = self.class.name.split("::")
          name = (parts.last == "Run" && parts.size > 1) ? "#{parts[-2]}Run" : parts.last
          "#{name.titleize} ##{to_param}"
        end

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
        # (see {#fail!}), not one target's — it advances neither progress_done
        # nor handled_target_ids. Readers grouping the log by target must treat
        # nil as its own bucket rather than a target id.
        def record_target_failure!(id:, message:)
          record_target_failures!([{id: id, message: message}])
        end

        # Appends several failures in ONE write — folding in the progress bump
        # and handled_target_ids for every entry that names a real target, so a
        # crash between separate writes can't leave them out of sync with each
        # other.
        #
        # The singular form persists on every call, so a loop over M ids is M
        # writes, each rewriting the whole errors_log JSON — O(M²) bytes. The
        # executor resolves every unavailable target in one pass before it
        # performs anything (see Async::Executor#record_unresolved), and that
        # batch is what this exists for.
        #
        # @param entries [Array<Hash>] +{id:, message:}+ pairs
        def record_target_failures!(entries)
          return if entries.empty?

          target_entries = entries.reject { |entry| entry[:id].nil? }
          appended = entries.map { |entry| {"target_id" => entry[:id], "message" => entry[:message]} }
          update!(
            errors_log: errors_log + appended,
            progress_done: progress_done + target_entries.size,
            handled_target_ids: handled_target_ids + target_entries.map { |entry| entry[:id].to_s },
            last_activity_at: Time.current
          )
        end

        # Target ids not yet dispositioned — what a resumed run still has to
        # do. See {#record_target_failures!} and Async::Executor#advance!, which
        # are what populate handled_target_ids.
        #
        # @return [Array]
        def unhandled_target_ids
          handled = handled_target_ids.map(&:to_s).to_set
          target_ids.reject { |id| handled.include?(id.to_s) }
        end

        # The interaction's validated inputs, with the types dispatch put in.
        #
        # The column is JSON, so Dispatchable#dispatch_options writes it through
        # ActiveJob::Arguments; this is the other half. Without it a Date comes
        # back a String and a BigDecimal comes back a String, which is the kind of
        # bug that survives every test written against a run whose options happen
        # to be strings anyway.
        #
        # Falls back to the raw hash for a row written before this existed, and
        # for one an operator edited by hand — neither carries the envelope keys
        # deserialize expects, and refusing to read them would take out the
        # progress page as well as the work.
        #
        # @return [Hash]
        def options
          raw = super
          return raw unless raw.is_a?(Hash)

          ::ActiveJob::Arguments.deserialize([raw]).first
        rescue ::ActiveJob::DeserializationError
          raw
        end

        # An attachment attribute, revived from the token dispatch staged.
        #
        # A file cannot ride the options column, so dispatch uploads it to the
        # backend's cache and stores the token (see
        # Dispatchable#stage_dispatch_attachments). +options["file"]+ is therefore
        # that token — a String — and this is what turns it back into something
        # with a filename and bytes.
        #
        #   async do
        #     def perform
        #       CSV.foreach(attachment(:import_file).url) { |row| ... }
        #     end
        #   end
        #
        # Deliberately not folded into +options+. The token is what is actually
        # stored, and reviving it reaches storage — which the progress page reads
        # options without wanting to do.
        #
        # @param key [Symbol, String] the attribute name
        # @return [Plutonium::Attachments::Resolved, nil] nil if nothing was
        #   staged, or the token no longer resolves
        def attachment(key) = attachments(key).first

        # Every attachment staged under +key+, for a multiple-file attribute.
        #
        # @param key [Symbol, String]
        # @return [Array<Plutonium::Attachments::Resolved>]
        def attachments(key) = Plutonium::Attachments.resolve(options[key.to_s])

        # Says "still working" — for work the executor cannot see inside.
        #
        # Async::ReapJob treats a run silent past +stall_after+ as dead and resumes
        # it. Every write the executor makes refreshes that clock, so a targeted
        # run whose targets are quick heartbeats once per target for free. Two
        # shapes of work get nothing:
        #
        # * OPAQUE work. Between the claim and {#finish!} the executor writes
        #   nothing at all, because there is nothing to count. An opaque +perform+
        #   that outlives stall_after is reaped mid-flight, and — having no
        #   handled_target_ids to resume from — is re-run FROM SCRATCH.
        # * A single +perform_on+ that outlives stall_after on its own.
        #
        # So a run that does either must say so itself. This is deliberately not
        # automatic: a background thread would have to guess how often to write,
        # and would keep reporting a wedged worker as healthy. Only the work knows
        # it is making progress.
        #
        #   def perform
        #     invoices.each_slice(500) do |slice|
        #       reissue(slice)
        #       heartbeat!
        #     end
        #   end
        #
        # It also ANSWERS: the write is conditional on this instance still holding
        # the row's lock_version, so a worker superseded while inside a long
        # +perform+ learns at its next beat rather than at the end — see
        # Async::Executor#superseded?, which turns that into "no longer mine"
        # instead of a failure. That is the only place a long opaque run can find
        # out at all.
        #
        # The beat must NOT bump lock_version — that is the executor's own record
        # it would be invalidating, making its next save! raise against a row
        # nobody else touched. Which rules out more than it looks like:
        #
        # * +touch+ and +update!+ both bump it (Locking::Optimistic hooks
        #   _touch_row as well as _update_record).
        # * so does +update_all+ GIVEN A HASH. Rails silently adds the increment
        #   when the model locks and the hash does not mention the column — see
        #   ActiveRecord::Relation#update_all. Only the string/array form escapes
        #   it, going through sanitize_sql_for_assignment untouched, which is why
        #   this and Async::Executor#claim! both spell their SQL out.
        #
        # The in-memory attribute is left alone for a related reason: nothing
        # reads it, and assigning it would put a change on the record that the
        # caller never asked to save.
        #
        # Call it on SELF, which is what +perform+/+perform_on+ already hand the
        # author. The conditional reads this instance's lock_version, and the
        # executor's own writes keep that current; a separately loaded copy
        # (Run.find(id)) goes stale at the first advance! and would raise here
        # having been superseded by nobody.
        #
        # Under the +:transactional+ policy the beat is inside the batch's
        # transaction like everything else, so it is invisible to the reaper until
        # the batch commits. An all-or-nothing batch longer than stall_after is
        # reapable no matter what this does.
        #
        # @raise [ActiveRecord::StaleObjectError] if another executor owns the run
        # @return [Time] the recorded activity time
        def heartbeat!
          now = Time.current
          written = self.class.where(id: id, lock_version: lock_version)
            .update_all(["last_activity_at = ?", now])
          raise ActiveRecord::StaleObjectError.new(self, "heartbeat") if written.zero?

          now
        end

        # Which shape of work this is, decided by what the subclass implements
        # rather than a mode flag — one less thing for an author to keep in sync.
        #
        # Non-public methods count. `private def perform_on(record)` is a natural
        # idiom for work only the executor is meant to invoke, and Ruby's
        # public-only respond_to? default would read that as opaque work — routing
        # it to #perform, which the base class raises NotImplementedError for. The
        # author would see every dispatch fail on a run whose perform_on is right
        # there. Async::Executor invokes both through send to match.
        def targeted? = respond_to?(:perform_on, true)

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

        private

        # Not swallowed: after_commit runs synchronously, so re-raising here
        # still surfaces to the dispatching request rather than leaving a
        # permanently invisible, un-enqueued ghost.
        def enqueue_job
          Plutonium::Interaction::Async::Job.perform_later(id)
        rescue
          fail!("could not be enqueued for execution")
          raise
        end
      end
    end
  end
end
