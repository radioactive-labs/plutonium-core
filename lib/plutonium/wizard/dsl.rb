# frozen_string_literal: true

module Plutonium
  module Wizard
    # The author-facing class macros: `step`, `review`, `anchored`, `navigation`,
    # `cleanup_after`, `one_time`, `encrypt_data`. Mixed into {Base}.
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
            using_spec: capture.using_spec,
            form_layout: capture.form_layout_sections
          )
        end

        # Declare the terminal review step (§2.5). Must be last.
        def review(label: "Review", condition: nil, &block)
          assert_not_after_review!(:review)
          steps << ReviewStep.new(label:, condition:, block:)
        end

        # --- anchoring (§3) ---

        def anchored(with: nil, &resolver)
          @anchored = true
          @anchor_types = Array(with).presence
          @anchor_resolver = resolver
        end

        def anchored? = !!@anchored

        def anchor_types = @anchor_types

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

        # --- one-time (§9) ---

        def one_time(once_per: :user)
          @one_time = once_per
        end

        def one_time? = !@one_time.nil?

        def one_time_scope = @one_time

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
          subclass.instance_variable_set(:@anchor_resolver, @anchor_resolver)
          subclass.instance_variable_set(:@navigation, @navigation)
          subclass.instance_variable_set(:@cleanup_after, @cleanup_after)
          subclass.instance_variable_set(:@cleanup_after_set, @cleanup_after_set)
          subclass.instance_variable_set(:@one_time, @one_time)
          subclass.instance_variable_set(:@encrypt_data, @encrypt_data)
        end
      end
    end
  end
end
