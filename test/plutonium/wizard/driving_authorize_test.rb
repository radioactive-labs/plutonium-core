# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    # Regression test for {Plutonium::Wizard::Driving#authorize_wizard_entry!}.
    #
    # Before the fix the denial path (`wizard.authorize?` -> false) crashed two
    # different ways:
    #
    #   1. `ActionPolicy::Unauthorized` (no leading `::`) resolved to the
    #      `Plutonium::ActionPolicy` namespace (which only defines
    #      `StiPolicyLookup`), raising `NameError: uninitialized constant
    #      Plutonium::ActionPolicy::Unauthorized`.
    #   2. Even with the `::`, `ActionPolicy::Unauthorized.new(policy, rule,
    #      result = policy.result)` calls `policy.result` on its first arg. The
    #      buggy code passed `wizard.class` (a Class), so this raised
    #      `NoMethodError: undefined method 'result' for class <WizardClass>`.
    #
    # The denial path was never exercised by existing wizards (they use
    # `authorize? = current_user.present?` behind auth constraints, so it is
    # always true). These tests drive the path directly through a bare host
    # including the Driving concern.
    class DrivingAuthorizeTest < ActiveSupport::TestCase
      class AllowWizard < Plutonium::Wizard::Base
        step(:only) { attribute :name, :string }
        review label: "R"
        def execute = succeed
        def authorize? = true
      end

      class DenyWizard < Plutonium::Wizard::Base
        step(:only) { attribute :name, :string }
        review label: "R"
        def execute = succeed
        def authorize? = false
      end

      # `authorize_wizard_entry!` only touches `runner.wizard` (then
      # `wizard.authorize?`), so a bare host mixing in the concern is enough.
      class FakeHost
        include Plutonium::Wizard::Driving
      end

      def runner_for(wizard) = Struct.new(:wizard).new(wizard)
      def host = @host ||= FakeHost.new

      test "entry is allowed when authorize? returns true (no raise)" do
        assert_nil host.send(:authorize_wizard_entry!, runner_for(AllowWizard.new))
      end

      test "denied entry raises ::ActionPolicy::Unauthorized, not NameError or NoMethodError" do
        wizard = DenyWizard.new
        err = assert_raises(::ActionPolicy::Unauthorized) do
          host.send(:authorize_wizard_entry!, runner_for(wizard))
        end

        assert_same ::ActionPolicy::Unauthorized, err.class
        refute err.is_a?(NameError), "must not be the namespace-collision NameError"

        # ActionPolicy::Unauthorized stores the policy CLASS (`@policy =
        # policy.class`), so the wizard instance's class is what's reported.
        assert_equal wizard.class, err.policy
        assert_equal :authorize?, err.rule

        # The shared rescue_from (lib/plutonium/core/controller.rb) surfaces
        # `exception.result.message`; the explicit result must answer it.
        assert_equal "Wizard authorization denied", err.result.message
      end

      test "the exception is the top-level ::ActionPolicy::Unauthorized despite the Plutonium::ActionPolicy namespace" do
        assert defined?(Plutonium::ActionPolicy),
          "precondition: the colliding Plutonium::ActionPolicy namespace exists"

        err = assert_raises(::ActionPolicy::Unauthorized) do
          host.send(:authorize_wizard_entry!, runner_for(DenyWizard.new))
        end

        assert_same ::ActionPolicy::Unauthorized, err.class
        refute err.class.name.start_with?("Plutonium::ActionPolicy"),
          "must be the top-level gem class, not the Plutonium::ActionPolicy namespace"
      end

      test "each denial builds a fresh result object (no shared mutable state)" do
        r1 = assert_raises(::ActionPolicy::Unauthorized) do
          host.send(:authorize_wizard_entry!, runner_for(DenyWizard.new))
        end
        r2 = assert_raises(::ActionPolicy::Unauthorized) do
          host.send(:authorize_wizard_entry!, runner_for(DenyWizard.new))
        end

        refute_same r1.result, r2.result
        assert_equal "Wizard authorization denied", r1.result.message
        assert_equal "Wizard authorization denied", r2.result.message
      end
    end
  end
end
