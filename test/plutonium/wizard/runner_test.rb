# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    # Drives the pure engine directly with the Memory store (and the AR store for
    # the lock/concurrency test). Uses real `Organization` records for the persist /
    # rollback / resume cases since those need GlobalID-able records.
    class RunnerTest < ActiveSupport::TestCase
      # --- a branching, execute-only wizard ---
      class W < Plutonium::Wizard::Base
        step(:a) do
          attribute :go, :string
          validates :go, presence: true
        end
        step(:b, condition: -> { data.go == "yes" }) do
          attribute :note, :string
        end
        review label: "R"

        def execute = succeed(:done)
      end

      # --- an on_submit / persist / on_rollback wizard ---
      class Persisting < Plutonium::Wizard::Base
        step(:make) do
          attribute :name, :string
          validates :name, presence: true
          on_submit do
            persist Organization.create!(name: data.name)
          end
        end
        review label: "R"

        def execute = succeed(:done)
      end

      class RollbackCustom < Plutonium::Wizard::Base
        step(:make) do
          attribute :name, :string
          on_submit { persist Organization.create!(name: data.name) }
          on_rollback { persisted[:make].each { |r| r.update!(name: "rolled-back") } }
        end
        review label: "R"

        def execute = succeed(:done)
      end

      # --- a wizard whose on_submit fails via a bang method ---
      class BangFail < Plutonium::Wizard::Base
        step(:make) do
          attribute :name, :string
          on_submit { persist Organization.create!(name: nil) } # name required → RecordInvalid
        end
        review label: "R"

        def execute = succeed(:done)
      end

      class StepErrorFail < Plutonium::Wizard::Base
        step(:make) do
          attribute :name, :string
          on_submit { fail!(:name, "is no good") }
        end
        review label: "R"

        def execute = succeed(:done)
      end

      # --- a wizard whose execute fails ---
      class ExecuteFails < Plutonium::Wizard::Base
        step(:a) do
          attribute :go, :string
          validates :go, presence: true
        end
        review label: "R"

        def execute
          failed("nope")
        end
      end

      setup do
        Plutonium::Wizard::Session.delete_all
        Organization.delete_all if defined?(Organization)
        @store = Plutonium::Wizard::Store::Memory.new
        @runner = build_runner(W)
      end

      def build_runner(klass, store: @store, key: "k", **kw)
        Plutonium::Wizard::Runner.new(wizard_class: klass, store: store, instance_key: key, **kw)
      end

      # ---- visible_path / branching ----

      test "branching hides b until go=yes (subtractive)" do
        assert_equal %i[a review], @runner.visible_path.map(&:key)
        @runner.advance(:a, {"go" => "yes"})
        assert_equal %i[a b review], build_runner(W).visible_path.map(&:key)
      end

      test "review is always last in the visible path" do
        assert_equal :review, @runner.visible_path.last.key
      end

      # ---- current_step ----

      test "current_step defaults to first visible" do
        assert_equal :a, @runner.current_step.key
      end

      test "wizard reader is exposed" do
        assert_kind_of W, @runner.wizard
      end

      # ---- advance ----

      test "advance invalid stays put with errors" do
        res = @runner.advance(:a, {"go" => ""})
        refute res.ok?
        assert res.errors.key?(:go)
        assert_equal :a, build_runner(W).current_step.key
      end

      test "advance valid stages data and moves cursor" do
        res = @runner.advance(:a, {"go" => "yes"})
        assert res.ok?
        reloaded = build_runner(W)
        assert_equal "yes", reloaded.wizard.data.go
        assert_equal :b, reloaded.current_step.key
      end

      test "advance with go=no skips b and lands on review" do
        @runner.advance(:a, {"go" => "no"})
        assert_equal :review, build_runner(W).current_step.key
      end

      # ---- imported validation merge (nil-safe) ----

      test "imported_validate_fn merged with inline when present" do
        klass = Class.new(Plutonium::Wizard::Base) do
          step(:org, using: Organization, only: %i[name]) do
            attribute :extra, :string
            validates :extra, presence: true
          end
          review label: "R"
          def execute = succeed(:done)
        end
        runner = build_runner(klass)
        # name blank (imported presence) + extra blank (inline presence)
        res = runner.advance(:org, {"name" => "", "extra" => ""})
        refute res.ok?
        assert res.errors.key?(:name), "imported validation should surface"
        assert res.errors.key?(:extra), "inline validation should surface"
      end

      test "nil imported_validate_fn (validate:false) is nil-safe" do
        klass = Class.new(Plutonium::Wizard::Base) do
          step(:org, using: Organization, only: %i[name], validate: false) do
            attribute :extra, :string
            validates :extra, presence: true
          end
          review label: "R"
          def execute = succeed(:done)
        end
        runner = build_runner(klass)
        res = runner.advance(:org, {"name" => "", "extra" => "x"})
        assert res.ok?, "validate:false must not raise and name must not block"
      end

      # ---- on_submit / persist ----

      test "on_submit runs and persist tracks GIDs into state + wizard.persisted" do
        runner = build_runner(Persisting)
        res = runner.advance(:make, {"name" => "Acme"})
        assert res.ok?
        org = Organization.find_by!(name: "Acme")

        state = @store.read("k")
        assert_equal [org.to_global_id.to_s], state.persisted["make"]
        assert_equal [org], runner.wizard.persisted[:make]
      end

      test "on_submit RecordInvalid → step failure, no advance" do
        runner = build_runner(BangFail)
        res = runner.advance(:make, {"name" => "x"})
        refute res.ok?
        assert res.errors.key?(:name)
        assert_equal :make, build_runner(BangFail).current_step.key
        assert_equal 0, Organization.where(name: nil).count
      end

      test "on_submit fail! → mapped attribute error, no advance" do
        runner = build_runner(StepErrorFail)
        res = runner.advance(:make, {"name" => "x"})
        refute res.ok?
        assert_includes res.errors[:name], "is no good"
        assert_equal :make, build_runner(StepErrorFail).current_step.key
      end

      # ---- back ----

      test "back moves cursor without validating and keeps data" do
        runner = build_runner(W)
        runner.advance(:a, {"go" => "yes"})
        runner = build_runner(W)
        assert_equal :b, runner.current_step.key
        res = runner.back
        assert res.ok?
        reloaded = build_runner(W)
        assert_equal :a, reloaded.current_step.key
        assert_equal "yes", reloaded.wizard.data.go # data intact
      end

      # ---- cancel ----

      test "cancel runs default destroy cleanup then clears the row" do
        runner = build_runner(Persisting)
        runner.advance(:make, {"name" => "Acme"})
        assert Organization.exists?(name: "Acme")
        runner.cancel
        refute Organization.exists?(name: "Acme")
        assert_nil @store.read("k")
      end

      test "cancel runs custom on_rollback when present" do
        runner = build_runner(RollbackCustom)
        runner.advance(:make, {"name" => "Acme"})
        org = Organization.find_by!(name: "Acme")
        runner.cancel
        assert_equal "rolled-back", org.reload.name # on_rollback ran instead of destroy
        assert_nil @store.read("k")
      end

      # ---- finalize ----

      test "finalize completeness gap redirects to first offending step" do
        res = @runner.finalize
        refute res.completed?
        assert_equal :a, res.redirect_step
      end

      test "finalize success runs execute, completes row, returns value" do
        @runner.advance(:a, {"go" => "no"}) # b hidden → a + review only
        res = @runner.finalize
        assert res.completed?
        assert_equal :done, res.value
        assert_equal "completed", @store.read("k").status
      end

      test "finalize failure reverts and returns errors" do
        runner = build_runner(ExecuteFails)
        runner.advance(:a, {"go" => "yes"})
        res = runner.finalize
        refute res.completed?
        assert res.errors.key?(:base)
      end

      test "finalize prunes branch-hidden data before execute" do
        captured = nil
        klass = Class.new(Plutonium::Wizard::Base) do
          step(:a) do
            attribute :go, :string
            validates :go, presence: true
          end
          step(:b, condition: -> { data.go == "yes" }) { attribute :note, :string }
          review label: "R"
          define_method(:execute) do
            captured = data_attributes.dup
            succeed(:done)
          end
        end
        runner = build_runner(klass)
        runner.advance(:a, {"go" => "yes"})
        runner = build_runner(klass)
        runner.advance(:b, {"note" => "hi"})
        # now flip a so b is hidden
        runner = build_runner(klass)
        runner.advance(:a, {"go" => "no"})
        build_runner(klass).finalize
        refute captured.key?("note"), "branch-hidden note must be pruned before execute"
        assert_equal "no", captured["go"]
      end

      # ---- resume / rehydration ----

      test "resume rehydrates wizard.persisted from stored GIDs" do
        org = Organization.create!(name: "Stored")
        state = Plutonium::Wizard::State.new(
          wizard: Persisting.name, instance_key: "k", current_step: "make",
          status: "in_progress", data: {"name" => "Stored"},
          persisted: {"make" => [org.to_global_id.to_s]}
        )
        @store.write("k", state, cleanup_after: 1.day)
        runner = build_runner(Persisting)
        assert_equal [org], runner.wizard.persisted[:make]
      end

      # ---- concurrent finalize (AR store + lock) ----

      test "concurrent finalize: loser does not re-run execute" do
        Plutonium::Wizard::Session.delete_all
        store = Plutonium::Wizard::Store::ActiveRecord.new
        runner = build_runner(W, store: store, key: "ar-k")
        runner.advance(:a, {"go" => "no"})
        first = build_runner(W, store: store, key: "ar-k").finalize
        assert first.completed?
        second = build_runner(W, store: store, key: "ar-k").finalize
        refute second.completed?
      end
    end
  end
end
