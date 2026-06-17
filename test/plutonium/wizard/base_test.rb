# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    class BaseTest < Minitest::Test
      class CreateCo < Plutonium::Wizard::Base
        presents label: "Create a company"

        step :company do
          attribute :name, :string
          attribute :employees, :integer
          input :name
          validates :name, presence: true
        end

        step :plan, condition: -> { data.company.name.present? } do
          attribute :plan, :string
          input :plan
        end

        review label: "Review"

        def execute = succeed(true)
      end

      def test_steps_ordered_and_terminal_review
        keys = CreateCo.steps.map(&:key)
        assert_equal %i[company plan review], keys
        assert CreateCo.steps.last.review?
        refute CreateCo.steps.first.review?
      end

      def test_step_label_defaults_to_humanized_key
        plan = CreateCo.steps.find { _1.key == :plan }
        assert_equal "Plan", plan.label
      end

      def test_step_records_condition
        plan = CreateCo.steps.find { _1.key == :plan }
        assert_kind_of Proc, plan.condition

        company = CreateCo.steps.find { _1.key == :company }
        assert_nil company.condition
      end

      def test_data_steps_spec_is_per_step
        spec = CreateCo.data_steps_spec
        assert_equal %i[company plan], spec.keys
        assert_equal({name: :string, employees: :integer}, spec[:company][:schema])
        assert_equal({plan: :string}, spec[:plan][:schema])
      end

      def test_typed_data_snapshot_is_step_keyed
        w = CreateCo.new
        w.data_attributes = {"company" => {"name" => "Acme", "employees" => "12"}}

        assert_equal "Acme", w.data.company.name
        assert_equal 12, w.data.company.employees   # cast to Integer
        assert_nil w.data.plan.plan                 # uncollected → nil
      end

      def test_data_memo_invalidated_on_reassign
        w = CreateCo.new
        w.data_attributes = {"company" => {"name" => "Acme"}}
        assert_equal "Acme", w.data.company.name

        w.data_attributes = {"company" => {"name" => "Globex"}}
        assert_equal "Globex", w.data.company.name
      end

      def test_review_must_be_last
        err = assert_raises(ArgumentError) do
          Class.new(Plutonium::Wizard::Base) do
            review label: "R"
            step(:after) { attribute :x, :string }
          end
        end
        assert_match(/review.*last/i, err.message)
      end

      def test_anchor_raises_when_not_anchored
        assert_raises(Plutonium::Wizard::NotAnchoredError) { CreateCo.new.anchor }
      end

      def test_anchored_recording
        single = Class.new(Plutonium::Wizard::Base) { anchored with: Array }
        assert single.anchored?
        assert_equal [Array], single.anchor_types

        poly = Class.new(Plutonium::Wizard::Base) { anchored with: [Array, Hash] }
        assert_equal [Array, Hash], poly.anchor_types

        generic = Class.new(Plutonium::Wizard::Base) { anchored }
        assert generic.anchored?
        assert_nil generic.anchor_types

        none = Class.new(Plutonium::Wizard::Base)
        refute none.anchored?
      end

      def test_anchor_returns_bound_record_when_anchored
        klass = Class.new(Plutonium::Wizard::Base) { anchored with: String }
        w = klass.new
        w.anchor = "the-record"
        assert_equal "the-record", w.anchor
      end

      def test_navigation_default_and_override
        assert_equal :linear, CreateCo.navigation

        free = Class.new(Plutonium::Wizard::Base) { navigation :free }
        assert_equal :free, free.navigation
      end

      def test_stepper_default_and_override
        assert_equal true, CreateCo.stepper?, "stepper (top rail) is on by default"

        railless = Class.new(Plutonium::Wizard::Base) { stepper false }
        assert_equal false, railless.stepper?
      end

      def test_stepper_is_inherited_not_shared
        railless = Class.new(Plutonium::Wizard::Base) { stepper false }
        sub = Class.new(railless)
        assert_equal false, sub.stepper?, "subclass inherits the stepper setting"
      end

      def test_review_summary_default_and_override
        assert CreateCo.steps.last.summary?, "review auto-summary is on by default"

        no_summary = Class.new(Plutonium::Wizard::Base) do
          step(:a) { attribute :x, :string }
          review label: "R", summary: false
        end
        refute no_summary.steps.last.summary?
      end

      def test_review_header_default_and_override
        assert CreateCo.steps.last.header?, "review header section is shown by default"

        no_header = Class.new(Plutonium::Wizard::Base) do
          step(:a) { attribute :x, :string }
          review label: "R", header: false
        end
        refute no_header.steps.last.header?
      end

      def test_cleanup_after_default_from_config
        assert_equal Plutonium.configuration.wizards.cleanup_after, CreateCo.cleanup_after
      end

      def test_cleanup_after_explicit_and_never
        explicit = Class.new(Plutonium::Wizard::Base) { cleanup_after 7.days }
        assert_equal 7.days, explicit.cleanup_after

        never = Class.new(Plutonium::Wizard::Base) { cleanup_after :never }
        assert_nil never.cleanup_after
      end

      def test_concurrency_key
        refute CreateCo.concurrency_key?

        keyed = Class.new(Plutonium::Wizard::Base) { concurrency_key { current_user } }
        assert keyed.concurrency_key?
        refute_nil keyed.concurrency_key_resolver

        # Method shorthand.
        by_method = Class.new(Plutonium::Wizard::Base) { concurrency_key :current_user }
        assert by_method.concurrency_key?
      end

      def test_concurrency_key_value_folds_tenant
        keyed = Class.new(Plutonium::Wizard::Base) { concurrency_key { current_user } }
        w = keyed.new
        w.current_user = "user-1"
        w.current_scoped_entity = "tenant-9"
        assert_equal ["user-1", "tenant-9"], w.concurrency_key_value
      end

      # An anchored wizard with no explicit key is implicitly keyed by
      # [anchor, current_user] (tenant folds in) — one draft per user per record.
      def test_anchored_wizard_implies_anchor_user_key
        klass = Class.new(Plutonium::Wizard::Base) { anchored with: String }
        assert klass.concurrency_key?, "anchored ⇒ keyed by default"
        assert klass.implied_anchor_key?

        w = klass.new
        w.anchor = "rec"
        w.current_user = "user-1"
        w.current_scoped_entity = "tenant-9"
        assert_equal ["rec", "user-1", "tenant-9"], w.concurrency_key_value
      end

      def test_explicit_concurrency_key_overrides_implied_anchor_key
        klass = Class.new(Plutonium::Wizard::Base) do
          anchored with: String
          concurrency_key { anchor }
        end
        refute klass.implied_anchor_key?
        w = klass.new
        w.anchor = "rec"
        w.current_scoped_entity = "t"
        assert_equal ["rec", "t"], w.concurrency_key_value, "explicit key wins"
      end

      def test_anonymous_anchored_wizard_stays_tokened
        klass = Class.new(Plutonium::Wizard::Base) do
          anchored with: String
          anonymous
        end
        refute klass.concurrency_key?, "a guest has no real user to key by"
        refute klass.implied_anchor_key?
      end

      def test_non_anchored_wizard_is_not_implicitly_keyed
        refute CreateCo.concurrency_key?
        refute CreateCo.implied_anchor_key?
      end

      def test_one_time_requires_concurrency_key
        # `one_time` without a `concurrency_key` raises at first use.
        bad = Class.new(Plutonium::Wizard::Base) { one_time }
        assert_raises(ArgumentError) { bad.one_time? }
      end

      def test_one_time
        refute CreateCo.one_time?

        ot = Class.new(Plutonium::Wizard::Base) do
          concurrency_key { current_user }
          one_time
        end
        assert ot.one_time?
      end

      def test_on_relaunch_defaults_to_new_and_opts_into_prompt
        assert_equal :new, CreateCo.on_relaunch
        refute CreateCo.relaunch_prompt?

        prompt = Class.new(Plutonium::Wizard::Base) { on_relaunch :prompt }
        assert_equal :prompt, prompt.on_relaunch
        assert prompt.relaunch_prompt?
      end

      def test_on_relaunch_is_inherited
        prompt = Class.new(Plutonium::Wizard::Base) { on_relaunch :prompt }
        assert Class.new(prompt).relaunch_prompt?
      end

      def test_completed_block_defaults_to_nil_and_is_recorded
        assert_nil CreateCo.completed_block

        block = proc { "done" }
        with_block = Class.new(Plutonium::Wizard::Base) { completed(&block) }
        assert_equal block, with_block.completed_block
      end

      def test_completed_block_is_inherited_not_shared
        block = proc { "done" }
        parent = Class.new(Plutonium::Wizard::Base) { completed(&block) }
        child = Class.new(parent)

        assert_equal block, child.completed_block
        # Overriding on the child doesn't mutate the parent's block.
        other = proc { "child" }
        child.completed(&other)
        assert_equal other, child.completed_block
        assert_equal block, parent.completed_block
      end

      def test_encrypt_data
        refute CreateCo.encrypt_data?

        enc = Class.new(Plutonium::Wizard::Base) { encrypt_data }
        assert enc.encrypt_data?
      end

      def test_anonymous_defaults_to_false_and_opts_in
        refute CreateCo.anonymous?, "wizards require authentication by default"

        guest = Class.new(Plutonium::Wizard::Base) { anonymous }
        assert guest.anonymous?
      end

      def test_anonymous_is_not_inherited_by_reference
        guest = Class.new(Plutonium::Wizard::Base) { anonymous }
        sub = Class.new(guest)
        assert sub.anonymous?, "subclass inherits the anonymous flag"
        # And a plain subclass of a default wizard stays authenticated.
        refute Class.new(CreateCo).anonymous?
      end

      def test_presents
        assert_equal "Create a company", CreateCo.label
        assert_equal "Create a company", CreateCo.new.label
      end

      def test_execute_required
        bare = Class.new(Plutonium::Wizard::Base)
        assert_raises(NotImplementedError) { bare.new.execute }
      end

      def test_succeed_returns_success_outcome
        outcome = CreateCo.new.execute
        assert_kind_of Plutonium::Interaction::Outcome::Success, outcome
        assert_equal true, outcome.value
      end

      def test_failed_returns_failure_outcome
        w = CreateCo.new
        outcome = w.send(:failed, "nope")
        assert_kind_of Plutonium::Interaction::Outcome::Failure, outcome
        assert_includes w.errors[:base], "nope"
      end

      def test_fail_bang_base
        w = CreateCo.new
        e = assert_raises(Plutonium::Wizard::StepError) { w.send(:fail!, "nope") }
        assert_equal :base, e.attribute
        assert_equal "nope", e.message
      end

      def test_fail_bang_with_attribute
        w = CreateCo.new
        e = assert_raises(Plutonium::Wizard::StepError) { w.send(:fail!, :name, "bad") }
        assert_equal :name, e.attribute
        assert_equal "bad", e.message
      end

      def test_using_recorded_on_step
        klass = Class.new(Plutonium::Wizard::Base) do
          step :imported, using: String, only: %i[a b]
        end
        step = klass.steps.first
        assert_equal String, step.using_spec[:using]
        assert_equal %i[a b], step.using_spec[:opts][:only]
      end
    end
  end
end
