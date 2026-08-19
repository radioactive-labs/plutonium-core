# frozen_string_literal: true

module Plutonium
  module Interaction
    module Concerns
      # Turns an interaction into a dispatcher: instead of doing the work
      # inline, it persists a {Plutonium::Interaction::Run}, enqueues it, and
      # sends the user to it.
      #
      # The interaction keeps everything else it already was — it declares
      # inputs, validates them, renders a form, and is gated by the same policy
      # as before. Only +#execute+ changes.
      #
      # @example
      #   class Blogging::ArchivePosts < Plutonium::Resource::Interaction
      #     dispatches_to Blogging::ArchivePostsRun
      #
      #     attribute :resources
      #     attribute :reason, :string
      #   end
      #
      # == The outcome stays synchronous
      #
      # +call+ still returns an Outcome immediately, because dispatching is what
      # succeeded. Whether the WORK succeeds is the run's business, reported on
      # the run's own page — which is why Outcome needs no third "pending" state.
      #
      # == Nothing is passed in at the call site
      #
      # Every value the run needs is already reachable: the targets are the
      # +resource+/+resources+ the controller resolved through the policy scope,
      # and the authorization triple comes from the controller the interaction
      # is rendering in. So no controller and no host app has to hand a
      # dispatching interaction anything an inline one does not already get.
      #
      # == What dispatch records, and why it is exactly this
      #
      # The job has no controller, so {Plutonium::Interaction::Runs::Context}
      # rebuilds the authorization context from the row. Three of the columns
      # exist purely so that rebuild cannot silently widen:
      #
      # * +authorization_namespace+ — the portal's module NAME. Without it,
      #   perform-time lookup falls back to the base policy and every narrowing
      #   the portal applied is lost.
      # * +policy_class_name+ — the policy dispatch ACTUALLY RESOLVED, never an
      #   inferred "#{Model}Policy". A namespaced portal and an STI fallback both
      #   make the inferred name wrong, and Context refuses to run when the
      #   recorded name and today's lookup disagree.
      # * +policy_action+ — the predicate, so perform re-checks PERMISSION and
      #   not merely visibility.
      module Dispatchable
        extend ActiveSupport::Concern

        # Raised when a dispatching interaction runs while the runs subsystem is
        # switched off. Named rather than a bare RuntimeError so a host can tell
        # it apart from anything the interaction itself raised — and so it reads
        # the same way as the interaction layer's other typed failures
        # (Runs::Context::UnresolvableError, Runs::Executor::TargetRefusedError).
        class NotEnabledError < StandardError; end

        # The tenant is half of what the policy scope filters on, and this is
        # where it comes from.
        include Plutonium::Interaction::Concerns::Scoping

        included do
          # A class_attribute rather than a class ivar so a subclass of a
          # dispatching interaction inherits the declaration.
          class_attribute :run_class, instance_accessor: false
        end

        # Prepended, rather than defined via +define_method+, so a `def
        # execute` written BELOW `dispatches_to` can't silently shadow it —
        # a prepended module sits ahead of the class in the ancestor chain
        # regardless of source order. (A subclass's own #execute still wins,
        # same as any override — this only closes same-class ordering.)
        module ExecuteOverride
          private

          def execute = dispatch
        end

        class_methods do
          # Declares that this interaction dispatches its work to +run_class+.
          #
          # @param run_class [Class<Plutonium::Interaction::Run>]
          # @raise [ArgumentError] if this class already defines its own #execute
          # @return [void]
          def dispatches_to(run_class)
            # Catches the OTHER ordering: #execute already defined before
            # dispatches_to runs is two conflicting declarations, not an
            # ordering accident, and the prepend below does not resolve it.
            if !@execute_defined_by_dispatch &&
                (method_defined?(:execute, false) || private_method_defined?(:execute, false))
              raise ArgumentError,
                "#{self} defines its own #execute, which dispatches_to would overwrite. " \
                "An interaction either does the work inline or dispatches it to a run — " \
                "remove one of the two."
            end

            self.run_class = run_class

            prepend(ExecuteOverride) unless @execute_defined_by_dispatch
            @execute_defined_by_dispatch = true
          end
        end

        private

        # Persists the run and returns the outcome that sends the user to it.
        #
        # The run enqueues ITS OWN job, via an +after_commit+ on
        # {Plutonium::Interaction::Run} — not from here, which would race a
        # fast/inline job adapter against the very commit the row needs to
        # be visible.
        #
        # @return [Plutonium::Interaction::Outcome::Success]
        def dispatch
          # The flag gates the MIGRATION, not just the behaviour: while it is off
          # the runs migration path is never registered (see Plutonium::Railtie),
          # so plutonium_interaction_runs does not exist. Without this the create!
          # below surfaces as a raw "no such table" from inside ActiveRecord,
          # which says nothing about the switch that has to be flipped.
          unless Plutonium.configuration.interaction_runs.enabled
            raise NotEnabledError,
              "#{self.class} dispatches to #{self.class.run_class}, but interaction runs are not " \
              "enabled. Set `config.interaction_runs.enabled = true` in your Plutonium " \
              "initializer, then run the migration."
          end

          run = self.class.run_class.create!(
            initiator: current_user,
            scoped_entity: current_scoped_entity,
            options: dispatch_options,
            **dispatch_target_attributes
          )

          succeed(run).with_redirect_response(dispatch_redirect_target(run))
        end

        # Everything the interaction validated, minus the records themselves.
        #
        # The records are the TARGETS: they are stored as ids and re-resolved
        # through the policy scope when the run performs. A serialized copy in
        # options would be both stale and unauthorized.
        #
        # @return [Hash]
        def dispatch_options
          attributes.except("resource", "resources")
        end

        # Whether this interaction has a SUBJECT at all, decided by what it
        # declared rather than by what the declaration currently holds.
        #
        # Emptiness cannot stand in for this. A bulk action whose ids all
        # resolved to nothing produces an empty +resources+, and reading that as
        # "no targets" would dispatch a run indistinguishable from genuinely
        # opaque work — no target_type, no policy assertion, nothing for
        # Runs::Context to check. Asking what the class DECLARED separates the
        # two cases exactly.
        #
        # @return [Boolean]
        def dispatch_targeted?
          attributes.key?("resources") || attributes.key?("resource")
        end

        # The records the run will act on, taken from whichever subject the
        # controller bound — +resources+ for a bulk action, +resource+ for a
        # record action. Both arrive already narrowed by the policy scope (see
        # Plutonium::Resource::Controllers::InteractiveActions#interactive_bulk).
        #
        # @return [Array<ActiveRecord::Base>]
        def dispatch_targets
          @dispatch_targets ||= begin
            records = Array(attributes["resources"] || attributes["resource"])
            # Refused rather than downgraded to an opaque run. The likeliest
            # cause is a bulk submission whose ids have all since been deleted or
            # left the tenant, and "act on nothing" is not a sensible reading of
            # it — the run would carry no policy assertion and then fail deep in
            # a job with a message about a missing target_type.
            if records.empty?
              raise "#{self.class} declares a subject but resolved no records to act on. " \
                    "A targeted run over an empty set cannot record the policy it was " \
                    "dispatched under, and must not be silently downgraded to opaque work."
            end

            records
          end
        end

        # The target half of the row — empty for opaque work.
        #
        # A run with no targets carries no target_type, and therefore neither a
        # policy to pin nor a predicate to ask. Recording either anyway would be
        # writing an assertion nothing ever checks.
        #
        # @return [Hash]
        def dispatch_target_attributes
          return {} unless dispatch_targeted?

          records = dispatch_targets
          namespace = dispatch_authorization_namespace
          target_class = dispatch_target_class

          {
            target_type: target_class.name,
            target_ids: records.map(&:id),
            progress_total: records.size,
            authorization_namespace: namespace&.name,
            policy_class_name: ::ActionPolicy.lookup(target_class, namespace: namespace).name,
            policy_action: dispatch_policy_action.to_s
          }
        end

        # The RESOURCE class, not the class of the records.
        #
        # A bulk selection of STI rows resolves its policy per record when it
        # performs (Runs::Context#policy_for), but the SCOPE the run resolves
        # targets through has to be the one dispatch authorized against. Reading
        # it off the first record would narrow a mixed Post/Article selection to
        # whichever type happened to come first, and silently report the rest as
        # missing.
        #
        # @return [Class]
        def dispatch_target_class
          view_context.controller.helpers.resource_class
        end

        # ActionPolicy's own public accessor for the controller's module nesting
        # (ActionPolicy::Behaviours::Namespaced). nil is legitimate and means
        # "top level".
        #
        # @return [Module, nil]
        def dispatch_authorization_namespace
          view_context.controller.authorization_namespace
        end

        # The predicate to re-check per record, derived from the action's name
        # exactly as
        # Plutonium::Resource::Controllers::InteractiveActions#authorize_interactive_bulk_action!
        # derives it — the two must agree, or perform would re-check a different
        # question than dispatch asked.
        #
        # @return [Symbol]
        def dispatch_policy_action
          action = view_context.controller.helpers.current_interactive_action
          # Refused here rather than at perform time: Runs::Context will reject a
          # targeted run with no predicate, but by then the diagnosis is a row in
          # a failed job, hours from the code that wrote it.
          unless action
            raise "#{self.class} dispatches #{self.class.run_class} over #{dispatch_targets.size} target(s), " \
                  "but no interactive action is in flight, so there is no policy predicate to record. " \
                  "A targeted run without one cannot re-check permission when it performs."
          end

          :"#{action.name}?"
        end

        # Where dispatch sends the user: the run's own page.
        #
        # Resolved with +resource_url_for+, which is how every resource URL in
        # this framework is built, and NOT by handing the record to
        # Response::Redirect for a plain +url_for+. Under +:path+ entity scoping
        # the route helper is entity-prefixed and takes the tenant as its first
        # argument — +org_runs_path(org, run)+, not +runs_path(run)+ — and
        # +url_for(record)+ derives the helper from the record's own route_key,
        # so it cannot know about the prefix. Passing the bare record would
        # therefore raise for the common entity-scoped case.
        #
        # Override to send them somewhere else.
        #
        # @return [String]
        def dispatch_redirect_target(run)
          view_context.controller.helpers.resource_url_for(run)
        end
      end
    end
  end
end
