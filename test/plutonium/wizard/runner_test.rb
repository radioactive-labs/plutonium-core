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

      # --- a wizard whose execute raises a hard error ---
      class ExecuteRaises < Plutonium::Wizard::Base
        step(:a) do
          attribute :go, :string
          validates :go, presence: true
        end
        review label: "R"

        def execute
          raise "boom"
        end
      end

      # --- a wizard with a zero-validation always-visible step after a required one ---
      class WithSkippable < Plutonium::Wizard::Base
        step(:a) do
          attribute :go, :string
          validates :go, presence: true
        end
        step(:b) do
          attribute :note, :string
        end
        review label: "R"

        def execute = succeed(:done)
      end

      # --- a branch whose hidden step persisted a real record (save-as-you-go) ---
      # Step `a` chooses a path; `b` is only visible when path == "x" and its
      # `on_submit` creates + persists an Organization; `c` is always visible.
      class BranchPersist < Plutonium::Wizard::Base
        step(:a) do
          attribute :path, :string
          validates :path, presence: true
        end
        step(:b, condition: -> { data.path == "x" }) do
          attribute :note, :string
          on_submit { persist Organization.create!(name: "b-record") }
        end
        step(:c) { attribute :tail, :string }
        review label: "R"

        def execute = succeed(:done)
      end

      # Same shape as BranchPersist but `b` declares a custom on_rollback that
      # soft-deletes (renames) instead of destroying.
      class BranchPersistRollback < Plutonium::Wizard::Base
        step(:a) do
          attribute :path, :string
          validates :path, presence: true
        end
        step(:b, condition: -> { data.path == "x" }) do
          attribute :note, :string
          on_submit { persist Organization.create!(name: "b-record") }
          on_rollback { persisted[:b].each { |r| r.update!(name: "rolled-back") } }
        end
        step(:c) { attribute :tail, :string }
        review label: "R"

        def execute = succeed(:done)
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
        # §6.1: error values are normalized to plain String messages, never
        # ActiveModel::Error objects.
        assert_kind_of String, res.errors[:name].first
        assert_kind_of String, res.errors[:extra].first
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

      test "finalize success runs execute and (repeatable) deletes the row" do
        @runner.advance(:a, {"go" => "no"}) # b hidden → a + review only
        res = @runner.finalize
        assert res.completed?
        assert_equal :done, res.value
        # W has no concurrency_key → repeatable → the row is deleted on completion (§4.3).
        assert_nil @store.read("k")
      end

      # ---- identity axes (§4): concurrency resume, one_time retain, repeatable ----

      # A keyed, one-time wizard: retains its completed row at the key (blocks
      # restart; the gate checks it).
      class OneTimeW < Plutonium::Wizard::Base
        concurrency_key { current_user }
        one_time
        step(:a) do
          attribute :go, :string
          validates :go, presence: true
        end
        review label: "R"
        def execute = succeed(:done)
      end

      test "one_time wizard RETAINS the completed row on finish" do
        runner = build_runner(OneTimeW, current_user: "u1")
        runner.advance(:a, {"go" => "ok"})
        res = runner.finalize
        assert res.completed?
        assert_equal "completed", @store.read("k").status
      end

      test "re-entering a completed one_time run is flagged completed_one_time?" do
        runner = build_runner(OneTimeW, current_user: "u1")
        runner.advance(:a, {"go" => "ok"})
        runner.finalize
        reentry = build_runner(OneTimeW, current_user: "u1")
        assert reentry.completed_one_time?
      end

      test "concurrency-keyed launch resumes the existing in_progress row" do
        first = build_runner(OneTimeW, current_user: "u1")
        first.advance(:a, {"go" => "ok"})
        refute first.resumed?, "the first launch starts fresh"

        # A second launch with the same key + context finds the same row.
        second = build_runner(OneTimeW, current_user: "u1")
        assert second.resumed?, "a second launch with the same key resumes, not forks"
        assert_equal({"go" => "ok"}, second.state.data)
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

      # ---- branch-hidden step with persisted records is fully pruned (§6.3) ----

      # Drive a → b (record persisted) → flip a so b is now hidden. Assert the
      # record is rolled back (destroyed by default), its persisted/data/visited
      # state cleared, and the cleared state is durable.
      test "advance that hides a persisted step destroys its record and clears its state" do
        runner = build_runner(BranchPersist)
        runner.advance(:a, {"path" => "x"})
        build_runner(BranchPersist).advance(:b, {"note" => "hi"})

        org = Organization.find_by!(name: "b-record")
        seen = @store.read("k")
        assert_equal [org.to_global_id.to_s], seen.persisted["b"]
        assert_includes seen.visited, "b"
        assert_equal "hi", seen.data["note"]

        # Flip a so b is now branch-hidden.
        build_runner(BranchPersist).advance(:a, {"path" => "y"})

        refute Organization.exists?(id: org.id), "the hidden step's record must be destroyed"
        state = @store.read("k")
        refute state.persisted.key?("b"), "persisted entry for b must be cleared"
        refute state.data.key?("note"), "b's staged data must be dropped"
        refute_includes state.visited, "b", "b must be removed from visited"
      end

      test "advance that hides a persisted step runs its custom on_rollback" do
        runner = build_runner(BranchPersistRollback)
        runner.advance(:a, {"path" => "x"})
        build_runner(BranchPersistRollback).advance(:b, {"note" => "hi"})
        org = Organization.find_by!(name: "b-record")

        build_runner(BranchPersistRollback).advance(:a, {"path" => "y"})

        assert Organization.exists?(id: org.id), "on_rollback soft-deletes; record survives"
        assert_equal "rolled-back", org.reload.name, "custom on_rollback ran instead of destroy"
        refute @store.read("k").persisted.key?("b")
      end

      # Re-entering b after it was un-visited re-runs its on_submit cleanly (a brand
      # new record), since forget_step removed it from visited.
      test "re-entering a pruned branch re-runs on_submit with a fresh record" do
        runner = build_runner(BranchPersist)
        runner.advance(:a, {"path" => "x"})
        build_runner(BranchPersist).advance(:b, {"note" => "first"})
        first = Organization.find_by!(name: "b-record")

        build_runner(BranchPersist).advance(:a, {"path" => "y"}) # b hidden + pruned
        refute Organization.exists?(id: first.id)

        # Path back to x re-exposes b; it was un-visited so on_submit re-runs.
        build_runner(BranchPersist).advance(:a, {"path" => "x"})
        refute_includes @store.read("k").visited, "b", "b is unvisited after pruning"
        build_runner(BranchPersist).advance(:b, {"note" => "second"})

        second = Organization.find_by!(name: "b-record")
        refute_equal first.id, second.id, "a brand new record is created on re-entry"
        assert_equal [second.to_global_id.to_s], @store.read("k").persisted["b"]
      end

      # finalize is a safety net: a branch hidden via seeded/resumed state (not via
      # advance) still has its persisted record rolled back before execute.
      test "finalize leaves no orphaned persisted record after a branch-hide" do
        org = Organization.create!(name: "b-record")
        # Seed a state where b's record is persisted but path now hides b.
        state = Plutonium::Wizard::State.new(
          wizard: BranchPersist.name, instance_key: "k", current_step: "review",
          status: "in_progress",
          data: {"path" => "y", "note" => "stale", "tail" => "t"},
          persisted: {"b" => [org.to_global_id.to_s]},
          visited: %w[a b c]
        )
        @store.write("k", state, cleanup_after: 1.day)

        build_runner(BranchPersist).finalize
        refute Organization.exists?(id: org.id), "finalize must roll back the orphaned record"
      end

      # The lazy-persisted contract must not regress: an advance that hides nothing
      # issues no locate calls beyond what the flow already needed (here: zero).
      test "advance that hides nothing issues no extra locates" do
        runner = build_runner(BranchPersist)
        runner.advance(:a, {"path" => "x"}) # nothing hidden; b becomes visible

        runner = build_runner(BranchPersist)
        locates = counting_locates do
          runner.advance(:c, {"tail" => "t"}) # c is always visible; hides nothing
        end
        assert_equal 0, locates, "an advance that prunes nothing must not locate"
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

      # ---- lazy persisted rehydration (§4.5) ----

      # Run `block` while counting `GlobalID::Locator.locate` calls.
      def counting_locates
        count = 0
        original = GlobalID::Locator.method(:locate)
        GlobalID::Locator.define_singleton_method(:locate) do |*args, **kw|
          count += 1
          original.call(*args, **kw)
        end
        yield
        count
      ensure
        GlobalID::Locator.singleton_class.send(:remove_method, :locate)
        GlobalID::Locator.define_singleton_method(:locate, original)
      end

      def stored_persisting_runner
        org = Organization.create!(name: "Stored")
        state = Plutonium::Wizard::State.new(
          wizard: Persisting.name, instance_key: "k", current_step: "make",
          status: "in_progress", data: {"name" => "Stored"},
          persisted: {"make" => [org.to_global_id.to_s]}
        )
        @store.write("k", state, cleanup_after: 1.day)
        [build_runner(Persisting), org]
      end

      test "a render/no-op that never reads persisted issues zero locate calls" do
        runner, _org = stored_persisting_runner
        locates = counting_locates do
          # build already happened; now a typical GET render touches the path,
          # current step, visited keys — none of which read `persisted`.
          runner.visible_path
          runner.current_step
          runner.visited_keys
          runner.back
        end
        assert_equal 0, locates, "a request that never reads persisted must not locate"
      end

      test "constructing the runner alone issues zero locate calls (lazy)" do
        org = Organization.create!(name: "Stored")
        state = Plutonium::Wizard::State.new(
          wizard: Persisting.name, instance_key: "k", current_step: "make",
          status: "in_progress", data: {"name" => "Stored"},
          persisted: {"make" => [org.to_global_id.to_s]}
        )
        @store.write("k", state, cleanup_after: 1.day)
        locates = counting_locates { build_runner(Persisting) }
        assert_equal 0, locates, "construction must not eagerly rehydrate persisted"
      end

      test "first read of persisted[:key] locates once; second read is memoized" do
        runner, org = stored_persisting_runner

        first_count = counting_locates do
          assert_equal [org], runner.wizard.persisted[:make]
        end
        assert_equal 1, first_count, "first read locates the key's single GID once"

        second_count = counting_locates do
          assert_equal [org], runner.wizard.persisted[:make]
        end
        assert_equal 0, second_count, "second read is served from the memo"
      end

      test "records persisted this request are returned without locating" do
        runner = build_runner(Persisting)
        runner.advance(:make, {"name" => "Acme"})
        org = Organization.find_by!(name: "Acme")

        locates = counting_locates do
          assert_equal [org], runner.wizard.persisted[:make]
        end
        assert_equal 0, locates, "live records from this request's persist need no locate"
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

      # ---- finalize hard failure reverts completing → in_progress (§6.2) ----

      test "finalize hard execute error reverts completing and re-raises" do
        Plutonium::Wizard::Session.delete_all
        store = Plutonium::Wizard::Store::ActiveRecord.new
        runner = build_runner(ExecuteRaises, store: store, key: "ar-raise")
        runner.advance(:a, {"go" => "yes"})

        assert_raises(RuntimeError) do
          build_runner(ExecuteRaises, store: store, key: "ar-raise").finalize
        end

        row = Plutonium::Wizard::Session.find_by!(instance_key: "ar-raise")
        assert row.status_in_progress?, "row must revert to in_progress so the user can retry"
      end

      # ---- RecordNotUnique recovery preserves staged data (Fix 3) ----

      # A store that raises RecordNotUnique on its FIRST write (simulating a
      # concurrent INSERT racing us to the unique instance_key index) and serves a
      # pre-existing row from #read, so the runner must merge + re-write.
      class RacingStore < Plutonium::Wizard::Store::Memory
        def initialize(existing)
          super()
          @existing = existing
          @raised = false
        end

        def read(key)
          @rows[key] ? super : @existing.dup
        end

        def write(key, state, cleanup_after:)
          unless @raised
            @raised = true
            raise ActiveRecord::RecordNotUnique, "raced"
          end
          super
        end
      end

      test "RecordNotUnique recovery merges staged data onto the existing row and re-writes" do
        existing = Plutonium::Wizard::State.new(
          wizard: W.name, instance_key: "race", current_step: "a",
          status: "in_progress", data: {"pre" => "kept"}, persisted: {}, visited: []
        )
        store = RacingStore.new(existing)
        runner = build_runner(W, store: store, key: "race")
        res = runner.advance(:a, {"go" => "yes"})
        assert res.ok?

        stored = store.read("race")
        assert_equal "kept", stored.data["pre"], "pre-existing data must survive the race"
        assert_equal "yes", stored.data["go"], "freshly staged data must survive the race"
        assert_includes stored.visited, "a"
      end

      # ---- visited-set completeness (§6.3) ----

      test "finalize bounces to an unvisited zero-validation step, then completes once submitted" do
        runner = build_runner(WithSkippable)
        runner.advance(:a, {"go" => "yes"}) # a visited+valid; b not yet visited

        # b has no validations but was never visited → finalize must redirect to it.
        res = build_runner(WithSkippable).finalize
        refute res.completed?
        assert_equal :b, res.redirect_step

        # Now visit b, then finalize succeeds.
        build_runner(WithSkippable).advance(:b, {"note" => "hi"})
        done = build_runner(WithSkippable).finalize
        assert done.completed?
        assert_equal :done, done.value
      end

      test "advance stamps the step into the visited set" do
        runner = build_runner(WithSkippable)
        runner.advance(:a, {"go" => "yes"})
        assert_includes @store.read("k").visited, "a"
      end

      test "back does not change the visited set" do
        runner = build_runner(WithSkippable)
        runner.advance(:a, {"go" => "yes"})
        runner = build_runner(WithSkippable)
        runner.advance(:b, {"note" => "hi"})
        runner = build_runner(WithSkippable)
        runner.back
        assert_equal %w[a b].sort, @store.read("k").visited.sort
      end

      # --- owner-scoped resume (§4.5) -----------------------------------------

      # An `anonymous` wizard so we can compare it against a default (authed) one.
      class GuestW < Plutonium::Wizard::Base
        anonymous
        step(:a) { attribute :x, :string }
        review label: "R"
        def execute = succeed(:done)
      end

      test "a non-anonymous run owned by user A is forbidden for user B" do
        a = Organization.create!(name: "User-A")
        b = Organization.create!(name: "User-B")

        # A starts and stages a row at key "k".
        build_runner(W, owner: a, current_user: a).advance(:a, {"go" => "yes"})
        assert_equal a.to_global_id.to_s, @store.read("k").owner.to_global_id.to_s

        # B resumes the SAME key → flagged forbidden, A's row is NOT resumed.
        runner_b = build_runner(W, owner: b, current_user: b)
        assert runner_b.forbidden?, "another user's row must be forbidden"
        refute runner_b.resumed?, "B must not resume A's row"
      end

      test "the owner can resume their own non-anonymous run" do
        a = Organization.create!(name: "User-A")
        build_runner(W, owner: a, current_user: a).advance(:a, {"go" => "yes"})

        runner_a = build_runner(W, owner: a, current_user: a)
        refute runner_a.forbidden?
        assert runner_a.resumed?, "the owner resumes their own row"
      end

      test "an anonymous run is never owner-forbidden (guarded by its run id)" do
        # A guest row has no owner; a different (or no) user at the same key resumes
        # it — the unguessable run id is the only guard, not an owner check.
        build_runner(GuestW).advance(:a, {"x" => "1"})
        assert_nil @store.read("k").owner

        runner = build_runner(GuestW)
        refute runner.forbidden?
        assert runner.resumed?
      end
    end
  end
end
