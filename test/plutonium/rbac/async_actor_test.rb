# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::AsyncActorTest < ActiveSupport::TestCase
  include DataHelpers
  include RbacHelpers

  setup do
    Plutonium::Interaction::Async::Run.delete_all
    Plutonium::Rbac::Current.reset
    @user = create_user!
    @org = create_organization!
  end

  teardown do
    Plutonium.configuration.rbac.enabled = true
    Plutonium::Rbac::Current.reset
    Plutonium::Interaction::Async::Run.delete_all
  end

  def create_run!(namespace: nil, policy_class_name: "Blogging::PostPolicy")
    TestPostRun.create!(
      initiator: @user, scoped_entity: @org,
      target_type: "Blogging::Post", target_ids: [],
      authorization_namespace: namespace,
      policy_class_name:, policy_action: "touch?"
    )
  end

  test "rebuilding a run's context installs the actor resolver for the initiator and tenant" do
    seen = nil
    stub_rbac_holder do
      seen = [user, entity_scope]
      :holder
    end

    Plutonium::Interaction::Async::Context.new(create_run!)

    assert Plutonium::Rbac::Current.enforcing?
    assert_nil Plutonium::Rbac::Current.portal
    assert_equal :holder, Plutonium::Rbac::Current.actor
    assert_equal [@user, @org], seen
  end

  test "a run resolves the holder through its stored portal namespace" do
    stub_rbac_holder { :default }
    swap_portal_policy(OrgPortal) { def rbac_holder = :org_portal }

    Plutonium::Interaction::Async::Context.new(
      create_run!(namespace: "OrgPortal", policy_class_name: "OrgPortal::Blogging::PostPolicy")
    )

    assert_equal OrgPortal, Plutonium::Rbac::Current.portal
    assert_equal :org_portal, Plutonium::Rbac::Current.actor
  end

  test "nothing is installed when RBAC is disabled" do
    Plutonium.configuration.rbac.enabled = false
    Plutonium::Interaction::Async::Context.new(create_run!)
    refute Plutonium::Rbac::Current.enforcing?
  end
end
