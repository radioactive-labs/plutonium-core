# frozen_string_literal: true

module Plutonium
  module Wizard
    # The author-facing class macros: `step`, `review`, `anchored`, `navigation`,
    # `cleanup_after`, `concurrency_key`, `one_time`, `encrypt_data`, `anonymous`.
    # Mixed into {Base}.
    module DSL
      extend ActiveSupport::Concern

      # Sentinel distinguishing `cleanup_after` (read) from `cleanup_after nil`.
      UNSET = Object.new
      private_constant :UNSET

      class_methods do
        def steps
          @steps ||= []
        end

        # Declare an ordered step.
        #
        # `using:` is a step OPTION (never a block method — avoids Ruby's
        # `Module#using` refinements clash). The block, when present, adds inline
        # fields on top. Selector options for `using:` (only:/except:/fields:/etc.)
        # are captured and merged in Task 3.
        def step(key, label: nil, condition: nil, using: nil, **using_opts, &block)
          assert_not_after_review!(key)

          capture = FieldCapture.build(using:, using_opts:, &block)

          steps << Step.new(
            key:,
            label:,
            condition:,
            fields: capture,
            on_submit: capture.delete_hook(:on_submit),
            on_rollback: capture.delete_hook(:on_rollback),
            using_spec: capture.using_spec
          )
        end

        # Declare the terminal review step (§2.5). Must be last.
        def review(label: "Review", condition: nil, &block)
          assert_not_after_review!(:review)
          steps << ReviewStep.new(label:, condition:, block:)
        end

        # --- anchoring (§3) ---

        # Declare that this wizard runs against an anchor record. Two anchoring
        # strategies (which may combine):
        #
        # - `anchored with: Company` — a TYPE anchor. The anchor is resolved from
        #   the URL `:id` via the resource controller's scoped, policy-gated
        #   `resource_record!` (resource-mounted member route). IDOR-safe because
        #   the record is scoped+authorized.
        # - `anchored via: :current_scoped_entity` — a CONTEXT anchor. The anchor
        #   is resolved by calling that method on the controller at request time
        #   (`:current_user`, `:current_scoped_entity`, or any host method). No
        #   `:id`, IDOR-safe (trusted context). Mounted portal-level via
        #   `register_wizard`.
        # - combined `anchored via: :current_scoped_entity, with: Organization` —
        #   resolve via the method, then assert the result is an Organization.
        #
        # A resolved anchor that is nil raises (anchored-ness is declared).
        def anchored(with: nil, via: nil, &resolver)
          @anchored = true
          @anchor_types = Array(with).presence
          @anchor_via = via
          @anchor_resolver = resolver
        end

        def anchored? = !!@anchored

        def anchor_types = @anchor_types

        # The controller method used to resolve a CONTEXT anchor, or nil for a
        # TYPE (`with:`-only) anchor.
        def anchor_via = @anchor_via

        # Whether this wizard's anchor is a CONTEXT anchor (resolved via a method),
        # as opposed to a TYPE anchor (resolved from the URL `:id`).
        def anchored_via? = !@anchor_via.nil?

        def anchor_resolver = @anchor_resolver

        # --- navigation (§7) ---

        def navigation(mode = nil)
          if mode
            @navigation = mode
          else
            @navigation || :linear
          end
        end

        # --- cleanup (§2.3) ---

        def cleanup_after(ttl = UNSET)
          if ttl.equal?(UNSET)
            return @cleanup_after_set ? @cleanup_after : Plutonium.configuration.wizards.cleanup_after
          end
          @cleanup_after_set = true
          @cleanup_after = (ttl == :never) ? nil : ttl
        end

        # --- concurrency (§4.2) ---

        # Declare the run's CONCURRENCY KEY — the value(s) a run is keyed by
        # (Solid Queue-style). The keyed session row is created at start
        # (`in_progress`) and IS the lock: a second launch with the same key
        # resumes that row instead of forking (at most one in-progress run per
        # key). Omit → unlimited concurrent runs, each identified by a fresh
        # `wizard_token` (§4.3).
        #
        # The resolver runs in the wizard instance context (where `current_user`,
        # `current_scoped_entity`, `anchor`, and `wizard_token` are available) and
        # returns the value(s): records → GlobalID, scalars → to_s, arrays joined.
        # The portal tenant (`current_scoped_entity`) is ALWAYS folded in
        # automatically (§4.4) — authors never thread it.
        #
        #   concurrency_key { current_user }                 # ≤1 in-progress per user
        #   concurrency_key { anchor }                        # ≤1 per anchored record
        #   concurrency_key { wizard_token }                  # per-run id (e.g. guest)
        #   concurrency_key :current_user                     # method shorthand
        def concurrency_key(method = nil, &block)
          @concurrency_key =
            if block
              block
            elsif method
              m = method.to_sym
              -> { public_send(m) }
            else
              raise ArgumentError, "concurrency_key requires a block or a method name"
            end
        end

        # Whether this wizard has a concurrency_key (keyed/singleton runs).
        def concurrency_key? = !@concurrency_key.nil?

        # The resolver proc (or nil when omitted → tokened runs).
        def concurrency_key_resolver = @concurrency_key

        # --- repeatability / one-time (§4.3 / §9) ---

        # Opt a wizard into being ONE-TIME: on successful completion the completed
        # row is RETAINED at its concurrency_key, permanently blocking a restart
        # (and is what the gate, §9, checks). Without `one_time` the row is DELETED
        # on completion → repeatable.
        #
        # Requires a `concurrency_key` (that's the stable row to retain); a run
        # with no concurrency_key is tokened and always repeatable. The
        # requirement is enforced lazily in {#one_time?} so subclass timing and
        # declaration order don't matter.
        def one_time
          @one_time = true
        end

        # Whether this wizard is one-time. Raises if `one_time` was declared
        # without a `concurrency_key` (only keyed runs can be retained).
        def one_time?
          return false unless @one_time
          unless concurrency_key?
            raise ArgumentError,
              "#{name || "wizard"} declares `one_time` without a `concurrency_key`; " \
              "one-time retention needs a stable key to retain (§4.3)"
          end
          true
        end

        # --- authentication (§4.5) ---

        # Opt this wizard into GUEST (unauthenticated) access. By default a wizard
        # requires a `current_user` to enter — entry without one is rejected. An
        # `anonymous` wizard may run with no `current_user`; its identity is the
        # server-minted `wizard_token` (httponly/secure/same_site cookie), and it
        # may authenticate ONLY at its terminal `execute` (e.g. a signup flow). It
        # NEVER crosses the auth boundary mid-flow (§4.5).
        def anonymous
          @anonymous = true
        end

        def anonymous? = !!@anonymous

        # --- encryption (§8.1) ---

        def encrypt_data(flag = true)
          @encrypt_data = flag
        end

        def encrypt_data? = !!@encrypt_data

        private

        def assert_not_after_review!(key)
          return unless steps.any?(&:review?)
          raise ArgumentError,
            "`review` must be the last step; cannot declare step :#{key} after it"
        end

        # Class-level state must not leak into subclasses by reference.
        def inherited(subclass)
          super
          subclass.instance_variable_set(:@steps, steps.dup)
          subclass.instance_variable_set(:@anchored, @anchored)
          subclass.instance_variable_set(:@anchor_types, @anchor_types)
          subclass.instance_variable_set(:@anchor_via, @anchor_via)
          subclass.instance_variable_set(:@anchor_resolver, @anchor_resolver)
          subclass.instance_variable_set(:@navigation, @navigation)
          subclass.instance_variable_set(:@cleanup_after, @cleanup_after)
          subclass.instance_variable_set(:@cleanup_after_set, @cleanup_after_set)
          subclass.instance_variable_set(:@concurrency_key, @concurrency_key)
          subclass.instance_variable_set(:@one_time, @one_time)
          subclass.instance_variable_set(:@encrypt_data, @encrypt_data)
          subclass.instance_variable_set(:@anonymous, @anonymous)
        end
      end
    end
  end
end
