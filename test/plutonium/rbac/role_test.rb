# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::RoleTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    Plutonium::Rbac::Current.reset
  end

  teardown do
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
  end

  test "accepts catalog keys and derives key from name" do
    role = Plutonium::Rbac::Role.create!(name: "Post Editor", permissions: ["hr/employee.read", "hr/employee.update"])
    assert_equal "post_editor", role.key
    assert_equal ["hr/employee.read", "hr/employee.update"], role.permissions
  end

  test "rejects unknown keys" do
    role = Plutonium::Rbac::Role.new(name: "Bad", permissions: ["nope.read"])
    refute role.valid?
    assert role.errors.of_kind?(:permissions, :rbac_unknown_permission)
  end

  test "wildcards only on system roles" do
    refute Plutonium::Rbac::Role.new(name: "X", permissions: ["*"]).valid?
    assert Plutonium::Rbac::Role.new(name: "Owner", permissions: ["*"], system_role: true).valid?
  end

  test "key is unique among global roles" do
    Plutonium::Rbac::Role.create!(name: "Viewer", permissions: [])
    refute Plutonium::Rbac::Role.new(name: "Viewer", permissions: []).valid?
  end

  test "the same key is allowed in different tenants" do
    org_a = create_organization!
    org_b = create_organization!
    Plutonium::Rbac::Role.create!(name: "Viewer", entity: org_a, permissions: [])
    assert Plutonium::Rbac::Role.new(name: "Viewer", entity: org_b, permissions: []).valid?
  end

  test "escalation guard: cannot add keys the actor lacks" do
    Plutonium::Rbac::Current.permission_override = Set["hr/employee.read"]
    Plutonium::Rbac::Current.actor_resolver = -> { :actor }

    role = Plutonium::Rbac::Role.new(name: "Sneaky", permissions: ["hr/employee.read", "hr/employee.destroy"])
    refute role.valid?
    assert role.errors.of_kind?(:permissions, :rbac_not_grantable)
  end

  test "escalation guard fails closed for a nil actor" do
    Plutonium::Rbac::Current.actor_resolver = -> {}
    refute Plutonium::Rbac::Role.new(name: "R", permissions: ["hr/employee.read"]).valid?
  end

  test "no actor resolver (console, seeds, sync) skips the guard" do
    assert Plutonium::Rbac::Role.new(name: "R", permissions: ["hr/employee.destroy"]).valid?
  end

  test "the database refuses duplicate global keys" do
    row = {name: "Dup", key: "dup", permissions: [], created_at: Time.current, updated_at: Time.current}
    assert_raises(ActiveRecord::RecordNotUnique) do
      Plutonium::Rbac::Role.insert_all!([row, row.merge(name: "Dup 2")])
    end
  end

  test "an assigned role cannot be destroyed" do
    role = Plutonium::Rbac::Role.create!(name: "Held", permissions: [])
    membership = create_membership!(organization: create_organization!, user: create_user!)
    Plutonium::Rbac::RoleAssignment.create!(holder: membership, role:)

    refute role.destroy
    assert Plutonium::Rbac::Role.exists?(role.id)

    Plutonium::Rbac::RoleAssignment.delete_all
    assert role.reload.destroy
  end
end
