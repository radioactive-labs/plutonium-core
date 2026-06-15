# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    # Exercises the abandonment sweep (§8.1) against the real AR store + table.
    # An idle in_progress/completing row past its expires_at must be reaped:
    # the wizard's cleanup (on_rollback/destroy of tracked records) runs, then the
    # row is deleted. Completed rows and rows with a null expires_at are never swept.
    class SweepJobTest < ActiveSupport::TestCase
      # A save-as-you-go wizard whose on_submit creates a real, GlobalID-able record.
      # Default cleanup destroys it; this is the partial domain record the sweep
      # must clean up for an abandoned flow.
      class Persisting < Plutonium::Wizard::Base
        step(:make) do
          attribute :name, :string
          on_submit { persist Organization.create!(name: data.name) }
        end
        review label: "R"

        def execute = succeed(:done)
      end

      # Custom on_rollback (soft-delete style) — proves the sweep runs the wizard's
      # compensating block, not a blind destroy.
      class CustomRollback < Plutonium::Wizard::Base
        step(:make) do
          attribute :name, :string
          on_submit { persist Organization.create!(name: data.name) }
          on_rollback { persisted[:make].each { |r| r.update!(name: "swept") } }
        end
        review label: "R"

        def execute = succeed(:done)
      end

      setup do
        Plutonium::Wizard::Session.delete_all
        Organization.delete_all
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

      test "sweep runs the wizard's custom on_rollback instead of a blind destroy" do
        org = stage_persisting(CustomRollback, key: "soft", name: "Acme", expires_at: 1.hour.ago)

        Plutonium::Wizard::SweepJob.perform_now

        assert Organization.exists?(org.id), "custom on_rollback should not destroy the record"
        assert_equal "swept", org.reload.name
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
