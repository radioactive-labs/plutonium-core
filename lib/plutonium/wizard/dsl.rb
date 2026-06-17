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

      # The default concurrency key an anchored wizard gets when it declares no
      # explicit `concurrency_key`: one in-progress run per (anchor, user). The
      # tenant folds in automatically (§4.4), and the anchor's GlobalID is already
      # globally unique, so this is the full identity. Evaluated in the wizard
      # instance context (where `anchor`/`current_user` live).
      IMPLIED_ANCHOR_KEY = -> { [anchor, current_user] }
      private_constant :IMPLIED_ANCHOR_KEY

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
        def step(key, label: nil, description: nil, condition: nil, using: nil, **using_opts, &block)
          assert_not_after_review!(key)

          capture = FieldCapture.build(using:, using_opts:, &block)

          steps << Step.new(
            key:,
            label:,
            description:,
            condition:,
            fields: capture,
            on_submit: capture.delete_hook(:on_submit),
            on_rollback: capture.delete_hook(:on_rollback),
            using_spec: capture.using_spec
          )
        end

        # Declare the terminal review step (§2.5). Must be last.
        #
        # `summary:` (default true) controls the auto-summary of completed steps in
        # the COMPLETE state: with no custom block, `summary: true` renders the
        # per-step summary, `summary: false` renders the built-in "ready to
        # complete" panel instead — for a fully author-owned review. (The summary
        # always renders in the INCOMPLETE state, where it's the review-and-fix
        # view, regardless of this flag.)
        #
        # `header:` (default true) controls the step-header section (the label +
        # the "check everything over" prompt). `header: false` drops it entirely,
        # leaving just the review body in the card — for a chromeless finish.
        def review(label: "Review", description: nil, condition: nil, summary: true, header: true, &block)
          assert_not_after_review!(:review)
          steps << ReviewStep.new(label:, description:, condition:, summary:, header:, block:)
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

        # Whether the top rail (the step indicator, §7) is shown. On by default;
        # `stepper false` hides it for a chromeless flow. Uses UNSET so the `false`
        # value reads back correctly (a plain `|| true` would re-enable it).
        def stepper(flag = UNSET)
          return (@stepper = flag) unless flag.equal?(UNSET)
          return @stepper unless @stepper.nil?
          true
        end

        def stepper? = stepper

        # What a bare launch does when the user already has pending (in-progress)
        # runs of this wizard. `:new` (default) always mints a fresh run; `:prompt`
        # renders a "resume or start new" chooser instead (§4.5). Only meaningful
        # for authenticated TOKENED wizards — keyed wizards already auto-resume
        # their single keyed run, and `anonymous` runs are session-keyed; the
        # driving layer no-ops the prompt for both.
        def on_relaunch(mode = nil)
          return @on_relaunch || :new if mode.nil?
          @on_relaunch = mode
        end

        # Whether a bare launch should show the resume-or-new chooser (§4.5).
        def relaunch_prompt? = on_relaunch == :prompt

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
        #   concurrency_key { anchor }                        # ≤1 per anchored record (any user)
        #   concurrency_key { wizard_token }                  # per-run id → tokened/repeatable
        #   concurrency_key :current_user                     # method shorthand
        #
        # An `anchored` (authenticated) wizard with NO explicit key DEFAULTS to
        # `{ [anchor, current_user] }` — one draft per user per record (see
        # {IMPLIED_ANCHOR_KEY}). To make an anchored wizard repeatable instead
        # (a fresh run per launch), declare `concurrency_key { wizard_token }`.
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

        # Whether this wizard is keyed (keyed/singleton runs) — an explicit
        # `concurrency_key` OR the implied anchored default.
        def concurrency_key? = !@concurrency_key.nil? || implied_anchor_key?

        # The resolver proc, or nil when the wizard is tokened. Falls back to the
        # implied `{ [anchor, current_user] }` for an anchored wizard with no
        # explicit key.
        def concurrency_key_resolver
          @concurrency_key || (implied_anchor_key? ? IMPLIED_ANCHOR_KEY : nil)
        end

        # Whether the implied anchored key applies: the wizard is `anchored`, isn't
        # `anonymous` (a guest has no real user to key by — it stays session-keyed),
        # and declared no explicit `concurrency_key`.
        def implied_anchor_key? = anchored? && !anonymous? && @concurrency_key.nil?

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

        # A custom body for the "already completed" page shown when a finished
        # ONE-TIME wizard is re-opened (§9). The completion marker is retained but
        # its `data` is cleared, so there's nothing to review — just a confirmation.
        # The block renders in the {Plutonium::UI::Page::WizardCompleted} Phlex
        # context (with the wizard yielded) and REPLACES the default body entirely
        # (icon/title/message/button — the author supplies their own). Omit for the
        # built-in confirmation page.
        #
        #   completed do |wizard|
        #     h1 { "You're all set up!" }
        #     a(href: "/dashboard") { "Go to your dashboard" }
        #   end
        def completed(&block)
          @completed_block = block
        end

        # The custom completed-page block, or nil for the built-in default.
        def completed_block = @completed_block

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
          subclass.instance_variable_set(:@stepper, @stepper)
          subclass.instance_variable_set(:@on_relaunch, @on_relaunch)
          subclass.instance_variable_set(:@cleanup_after, @cleanup_after)
          subclass.instance_variable_set(:@cleanup_after_set, @cleanup_after_set)
          subclass.instance_variable_set(:@concurrency_key, @concurrency_key)
          subclass.instance_variable_set(:@one_time, @one_time)
          subclass.instance_variable_set(:@completed_block, @completed_block)
          subclass.instance_variable_set(:@encrypt_data, @encrypt_data)
          subclass.instance_variable_set(:@anonymous, @anonymous)
        end
      end
    end
  end
end
