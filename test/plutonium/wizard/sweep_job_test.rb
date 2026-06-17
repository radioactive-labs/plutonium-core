# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    # Exercises the abandonment sweep (§8.1) against the real AR store + table.
    # An idle in_progress/completing row past its expires_at must be reaped:
    # the wizard's cleanup (each step's on_rollback, then always destroy of tracked
    # records) runs, then the row is deleted. Completed rows and rows with a null
    # expires_at are never swept.
    class SweepJobTest < ActiveSupport::TestCase
      # A save-as-you-go wizard whose on_submit creates a real, GlobalID-able record.
      # Default cleanup destroys it; this is the partial domain record the sweep
      # must clean up for an abandoned flow.
      class Persisting < Plutonium::Wizard::Base
        step(:make) do
          attribute :name, :string
          on_submit { persist Organization.create!(name: data.make.name) }
        end
        review label: "R"

        def execute = succeed(:done)
      end

      # Custom on_rollback that performs an ADDITIONAL side effect — proves the
      # sweep runs the wizard's compensating block AND still destroys the tracked
      # record (on_rollback is additive, not a replacement for the destroy).
      class CustomRollback < Plutonium::Wizard::Base
        @side_effects = []
        class << self
          attr_reader :side_effects
        end

        step(:make) do
          attribute :name, :string
          on_submit { persist Organization.create!(name: data.make.name) }
          on_rollback { persisted[:make].each { |r| CustomRollback.side_effects << r.name } }
        end
        review label: "R"

        def execute = succeed(:done)
      end

      # Captures the tenant the sweep reconstructs — its on_rollback records
      # `current_scoped_entity`, which the runner sets from the passed argument.
      class ScopedRollback < Plutonium::Wizard::Base
        @seen_scope = nil
        class << self
          attr_accessor :seen_scope
        end

        step(:make) do
          attribute :name, :string
          on_submit { persist Organization.create!(name: data.make.name) }
          on_rollback { ScopedRollback.seen_scope = current_scoped_entity }
        end
        review label: "R"

        def execute = succeed(:done)
      end

      setup do
        Plutonium::Wizard::Session.delete_all
        Organization.delete_all
        CustomRollback.side_effects.clear
        ScopedRollback.seen_scope = nil
        @store = Plutonium::Wizard::Store::ActiveRecord.new
      end

      # Stage a real on_submit step through the runner so the row holds the tracked
      # record's GID, then back-date its expires_at to make it sweepable.
      def stage_persisting(klass, key:, name:, expires_at:)
        runner = Plutonium::Wizard::Runner.new(
          wizard_class: klass, store: @store, instance_key: key
        )
        runner.advance(:make, {"name" => name})
        org = Organization.find_by!(name: name)
        Plutonium::Wizard::Session
          .where(instance_key: key)
          .update_all(expires_at: expires_at)
        org
      end

      test "sweeps an expired in_progress row: runs cleanup (destroy) and deletes the row" do
        org = stage_persisting(Persisting, key: "expired", name: "Acme", expires_at: 1.hour.ago)

        Plutonium::Wizard::SweepJob.perform_now

        refute Organization.exists?(org.id), "tracked record must be destroyed by cleanup"
        refute Plutonium::Wizard::Session.exists?(instance_key: "expired"), "swept row must be gone"
      end

      # The sweep must clean up an OWNER-stamped run (the default — non-anonymous
      # wizards stamp the owner). Without adopting the owner, owner-scoping would
      # drop the loaded state and cancel an empty run, orphaning the record.
      test "sweeps an owner-stamped row: still destroys the tracked record" do
        owner = Organization.create!(name: "Owner")
        runner = Plutonium::Wizard::Runner.new(
          wizard_class: Persisting, store: @store, instance_key: "owned",
          owner: owner, current_user: owner
        )
        runner.advance(:make, {"name" => "Acme"})
        org = Organization.find_by!(name: "Acme")
        row = Plutonium::Wizard::Session.find_by!(instance_key: "owned")
        assert_equal owner.to_global_id.to_s, row.owner.to_global_id.to_s, "row is owner-stamped"
        Plutonium::Wizard::Session.where(instance_key: "owned").update_all(expires_at: 1.hour.ago)

        Plutonium::Wizard::SweepJob.perform_now

        refute Organization.exists?(org.id), "owner-scoped tracked record must still be destroyed"
        refute Plutonium::Wizard::Session.exists?(instance_key: "owned"), "swept row must be gone"
      end

      # The sweep reconstructs the run's tenant too, so a tenant-aware on_rollback
      # doesn't run with a nil scope.
      test "sweeps an owner+tenant-scoped row: on_rollback sees the row's tenant" do
        owner = Organization.create!(name: "Owner")
        tenant = Organization.create!(name: "Tenant")
        runner = Plutonium::Wizard::Runner.new(
          wizard_class: ScopedRollback, store: @store, instance_key: "scoped",
          owner: owner, current_user: owner, scope: tenant, current_scoped_entity: tenant
        )
        runner.advance(:make, {"name" => "Acme"})
        Plutonium::Wizard::Session.where(instance_key: "scoped").update_all(expires_at: 1.hour.ago)

        Plutonium::Wizard::SweepJob.perform_now

        assert_equal tenant.to_global_id.to_s, ScopedRollback.seen_scope&.to_global_id.to_s,
          "on_rollback must see the run's tenant, not nil"
        refute Plutonium::Wizard::Session.exists?(instance_key: "scoped")
      end

      test "sweep runs the wizard's custom on_rollback AND still destroys the record" do
        org = stage_persisting(CustomRollback, key: "soft", name: "Acme", expires_at: 1.hour.ago)

        Plutonium::Wizard::SweepJob.perform_now

        # on_rollback ran (additive side effect saw the live record) ...
        assert_equal ["Acme"], CustomRollback.side_effects
        # ... AND the engine still destroyed the tracked record.
        refute Organization.exists?(org.id), "persist'd record is always destroyed on sweep"
        refute Plutonium::Wizard::Session.exists?(instance_key: "soft")
      end

      test "sweeps an expired completing row (crashed mid-finalize)" do
        org = stage_persisting(Persisting, key: "midcommit", name: "Acme", expires_at: 1.hour.ago)
        Plutonium::Wizard::Session.where(instance_key: "midcommit").update_all(status: "completing")

        Plutonium::Wizard::SweepJob.perform_now

        refute Organization.exists?(org.id)
        refute Plutonium::Wizard::Session.exists?(instance_key: "midcommit")
      end

      test "never touches a completed row" do
        org = Organization.create!(name: "Keep")
        Plutonium::Wizard::Session.create!(
          wizard: Persisting.name, instance_key: "done", status: "completed",
          expires_at: 1.hour.ago
        )

        Plutonium::Wizard::SweepJob.perform_now

        assert Plutonium::Wizard::Session.exists?(instance_key: "done"), "completed marker must be kept"
        assert Organization.exists?(org.id)
      end

      test "never touches a not-yet-expired row" do
        org = stage_persisting(Persisting, key: "fresh", name: "Fresh", expires_at: 1.hour.from_now)

        Plutonium::Wizard::SweepJob.perform_now

        assert Plutonium::Wizard::Session.exists?(instance_key: "fresh")
        assert Organization.exists?(org.id)
      end

      test "never touches a null-expiry (cleanup_after :never) row" do
        org = stage_persisting(Persisting, key: "never", name: "Forever", expires_at: nil)

        Plutonium::Wizard::SweepJob.perform_now

        assert Plutonium::Wizard::Session.exists?(instance_key: "never")
        assert Organization.exists?(org.id)
      end

      test "skips an unconstantizable wizard class but still deletes the row" do
        Plutonium::Wizard::Session.create!(
          wizard: "Nonexistent::GhostWizard", instance_key: "ghost", status: "in_progress",
          expires_at: 1.hour.ago
        )

        assert_nothing_raised do
          Plutonium::Wizard::SweepJob.perform_now
        end
        refute Plutonium::Wizard::Session.exists?(instance_key: "ghost"), "row must still be reaped"
      end

      test "is idempotent and safe when a row is already gone" do
        stage_persisting(Persisting, key: "expired", name: "Acme", expires_at: 1.hour.ago)

        Plutonium::Wizard::SweepJob.perform_now
        assert_nothing_raised { Plutonium::Wizard::SweepJob.perform_now }
        assert_equal 0, Plutonium::Wizard::Session.count
      end
    end
  end
end
