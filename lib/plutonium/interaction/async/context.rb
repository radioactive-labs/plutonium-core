# frozen_string_literal: true

module Plutonium
  module Interaction
    module Async
      # Rebuilds the authorization context a run was dispatched under, and
      # resolves the run's targets through it.
      #
      # A run performs inside an ActiveJob: no controller, no request, no
      # +current_user+. But Plutonium does not authorize on a user — it
      # authorizes on the PAIR (user, entity_scope). See
      # Plutonium::Core::Controllers::Authorizable, which registers both
      # (`authorize :user` / `authorize :entity_scope`) and whose
      # +current_policy_context+ carries the entity scope into every policy it
      # builds. Rebuilding only the user would resolve targets under the WRONG
      # TENANT, and that direction fails OPEN: a broader scope silently includes
      # records the initiator could not see when they dispatched the run.
      #
      # Nothing about what the initiator was ALLOWED to do is carried over from
      # dispatch — only who they are and which tenant they were in. Permissions
      # are re-derived here. That is deliberate: if a persisted run replayed the
      # permissions it was created with, it would be a way to launder access that
      # has since been revoked.
      #
      # == What is fresh, and when
      #
      # Be precise about this, because the guarantee is narrower than "fresh at
      # perform time" and a vaguer claim would invite exactly the bug it is meant
      # to prevent:
      #
      # * The initiator and scoped entity are loaded from the database when this
      #   object is CONSTRUCTED — so they reflect job start, not dispatch.
      # * They are then CACHED, because they are ordinary belongs_to associations.
      #   A long-running executor holding one Context therefore keeps evaluating
      #   policies against the subjects as they were at job start. A predicate
      #   reading +user.role+ or +user.active?+ will NOT see a mid-run
      #   revocation.
      # * {#refresh_subjects!} re-reads just those two, so a caller that needs a
      #   genuinely current answer can get one. It is the caller's job to decide
      #   how often; see that method.
      # * Target RECORDS are loaded per {#targets} call and are likewise a
      #   snapshot. A predicate reading record state (+record.published?+) is only
      #   as current as the record instance handed to {#permitted?}.
      #
      # == Which policy applies
      #
      # Policy lookup in a controller passes +namespace: authorization_namespace+,
      # which ActionPolicy derives from the CONTROLLER's module nesting (see
      # ActionPolicy::Behaviours::Namespaced). That is how a portal gets its own
      # policy — +StorefrontPortal::Blogging::PostPolicy+ rather than
      # +Blogging::PostPolicy+. A job has no controller, so the namespace cannot
      # be derived here; the run carries it, and lookup replays it.
      #
      # The run ALSO carries the policy that dispatch actually resolved, and this
      # class refuses to run if today's lookup disagrees with it. The namespace
      # alone only fixes lookup as the constants stand right now — a policy
      # renamed, deleted or re-parented between enqueue and perform would resolve
      # to something else, which is the same silent widening moved later in time.
      class Context
        # Raised when the stored context cannot be rebuilt. Deliberately fatal:
        # every alternative to raising here resolves targets under a context
        # that is wider than the one the run was dispatched under.
        class UnresolvableError < StandardError; end

        # Raised when the policy resolved now is not the policy dispatch
        # resolved. A subclass so a caller can rescue either the specific case or
        # every "this run cannot be trusted" case with one rescue.
        class PolicyMismatchError < UnresolvableError; end

        # Resolved targets, split three ways.
        #
        # +records+ passed BOTH checks: visible in the scope, and permitted by the
        # policy predicate. +missing_ids+ was deleted or fell out of scope.
        # +unauthorized_ids+ is still visible but the initiator may no longer act
        # on it.
        #
        # The two failure buckets are surfaced rather than swallowed, and kept
        # apart because they mean different things to an operator: "that record is
        # gone" and "you may no longer archive that record" call for different
        # responses. Silence in either is how bulk operations quietly
        # under-apply — the run reports success having touched half the records.
        Targets = Struct.new(:records, :missing_ids, :unauthorized_ids)

        attr_reader :run

        # When the two authorization subjects were last read from the database.
        #
        # Exposed because the subjects go stale (see the class comment) and only
        # the caller knows how stale is too stale — so the caller needs to be able
        # to ASK, without keeping a shadow copy of this object's state that can
        # drift from it. The cadence policy stays with the caller; the clock stays
        # with the state it describes.
        #
        # @return [Time]
        attr_reader :subjects_read_at

        def initialize(run)
          @run = run
          verify_resolvable!
          # verify_resolvable! is what loads both subjects, so the clock starts
          # once they are known good — not before.
          @subjects_read_at = Time.current
        end

        # @return [ActiveRecord::Base] the user the run authorizes as
        def initiator = run.initiator

        # @return [ActiveRecord::Base, nil] the tenant, or nil for an unscoped portal
        def scoped_entity = run.scoped_entity

        # @return [ActiveRecord::Base, nil] the nested-route parent, nil if the
        #   dispatch was not nested
        def parent = run.parent

        # @return [Symbol, nil] the association the child hangs off {#parent}
        def parent_association = run.parent_association&.to_sym

        # @return [Class, nil]
        def target_class = resolve_constant(run.target_type, "target_type")

        # The dispatching controller's ActionPolicy namespace, as a Module.
        #
        # ActionPolicy.lookup calls +namespace.name+ and walks +namespace.namespace+,
        # so it needs the Module itself — handed a String it raises NoMethodError.
        # nil is a legitimate value meaning "top level", not a missing one.
        #
        # @return [Module, nil]
        def authorization_namespace = resolve_constant(run.authorization_namespace, "authorization_namespace")

        # The policy for the target resource, resolved the way the dispatching
        # controller resolved it. Verified against the run's recorded policy in
        # the constructor, so by the time anyone calls this it is known to match.
        #
        # @return [Class]
        def target_policy_class = ::ActionPolicy.lookup(target_class, namespace: authorization_namespace)

        # The policy predicate dispatch checked per record, e.g. :archive?.
        #
        # @return [Symbol, nil] nil only for opaque (untargeted) work
        def policy_action = run.policy_action&.to_sym

        # What Plutonium authorizes on, shaped for a policy constructor.
        #
        # The parent pair is included for the same reason the tenant is. Omitting
        # it does not merely lose a filter: Policy#default_relation_scope picks
        # ONE branch, parent or entity, so a nested run without its parent
        # re-derives targets under the TENANT where dispatch used the parent.
        # Wider, and not the scope the initiator was shown. It also leaves a host
        # predicate reading +parent+ looking at nil — legal, since the policy
        # declares it optional, so instead of raising it quietly answers false
        # and every target is refused for a reason that names the predicate
        # rather than the missing context.
        #
        # Both halves or neither: Policy#default_relation_scope raises on one
        # without the other, and the migration records them together.
        #
        # @return [Hash]
        def policy_context
          {user: initiator, entity_scope: scoped_entity,
           parent: parent, parent_association: parent_association}
        end

        # Builds the policy for a record or resource class, under the run's
        # namespace.
        #
        # The leading :: is REQUIRED — Plutonium::ActionPolicy exists, so a bare
        # ActionPolicy resolves to that namespace instead of the gem's.
        #
        # +lookup+ raises ActionPolicy::NotFound when nothing matches, which is
        # the correct direction to fail: no policy must never mean no check.
        #
        # Deliberately NOT asserted against the run's recorded policy. That
        # assertion is about the TARGET RESOURCE and is made once, up front. A
        # per-record check would break legitimate STI runs: a run over
        # Blogging::Post whose rows include Blogging::Article resolves
        # ArticlePolicy for those rows, which correctly differs from the run's
        # PostPolicy.
        #
        # Not a silent hole: a subtype policy missing +policy_action+ entirely
        # raises via +send_with_report+ (see {#permitted?}), not "permitted".
        #
        # @param record [ActiveRecord::Base, Class]
        # @return [Plutonium::Resource::Policy]
        def policy_for(record)
          # The record is POSITIONAL. ActionPolicy::Policy::Core#initialize is
          # `def initialize(record = nil, *)`, so a `record:` KEYWORD is swallowed
          # and the policy's own `record` stays nil — every predicate written as
          # `record.published?` then blows up (or, worse, a predicate that guards
          # on record state stops guarding). This is how ActionPolicy builds
          # policies internally too; see Behaviours::PolicyFor#policy_for.
          ::ActionPolicy.lookup(record, namespace: authorization_namespace).new(record, **policy_context)
        end

        # The target resource, narrowed to what the initiator may see in this
        # tenant. Policy#apply_scope also enforces that the policy actually
        # applied Plutonium's default (parent/entity) scoping, so a custom
        # relation_scope that forgets it raises rather than leaking.
        #
        # @return [ActiveRecord::Relation]
        def authorized_scope(relation = target_class.all)
          policy_for(relation.klass).apply_scope(relation, type: :active_record_relation)
        end

        # Resolves the stored target ids through the policy scope, then through
        # the policy predicate.
        #
        # BOTH checks are needed and they catch different revocations. The scope
        # catches lost VISIBILITY — the record is no longer the initiator's to
        # see. The predicate catches lost PERMISSION — the record is still
        # visible but +archive?+ now returns false. Resolving by scope alone
        # would let a run whose permission was revoked after enqueue proceed
        # anyway, which is the whole failure this class exists to prevent, and
        # is what dispatch itself checks per record (see
        # Plutonium::Resource::Controllers::InteractiveActions#authorize_interactive_bulk_action!).
        #
        # The check lives here rather than in the executor so that no caller can
        # perform work without it having happened.
        #
        # One query for the whole set, not one per id: a bulk run over a few
        # thousand records is the normal case, and per-id lookups would also make
        # the scope check easy to accidentally skip on the "just fetch this one"
        # path. The predicates are then evaluated in memory, per record — that is
        # N policy objects but no extra queries, unless a host's own predicate
        # queries, which is the host's choice.
        #
        # @return [Targets]
        def targets
          unless run.target_type
            raise UnresolvableError,
              "run #{run.id} (#{run.class}) has no target_type; it is not a targeted run"
          end

          key = target_class.primary_key
          # unhandled_target_ids, not target_ids: a run resumed after an
          # interruption (see Async::ReapJob) must not redo — or re-record as
          # missing/unauthorized — targets it already dispositioned.
          ids = run.unhandled_target_ids
          found = authorized_scope.where(key => ids).index_by { |record| record.public_send(key).to_s }

          # Compared as strings because the two sides cross a type boundary:
          # target_ids comes back out of a JSON column (and may have gone in as
          # request params), while the ids on the loaded records are whatever the
          # host's primary key is — bigint or uuid. Matching on raw values would
          # report every target as missing the moment those disagree.
          records = []
          missing_ids = []
          unauthorized_ids = []

          ids.each do |id|
            record = found[id.to_s]
            if record.nil?
              missing_ids << id
            elsif permitted?(record)
              records << record
            else
              unauthorized_ids << id
            end
          end

          Targets.new(records: records, missing_ids: missing_ids, unauthorized_ids: unauthorized_ids)
        end

        # Asks the record's own policy the question dispatch asked.
        #
        # PUBLIC because it is exactly what an executor needs immediately before
        # acting on a record. {#targets} answers this once, up front, which makes
        # a good operator report but is only true as of that moment; a run over
        # thousands of records acts long after it. Re-asking per record right
        # before {Run#perform_on} is the caller's decision, and this is the
        # sanctioned way to do it — reimplementing it would duplicate the
        # +send_with_report+ behaviour below rather than share it.
        #
        # NOT named +permitted_now?+: on its own it answers from the subjects
        # cached at construction, so a name promising currency would overstate it.
        # Pair it with {#refresh_subjects!} when currency actually matters.
        #
        # send_with_report raises NotImplementedError when the predicate is
        # missing, so an action renamed between enqueue and perform surfaces as a
        # loud failure rather than a silent false.
        #
        # @param record [ActiveRecord::Base]
        # @return [Boolean]
        def permitted?(record)
          policy_for(record).send_with_report(policy_action)
        end

        # Re-reads the two authorization subjects from the database.
        #
        # Policies are built from (initiator, scoped_entity), and both are cached
        # belongs_to associations — so without this every check for the whole run
        # evaluates against the subjects as they were when this object was built.
        # A predicate reading +user.role+ would then look like a guard while
        # guarding nothing. Reloading also drops association caches on the
        # subject, so +user.organizations+ is re-read too.
        #
        # Two queries. Deliberately NOT called automatically: per-record reload is
        # two queries per target, which is untenable for a large run, and the
        # right cadence (per record, per batch, per interval) depends on the
        # executor's shape. This provides the capability; the policy is the
        # caller's.
        #
        # Re-runs the subject existence checks, so a tenant or initiator deleted
        # MID-run stops the work the same way one deleted before it started does.
        # Does not re-verify the recorded policy: constants do not change under a
        # running process.
        #
        # @raise [UnresolvableError] if a subject has since been deleted
        # @return [self]
        def refresh_subjects!
          run.reload_initiator
          run.reload_scoped_entity if run.scoped_entity_type
          run.reload_parent if run.parent_type
          verify_subjects!
          # Stamped only after the check passes: a refresh that raised did not
          # produce a usable answer, so nothing may treat it as a fresh read.
          @subjects_read_at = Time.current
          self
        end

        private

        # Constantizes a stored class/module name, converting the raw NameError
        # into this class's domain error. A model or module renamed between
        # enqueue and perform is a stored-context failure like any other here, and
        # should name the run and the diagnosis rather than surfacing as an
        # unattributed NameError from deep inside a job.
        def resolve_constant(name, field)
          return nil if name.nil?

          name.constantize
        rescue NameError
          raise UnresolvableError,
            "run #{run.id} recorded #{field} #{name.inspect}, which no longer resolves to a constant; " \
            "refusing to guess what was meant"
        end

        def verify_resolvable!
          verify_subjects!
          verify_policy!
        end

        # Both checks below distinguish "the run carries no X" from "the run
        # carries an X that has since been deleted". The association returns nil
        # either way; only the *_type column tells them apart.
        #
        # Split out from verify_resolvable! so {#refresh_subjects!} can re-apply
        # exactly these — a subject deleted mid-run must fail the same way one
        # deleted before the run started does.
        def verify_subjects!
          # The initiator column is NOT NULL, so a nil association here means the
          # user row is gone. Refusing is the whole point: a run whose initiator
          # no longer exists has no one left to authorize as.
          if run.initiator.nil?
            raise UnresolvableError,
              "run #{run.id} has no initiator (#{run.initiator_type}##{run.initiator_id} no longer exists)"
          end

          # nil scoped_entity is LEGITIMATE — an unscoped portal has no tenant,
          # and the schema is nullable by design. But that is only true when the
          # run carries no tenant at all. If the columns are populated and the row
          # is gone, nil means "tenant unknown", and treating it as "no tenant"
          # drops the entity filter entirely, returning records from EVERY tenant.
          # That is precisely the fail-open case this class exists to prevent.
          if run.scoped_entity_type.present? && run.scoped_entity.nil?
            raise UnresolvableError,
              "run #{run.id} was scoped to #{run.scoped_entity_type}##{run.scoped_entity_id}, " \
              "which no longer exists; refusing to resolve targets without a tenant"
          end

          # Same distinction one more time, and the same direction of failure. A
          # deleted parent nils the association, which reads as "not a nested
          # dispatch" — and that hands the run entity scoping instead of parent
          # scoping, which is wider.
          if run.parent_type.present? && run.parent.nil?
            raise UnresolvableError,
              "run #{run.id} was nested under #{run.parent_type}##{run.parent_id}, " \
              "which no longer exists; refusing to resolve targets without its parent"
          end
        end

        # Checks that the policy resolving now is the one dispatch resolved.
        #
        # Only meaningful for a targeted run — untargeted work has no target
        # resource and therefore no policy to pin.
        def verify_policy!
          return if run.target_type.nil?

          # A targeted run with no recorded policy is not "unasserted", it is
          # unverifiable: there is nothing to compare today's lookup against, and
          # accepting it would silently disable the check for exactly the runs
          # that need it. The dispatcher's job is to record this.
          if run.policy_class_name.blank?
            raise UnresolvableError,
              "run #{run.id} targets #{run.target_type} but recorded no policy_class_name; " \
              "refusing to resolve targets against an unverifiable policy"
          end

          # A targeted run with no predicate is the same hole one level down:
          # there would be nothing to ask the policy, and "nothing to ask" must
          # never collapse into "allowed".
          if run.policy_action.blank?
            raise UnresolvableError,
              "run #{run.id} targets #{run.target_type} but recorded no policy_action; " \
              "refusing to act on targets without a permission check"
          end

          resolved = target_policy_class
          return if resolved.name == run.policy_class_name

          raise PolicyMismatchError,
            "run #{run.id} was dispatched under #{run.policy_class_name}, but " \
            "#{run.target_type} now resolves to #{resolved.name} " \
            "(namespace: #{run.authorization_namespace || "top level"}); " \
            "refusing to run under a policy the initiator was never subject to"
        end
      end
    end
  end
end
