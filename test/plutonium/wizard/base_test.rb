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

        step :plan, condition: -> { data.name.present? } do
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

      def test_union_attribute_schema
        assert_equal({name: :string, employees: :integer, plan: :string},
          CreateCo.union_attribute_schema)
      end

      def test_typed_data_snapshot
        w = CreateCo.new
        w.data_attributes = {"name" => "Acme", "employees" => "12"}

        assert_equal "Acme", w.data.name
        assert_equal 12, w.data.employees   # cast to Integer
        assert_nil w.data.plan              # uncollected → nil
      end

      def test_data_memo_invalidated_on_reassign
        w = CreateCo.new
        w.data_attributes = {"name" => "Acme"}
        assert_equal "Acme", w.data.name

        w.data_attributes = {"name" => "Globex"}
        assert_equal "Globex", w.data.name
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

      def test_encrypt_data
        refute CreateCo.encrypt_data?

        enc = Class.new(Plutonium::Wizard::Base) { encrypt_data }
        assert enc.encrypt_data?
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
