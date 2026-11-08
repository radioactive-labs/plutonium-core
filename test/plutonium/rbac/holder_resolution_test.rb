# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::HolderResolutionTest < ActiveSupport::TestCase
  include DataHelpers
  include RbacHelpers

  setup do
    Plutonium::Rbac::Current.reset
    @user = create_user!
    @org = create_organization!
  end

  teardown do
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::Catalog.reset!
  end

  def holder_for(portal: nil, entity_scope: @org) = Plutonium::Rbac.holder_for(user: @user, entity_scope:, portal:)

  test "a nil user has no holder" do
    assert_nil Plutonium::Rbac.holder_for(user: nil, entity_scope: @org)
  end

  test "the dummy's ResourcePolicy resolves the membership inside a tenant only" do
    membership = create_membership!(organization: @org, user: @user)
    assert_equal membership, holder_for
    assert_nil holder_for(entity_scope: nil)
  end

  test "raises when ::ResourcePolicy is not defined" do
    original = ::ResourcePolicy
    Object.send(:remove_const, :ResourcePolicy)
    error = assert_raises(Plutonium::Rbac::NotConfiguredError) { holder_for }
    assert_match(/rbac_holder/, error.message)
    assert_match(/pu:rbac:install/, error.message)
  ensure
    Object.const_set(:ResourcePolicy, original)
  end

  test "a ResourcePolicy using the mixin without overriding rbac_holder denies, without recursing" do
    refute Plutonium::Rbac::Policy.method_defined?(:rbac_holder)
    swap_resource_policy { include Plutonium::Rbac::Policy }

    assert_nil holder_for
    refute Hr::EmployeePolicy.new(Hr::Employee.new, user: @user, entity_scope: @org).read?
  end

  test "a portal concern override applies in that portal only" do
    stub_rbac_holder { :default }
    swap_portal_policy(OrgPortal) { def rbac_holder = :org_portal }

    assert_equal :org_portal, holder_for(portal: OrgPortal)
    assert_equal :default, holder_for(portal: AdminPortal)
    assert_equal :default, holder_for
  end

  test "super from a portal concern reaches the ResourcePolicy default" do
    stub_rbac_holder { :default }
    swap_portal_policy(OrgPortal) { def rbac_holder = [:wrapped, super] }

    assert_equal [:wrapped, :default], holder_for(portal: OrgPortal)
  end

  test "the same user resolves a different holder per portal through Current" do
    stub_rbac_holder { :default }
    swap_portal_policy(OrgPortal) { def rbac_holder = :org_portal }

    Plutonium::Rbac::Current.portal = OrgPortal
    assert_equal :org_portal, Plutonium::Rbac::Current.holder_for(user: @user, entity_scope: @org)
    Plutonium::Rbac::Current.portal = AdminPortal
    assert_equal :default, Plutonium::Rbac::Current.holder_for(user: @user, entity_scope: @org)
  end

  test "a resource without a portal policy still gets the portal's holder" do
    stub_rbac_holder { :default }
    swap_portal_policy(OrgPortal) { def rbac_holder = :org_portal }
    assert_nil "OrgPortal::Hr::EmployeePolicy".safe_constantize

    Plutonium::Rbac::Current.portal = OrgPortal
    policy = Hr::EmployeePolicy.new(Hr::Employee.new, user: @user, entity_scope: @org)
    assert_equal :org_portal, policy.current_rbac_holder
  end

  test "the escalation guard checks grants against the portal's holder" do
    membership = create_membership!(organization: @org, user: @user)
    role = Plutonium::Rbac::Role.create!(name: "Reader #{SecureRandom.hex(3)}", entity: @org, permissions: ["hr/employee.read"])
    membership.update!(rbac_role_ids: [role.id])
    stub_rbac_holder { nil }
    swap_portal_policy(OrgPortal) { def rbac_holder = OrganizationUser.find_by(user:, organization: entity_scope) }

    user, org = @user, @org
    Plutonium::Rbac::Current.actor_resolver = -> { Plutonium::Rbac::Current.holder_for(user:, entity_scope: org) }
    keys = %w[hr/employee.read hr/employee.destroy]

    Plutonium::Rbac::Current.portal = AdminPortal
    assert_equal keys, Plutonium::Rbac.ungrantable_keys(keys)
    Plutonium::Rbac::Current.portal = OrgPortal
    assert_equal %w[hr/employee.destroy], Plutonium::Rbac.ungrantable_keys(keys)
  ensure
    Plutonium::Rbac::RoleAssignment.where(holder: membership).delete_all if membership
    role&.destroy
  end

  test "the per-portal policy class is anonymous, so the catalog skips it" do
    swap_resource_policy do
      include Plutonium::Rbac::Policy

      def rbac_holder = :default
    end
    swap_portal_policy(OrgPortal) { def rbac_holder = :org_portal }
    holder_for(portal: OrgPortal)

    anonymous = ::ResourcePolicy.subclasses.reject(&:name)
    refute_empty anonymous
    Plutonium::Rbac::Catalog.reset!
    refute_includes Plutonium::Rbac::Catalog.send(:new).send(:rbac_policies), anonymous.first
  end

  test "rbac_holder on any other policy class raises at load time" do
    error = assert_raises(RuntimeError) do
      Class.new(Plutonium::Resource::Policy) { def rbac_holder = nil }
    end
    assert_match(/ResourcePolicy/, error.message)
    assert_match(/AdminPortal::ResourcePolicy/, error.message)

    assert_raises(RuntimeError) { Class.new(Hr::EmployeePolicy) { def rbac_holder = nil } }
  end

  test "rbac_holder on ResourcePolicy and portal concerns is allowed" do
    assert_nothing_raised do
      stub_rbac_holder { :default }
      swap_portal_policy(OrgPortal) { def rbac_holder = :org_portal }
    end
  end
end
