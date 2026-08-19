# frozen_string_literal: true

module Plutonium
  module Interaction
    module Concerns
      # Turns an interaction into a dispatcher: instead of doing the work
      # inline, it persists a {Plutonium::Interaction::Async::Run}, enqueues it, and
      # sends the user to it.
      #
      # The interaction keeps everything else it already was — it declares
      # inputs, validates them, renders a form, and is gated by the same policy
      # as before. Only +#execute+ changes.
      #
      # @example
      #   class Blogging::ArchivePosts < Plutonium::Resource::Interaction
      #     attribute :resources
      #     attribute :reason, :string
      #
      #     async do
      #       on_failure :continue
      #       def perform_on(post) = post.archive!(reason: options["reason"])
      #     end
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
      # The job has no controller, so {Plutonium::Interaction::Async::Context}
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

        # Raised when a dispatching interaction runs while async interactions are
        # switched off. Named rather than a bare RuntimeError so a host can tell
        # it apart from anything the interaction itself raised — and so it reads
        # the same way as the interaction layer's other typed failures
        # (Async::Context::UnresolvableError, Async::Executor::TargetRefusedError).
        class NotEnabledError < StandardError; end

        # The tenant is half of what the policy scope filters on, and this is
        # where it comes from.
        include Plutonium::Interaction::Concerns::Scoping

        included do
          # A class_attribute rather than a class ivar so a subclass of a
          # dispatching interaction inherits the declaration.
          class_attribute :run_class, instance_accessor: false

          # Guarded on run_class: an interaction that executes inline hands its
          # uploads straight to a model, whose own attachment validations run as
          # normal. Only a dispatched one stages, and only a staged token can be
          # validated ahead of the work.
          validate :validate_dispatch_attachments, if: -> { self.class.run_class }
        end

        # Prepended, rather than defined via +define_method+, so a `def
        # execute` written BELOW `async` can't silently shadow it —
        # a prepended module sits ahead of the class in the ancestor chain
        # regardless of source order. (A subclass's own #execute still wins,
        # same as any override — this only closes same-class ordering.)
        module ExecuteOverride
          private

          def execute = dispatch
        end

        class_methods do
          # Declares that this interaction executes OUT OF BAND, in a job,
          # instead of inline in the request.
          #
          # An interaction has exactly two ways to do its work, and this is the
          # fork between them:
          #
          #   def execute      # inline, in the request
          #   async do ...     # out of band, in a job
          #
          # == The block is the run's class body
          #
          # Not the body of #execute — the work happens later, in a process with
          # no controller and no view_context, so it cannot be a closure over
          # anything here. What the block declares is a
          # {Plutonium::Interaction::Async::Run} subclass, with exactly the API a
          # standalone run has: +on_failure+, and +perform_on(record)+ or
          # +perform+.
          #
          #   async do
          #     on_failure :continue
          #     def perform_on(post) = post.archive!(reason: options["reason"])
          #   end
          #
          # +def+ opens a fresh scope, so those bodies cannot accidentally close
          # over the interaction's locals — which is what makes the block safe to
          # write here rather than misleading.
          #
          # The generated class is NAMED, as +self::Run+, not left anonymous.
          # That is load-bearing: the class name is persisted in the run's +type+
          # column and constantized in another process, so an anonymous class
          # would produce a row nothing can read back.
          #
          # == Passing a class instead
          #
          # A run shared by several interactions that do the same kind of work is
          # declared once and named here:
          #
          #   async Blogging::ArchivePostsRun
          #
          # @param run_class [Class<Plutonium::Interaction::Async::Run>, nil]
          # @yield the run's class body, when no class is given
          # @raise [ArgumentError] if given both a class and a block, or neither,
          #   or if this class already defines +#execute+ or its own +Run+
          # @return [void]
          def async(run_class = nil, &block)
            if run_class && block
              raise ArgumentError,
                "#{self} declares async with both a run class and a block. The block IS " \
                "a run class — pass one or the other."
            end
            unless run_class || block
              raise ArgumentError,
                "#{self} declares async with nothing to run. Pass a run class, or a block " \
                "declaring one."
            end

            # Catches the OTHER ordering: #execute already defined before
            # async runs is two conflicting declarations, not an
            # ordering accident, and the prepend below does not resolve it.
            if !@execute_defined_by_dispatch &&
                (method_defined?(:execute, false) || private_method_defined?(:execute, false))
              raise ArgumentError,
                "#{self} declares async but also defines its own #execute, which async " \
                "would overwrite. An interaction either executes inline or runs async — " \
                "remove one of the two."
            end

            run_class ||= build_run_class(&block)
            self.run_class = run_class

            prepend(ExecuteOverride) unless @execute_defined_by_dispatch
            @execute_defined_by_dispatch = true
          end

          private

          # Defines +self::Run+ from the block.
          #
          # +const_set+ rather than an anonymous class: see #async. The
          # collision check refuses to clobber a Run the author declared
          # themselves, because silently replacing it would lose their work with
          # no diagnostic — and because the two ways of declaring a run are meant
          # to be alternatives, not layers.
          def build_run_class(&block)
            if const_defined?(:Run, false)
              raise ArgumentError,
                "#{self} already defines #{self}::Run, which async's block would replace. " \
                "Either drop the block and pass the class, or remove the class."
            end

            const_set(:Run, Class.new(Plutonium::Interaction::Async::Run)).tap do |klass|
              klass.class_eval(&block)
            end
          end
        end

        private

        # Persists the run and returns the outcome that sends the user to it.
        #
        # The run enqueues ITS OWN job, via an +after_commit+ on
        # {Plutonium::Interaction::Async::Run} — not from here, which would race a
        # fast/inline job adapter against the very commit the row needs to
        # be visible.
        #
        # @return [Plutonium::Interaction::Outcome::Success]
        def dispatch
          # The flag gates the MIGRATION, not just the behaviour: while it is off
          # the runs migration path is never registered (see Plutonium::Railtie),
          # so plutonium_async_runs does not exist. Without this the create!
          # below surfaces as a raw "no such table" from inside ActiveRecord,
          # which says nothing about the switch that has to be flipped.
          unless Plutonium.configuration.async_interactions.enabled
            raise NotEnabledError,
              "#{self.class} dispatches to #{self.class.run_class}, but async interactions are not " \
              "enabled. Set `config.async_interactions.enabled = true` in your Plutonium " \
              "initializer, then run the migration."
          end

          run = self.class.run_class.create!(
            initiator: current_user,
            scoped_entity: current_scoped_entity,
            # The third policy input. Recorded here rather than re-derived at
            # perform time, where there is no controller to ask — same reason
            # the tenant and the namespace are on the row.
            parent: current_parent,
            parent_association: current_nested_association&.to_s,
            options: dispatch_options,
            **dispatch_target_attributes
          )

          succeed(run).with_redirect_response(dispatch_redirect_target(run))
        end

        # Everything the interaction validated, minus the records themselves,
        # in a shape that survives the trip to a job.
        #
        # The records are the TARGETS: they are stored as ids and re-resolved
        # through the policy scope when the run performs. A serialized copy in
        # options would be both stale and unauthorized.
        #
        # Two things have to happen to the rest, because options is a JSON column
        # and JSON has neither files nor types:
        #
        # * An UPLOADED FILE is staged to its backend's cache and carried as the
        #   token — see {#stage_dispatch_attachments}. Left alone it serializes to
        #   a hash naming a tempfile the request deletes on its way out, so the
        #   run would receive the right filename and no bytes, with nothing
        #   raised anywhere.
        # * TYPED VALUES go through ActiveJob::Arguments, which is Rails' own
        #   answer to this exact problem. Without it a Date arrives as "2026-08-19"
        #   and a BigDecimal as "12.34", so `options["amount"] * 2` quietly
        #   produces "12.3412.34". Primitives pass through verbatim, so the common
        #   case stays readable in the column and only what needs an envelope gets
        #   one — and a host can register its own serializers.
        #
        # @return [Hash]
        def dispatch_options
          # Staged during validation; this is a no-op for a caller that skipped it.
          stage_dispatch_attachments!
          ::ActiveJob::Arguments.serialize([attributes.except("resource", "resources")]).first
        rescue ::ActiveJob::SerializationError => e
          # Raised HERE, where the author can see which attribute they declared,
          # rather than surviving into a row whose work fails deep in a job.
          raise ArgumentError,
            "#{self.class} cannot carry one of its attributes to a run: #{e.message}. " \
            "A run's options are JSON, so every attribute has to be JSON-safe, an " \
            "uploaded file, or a type ActiveJob knows how to serialize."
        end

        # Replaces uploaded files with the token their backend mints for them.
        #
        # The token IS what gets stored, verbatim — not wrapped in an envelope —
        # so the column stays readable and the run's own +attachment+ reader is
        # the one place that knows how to turn it back into a file. That split is
        # deliberate: staging happens here, in the request, where the file is;
        # reviving happens wherever the value is read, which may be a job.
        #
        # @return [Hash]
        # Stages every uploaded file and WRITES THE TOKEN BACK onto the attribute.
        #
        # Writing back is what makes the form survive a re-render. An attribute
        # still holding an ActionDispatch::Http::UploadedFile blows up the moment
        # the form redraws — the file input renders previously-attached files and
        # calls +url+ on the value, which an uploaded file does not answer. So any
        # validation failure on ANY attribute took the whole page down with a
        # NoMethodError. A staged token is a plain String, which is exactly what
        # the input already knows how to redraw, and what a wizard holds for the
        # same reason.
        #
        # Idempotent: a token is already a String, so a re-submit stages nothing
        # a second time.
        def stage_dispatch_attachments!
          return if @dispatch_attachments_staged

          attributes.except("resource", "resources").each do |name, value|
            next unless dispatch_attachment?(value)

            token = Plutonium::Attachments.stage_upload(value, **dispatch_attachment_options(name))
            public_send(:"#{name}=", token)
          end

          @dispatch_attachments_staged = true
        end

        # A file field's +backend:+ and +uploader:+, read off the interaction's own
        # +input+ declaration — the same options, in the same place, that a wizard
        # step reads them from:
        #
        #   attribute :import_file
        #   input :import_file, as: :uppy, uploader: Catalog::ImportUploader
        #
        # An interaction that declares no input for the attribute gets the
        # configured backend and base Shrine, which is what it would have got
        # before either option existed.
        def dispatch_attachment_options(name)
          options = self.class.defined_inputs.dig(name.to_sym, :options) || {}

          {backend: options[:backend] || dispatch_attachment_backend, uploader: options[:uploader]}
        end

        # An uploaded file, or a collection of them. Detected by behaviour rather
        # than by class so it covers ActionDispatch::Http::UploadedFile, Rack's
        # multipart shape, and a bare IO an author assigned themselves.
        def dispatch_attachment?(value)
          return value.any? { |v| dispatch_attachment?(v) } if value.is_a?(Array)

          value.respond_to?(:read) && value.respond_to?(:original_filename)
        end

        # Runs override the shared default, so an app can point runs at one
        # backend without moving its wizards.
        def dispatch_attachment_backend
          Plutonium.configuration.async_interactions.attachment_backend ||
            Plutonium::Attachments.default_backend
        end

        # Runs each file attribute's uploader validations, so a file that breaks
        # them fails the FORM.
        #
        # Without this the interaction validates clean, dispatches, and the run
        # fails in a job — the author's `validate_max_size` reported as a run
        # failure the submitter never sees, on a page they have already left.
        # Wizards reject at the step for the same reason; this is the interaction's
        # equivalent of that.
        #
        # No-op for ActiveStorage fields, and for uploaders declaring no rules.
        def validate_dispatch_attachments
          staged = attributes.except("resource", "resources").select { |_, v| dispatch_attachment?(v) }.keys
          stage_dispatch_attachments!

          staged.each do |name|
            messages = Plutonium::Attachments.validation_errors(
              public_send(name), **dispatch_attachment_options(name)
            )
            messages.each { |message| errors.add(name, message) }
          end
        end

        # Whether this interaction has a SUBJECT at all, decided by what it
        # declared rather than by what the declaration currently holds.
        #
        # Emptiness cannot stand in for this. A bulk action whose ids all
        # resolved to nothing produces an empty +resources+, and reading that as
        # "no targets" would dispatch a run indistinguishable from genuinely
        # opaque work — no target_type, no policy assertion, nothing for
        # Async::Context to check. Asking what the class DECLARED separates the
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
        # performs (Async::Context#policy_for), but the SCOPE the run resolves
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
          # Refused here rather than at perform time: Async::Context will reject a
          # targeted run with no predicate, but by then the diagnosis is a row in
          # a failed job, hours from the code that wrote it.
          unless action
            raise "#{self.class} dispatches #{self.class.run_class} over #{dispatch_targets.size} target(s), " \
                  "but no interactive action is in flight, so there is no policy predicate to record. " \
                  "A targeted run without one cannot re-check permission when it performs."
          end

          :"#{action.name}?"
        end

        # Where dispatch sends the user: back where they came from, else the
        # run's own page.
        #
        # +return_to+ wins because dispatching is not a destination. The user
        # asked to archive the rows they had selected; landing them on a progress
        # page means the list they were working is now two clicks away, and every
        # index already surfaces its in-progress runs in a banner — so going back
        # loses them nothing. A dispatch with no +return_to+ (a direct link, an
        # API-ish caller) still needs somewhere to go, and the run's page is the
        # only page that is about what just happened.
        #
        # Through +url_from+, which is what makes the parameter safe to honour:
        # it returns nil for anything not same-origin, so a forged +return_to+
        # cannot turn a bulk action into an open redirect.
        #
        # The fallback is resolved with +resource_url_for+, which is how every
        # resource URL in this framework is built, and NOT by handing the record
        # to Response::Redirect for a plain +url_for+. Under +:path+ entity
        # scoping the route helper is entity-prefixed and takes the tenant as its
        # first argument — +org_runs_path(org, run)+, not +runs_path(run)+ — and
        # +url_for(record)+ derives the helper from the record's own route_key, so
        # it cannot know about the prefix. Passing the bare record would therefore
        # raise for the common entity-scoped case.
        #
        # Override to send them somewhere else.
        #
        # @return [String]
        def dispatch_redirect_target(run)
          controller = view_context.controller

          controller.url_from(controller.params[:return_to]) ||
            controller.helpers.resource_url_for(run)
        end
      end
    end
  end
end
