# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Wizard
    # Focused tests for the one-time gate concern (§9): completion keying per
    # `one_time_scope`, the redirect/stash-on-incomplete + pass-through-on-complete
    # before_action behavior, and entry-path derivation. Driven through a bare
    # anonymous controller so the gate is exercised without full portal route wiring
    # (the end-to-end portal flow is covered by the integration suite).
    class GateTest < ActiveSupport::TestCase
      class UserWizard < Plutonium::Wizard::Base
        one_time once_per: :user
        step(:welcome) { attribute :ok, :string }
        review label: "R"
        def execute = succeed
      end

      class AnchorWizard < Plutonium::Wizard::Base
        one_time once_per: :anchor
        anchored with: Organization
        step(:setup) { attribute :ok, :string }
        review label: "R"
        def execute = succeed(anchor)
      end

      # A minimal host controller mixing in the gate, with the controller surface
      # the gate leans on stubbed out.
      class FakeController
        include Plutonium::Wizard::Gate

        attr_accessor :current_user, :session, :redirected_to, :request_fullpath
        attr_writer :gate_store, :gate_anchor

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
        public :enforce_wizard_completion!, :wizard_completed?, :wizard_completion_key

        # Stub the store + anchor + entry path so we exercise pure gate logic.
        def wizard_gate_store = @gate_store
        def wizard_gate_anchor(_wizard_class) = @gate_anchor
        def wizard_entry_path(wizard_class) = "/wiz/#{wizard_class.name}"
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

      # ---- completion keying ----

      test "once_per: :user keys completion by owner: current_user" do
        key = @ctrl.wizard_completion_key(UserWizard)
        assert_equal({wizard: UserWizard.name, owner: @user}, key)
      end

      test "once_per: :anchor keys completion by the resolved anchor" do
        anchor = Organization.create!(name: "Workspace")
        @ctrl.gate_anchor = anchor
        key = @ctrl.wizard_completion_key(AnchorWizard)
        assert_equal({wizard: AnchorWizard.name, anchor: anchor}, key)
      end

      test "wizard_gate_anchor raises by default (must be overridden)" do
        bare = Class.new { include Plutonium::Wizard::Gate }.new
        assert_raises(NotImplementedError) do
          bare.send(:wizard_gate_anchor, AnchorWizard)
        end
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

      test "completed (user): passes through, no redirect, no stash" do
        complete_for_user(UserWizard, @user)
        @ctrl.enforce_wizard_completion!(UserWizard)
        assert_nil @ctrl.redirected_to
        refute @ctrl.session.key?(:return_to)
      end

      test "completed for a DIFFERENT user does not satisfy the gate" do
        other = Organization.create!(name: "Other")
        complete_for_user(UserWizard, other)
        @ctrl.enforce_wizard_completion!(UserWizard)
        assert_equal "/wiz/#{UserWizard.name}", @ctrl.redirected_to
      end

      test "completed (anchor): passes through when the anchor matches" do
        anchor = Organization.create!(name: "Workspace")
        @ctrl.gate_anchor = anchor
        complete_for_anchor(AnchorWizard, anchor)
        @ctrl.enforce_wizard_completion!(AnchorWizard)
        assert_nil @ctrl.redirected_to
      end

      # ---- entry-path derivation (default helper-name logic) ----

      test "default entry path derives the register_wizard helper name + first step" do
        # A bare host that includes the gate but does NOT override wizard_entry_path,
        # so the real default helper-name derivation runs.
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

      def complete_for_user(wizard, owner)
        Plutonium::Wizard::Session.create!(
          wizard: wizard.name, instance_key: SecureRandom.hex,
          status: "completed", owner: owner
        )
      end

      def complete_for_anchor(wizard, anchor)
        Plutonium::Wizard::Session.create!(
          wizard: wizard.name, instance_key: SecureRandom.hex,
          status: "completed", anchor: anchor
        )
      end
    end
  end
end
