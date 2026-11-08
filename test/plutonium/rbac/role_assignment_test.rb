# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::RoleAssignmentTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    Plutonium::Rbac::Current.reset
    @org = create_organization!
    @other_org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    OrganizationUser.include(Plutonium::Rbac::Holder) unless OrganizationUser < Plutonium::Rbac::Holder
    OrganizationUser.define_method(:rbac_entity) { organization }
  end

  teardown do
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
  end

  test "tenant role must match the holder's tenant" do
    foreign = Plutonium::Rbac::Role.create!(name: "Foreign", entity: @other_org, permissions: [])
    assignment = Plutonium::Rbac::RoleAssignment.new(holder: @membership, role: foreign)
    refute assignment.valid?
    assert assignment.errors.of_kind?(:role, :rbac_wrong_tenant)
  end

  test "global role can be assigned anywhere" do
    global = Plutonium::Rbac::Role.create!(name: "Global", permissions: [])
    assert Plutonium::Rbac::RoleAssignment.new(holder: @membership, role: global).valid?
  end

  test "escalation guard on assignment" do
    big = Plutonium::Rbac::Role.create!(name: "Big", permissions: ["hr/employee.destroy"])
    Plutonium::Rbac::Current.permission_override = Set["hr/employee.read"]
    Plutonium::Rbac::Current.actor_resolver = -> { :actor }

    assignment = Plutonium::Rbac::RoleAssignment.new(holder: @membership, role: big)
    refute assignment.valid?
    assert assignment.errors.of_kind?(:role, :rbac_not_grantable)
  end

  test "role and holder cannot be changed on an existing assignment" do
    low = Plutonium::Rbac::Role.create!(name: "Low", permissions: [])
    owner = Plutonium::Rbac::Role.create!(name: "Owner", permissions: ["*"], system_role: true)
    other = create_membership!(organization: @org, user: create_user!)
    assignment = Plutonium::Rbac::RoleAssignment.create!(holder: @membership, role: low)

    refute assignment.update(role: owner)
    assert assignment.errors.of_kind?(:role_id, :rbac_readonly)
    refute assignment.reload.update(holder: other)
    assert assignment.errors.of_kind?(:holder_id, :rbac_readonly)
    assert_equal [low.id, @membership.id.to_s], assignment.reload.values_at(:role_id, :holder_id)
  end

  test "loading assignments through either side still works" do
    role = Plutonium::Rbac::Role.create!(name: "Low", permissions: [])
    Plutonium::Rbac::RoleAssignment.create!(holder: @membership, role:)

    assert_equal 1, @membership.rbac_role_assignments.reload.to_a.size
    assert_equal 1, role.assignments.reload.to_a.size
  end

  test "creating an assignment invalidates cached permission keys" do
    reader = Plutonium::Rbac::Role.create!(name: "Reader", permissions: ["hr/employee.read"])
    assert_empty @membership.rbac_permission_keys

    Plutonium::Rbac::RoleAssignment.create!(holder: @membership, role: reader)
    assert_equal Set["hr/employee.read"], @membership.rbac_permission_keys
  end
end
