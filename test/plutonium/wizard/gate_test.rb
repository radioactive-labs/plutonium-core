# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    # Focused tests for the one-time gate concern (§9): the gate recomputes the
    # wizard's instance_key from its `concurrency_key` (folded tenant included) and
    # checks `completed?(instance_key:)`; the redirect/stash-on-incomplete +
    # pass-through-on-complete before_action behavior; entry-path derivation; and
    # the "only one-time wizards are gateable" guard. Driven through a bare
    # anonymous controller (the end-to-end portal flow is in the integration suite).
    class GateTest < ActiveSupport::TestCase
      class UserWizard < Plutonium::Wizard::Base
        concurrency_key { current_user }
        one_time
        step(:welcome) { attribute :ok, :string }
        review label: "R"
        def execute = succeed
      end

      # A repeatable (not one-time) wizard — must NOT be gateable.
      class RepeatableWizard < Plutonium::Wizard::Base
        step(:x) { attribute :ok, :string }
        review label: "R"
        def execute = succeed
      end

      # A minimal host controller mixing in the gate, with the controller surface
      # the gate leans on stubbed out.
      class FakeController
        include Plutonium::Wizard::Gate

        attr_accessor :current_user, :session, :redirected_to, :request_fullpath
        attr_writer :gate_store

        def initialize
          @session = {}
          @request_fullpath = "/dashboard"
        end

        Req = Struct.new(:fullpath)
        def request = Req.new(@request_fullpath)

        def redirect_to(target)
          @redirected_to = target
        end

        # Make the private gate methods callable from tests.
        public :enforce_wizard_completion!, :wizard_completed?, :wizard_gate_instance_key

        # Stub the store + entry path so we exercise pure gate logic. No tenant
        # scoping here (a non-scoped host), so the folded tenant is nil.
        def wizard_gate_store = @gate_store
        def wizard_entry_path(wizard_class) = "/wiz/#{wizard_class.name}"
        def scoped_to_entity? = false
      end

      setup do
        Plutonium::Wizard::Session.delete_all
        Organization.delete_all
        @store = Plutonium::Wizard::Store::ActiveRecord.new
        @user = Organization.create!(name: "User-#{SecureRandom.hex(4)}") # any GlobalID-able owner
        @ctrl = FakeController.new
        @ctrl.current_user = @user
        @ctrl.gate_store = @store
      end

      # ---- gateability guard ----

      test "gating a non-one-time wizard raises" do
        klass = Class.new do
          include Plutonium::Wizard::Gate
        end
        assert_raises(ArgumentError) do
          klass.ensure_wizard_completed(RepeatableWizard)
        end
      end

      # ---- key recomputation matches the runner/driving digest ----

      test "gate recomputes the same instance_key the runner would use" do
        runner_key = Plutonium::Wizard.compute_instance_key(
          wizard_class: UserWizard, current_user: @user,
          current_scoped_entity: nil, anchor: nil, wizard_token: nil
        )
        assert_equal runner_key, @ctrl.wizard_gate_instance_key(UserWizard)
      end

      # ---- gate behavior: not completed → stash + redirect ----

      test "not completed: stashes request.fullpath in return_to and redirects to entry" do
        @ctrl.enforce_wizard_completion!(UserWizard)
        assert_equal "/wiz/#{UserWizard.name}", @ctrl.redirected_to
        assert_equal "/dashboard", @ctrl.session[:return_to]
      end

      test "not completed: does not clobber an existing return_to" do
        @ctrl.session[:return_to] = "/somewhere"
        @ctrl.enforce_wizard_completion!(UserWizard)
        assert_equal "/somewhere", @ctrl.session[:return_to]
      end

      # ---- gate behavior: completed → pass through ----

      test "completed: passes through, no redirect, no stash" do
        complete_at(@ctrl.wizard_gate_instance_key(UserWizard))
        @ctrl.enforce_wizard_completion!(UserWizard)
        assert_nil @ctrl.redirected_to
        refute @ctrl.session.key?(:return_to)
      end

      test "completed for a DIFFERENT user does not satisfy the gate" do
        other = Organization.create!(name: "Other")
        other_ctrl = FakeController.new
        other_ctrl.current_user = other
        other_ctrl.gate_store = @store
        complete_at(other_ctrl.wizard_gate_instance_key(UserWizard))

        # @ctrl (the first user) still has no completion at its own key.
        @ctrl.enforce_wizard_completion!(UserWizard)
        assert_equal "/wiz/#{UserWizard.name}", @ctrl.redirected_to
      end

      # ---- entry-path derivation (default helper-name logic) ----

      test "default entry path derives the register_wizard helper name + first step" do
        ctrl = Class.new { include Plutonium::Wizard::Gate }.new
        captured = nil
        ctrl.define_singleton_method(:onboarding_wizard_path) do |step:|
          captured = step
          "/admin/onboarding/#{step}"
        end
        klass = Class.new(Plutonium::Wizard::Base) do
          def self.name = "OnboardingWizard"
          step(:identity) { attribute :x, :string }
          review label: "R"
          def execute = succeed
        end
        path = ctrl.send(:wizard_entry_path, klass)
        assert_equal "/admin/onboarding/identity", path
        assert_equal :identity, captured
      end

      private

      def complete_at(instance_key)
        Plutonium::Wizard::Session.create!(
          wizard: UserWizard.name, instance_key: instance_key, status: "completed"
        )
      end
    end
  end
end
