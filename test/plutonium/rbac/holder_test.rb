# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::HolderTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    Plutonium::Rbac::Current.reset
    OrganizationUser.include(Plutonium::Rbac::Holder) unless OrganizationUser < Plutonium::Rbac::Holder
    OrganizationUser.define_method(:rbac_entity) { organization }

    @org = create_organization!
    @membership = create_membership!(organization: @org, user: create_user!)
    @reader = Plutonium::Rbac::Role.create!(name: "Reader", permissions: ["hr/employee.read"])
    @writer = Plutonium::Rbac::Role.create!(name: "Writer", permissions: ["hr/employee.create"])
  end

  teardown do
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
  end

  test "permission keys are the union of roles" do
    @membership.update!(rbac_role_ids: [@reader.id, @writer.id])
    assert_equal Set["hr/employee.read", "hr/employee.create"], @membership.rbac_permission_keys
  end

  test "keys are cached per request" do
    @membership.update!(rbac_role_ids: [@reader.id])
    @membership.rbac_permission_keys
    queries = 0
    counter = ->(*) { queries += 1 }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { @membership.rbac_permission_keys }
    assert_equal 0, queries
  end

  test "wildcard grant" do
    owner = Plutonium::Rbac::Role.create!(name: "Owner", permissions: ["*"], system_role: true)
    @membership.update!(rbac_role_ids: [owner.id])
    assert @membership.rbac_granted?("anything.at_all")
  end

  test "removing roles" do
    @membership.update!(rbac_role_ids: [@reader.id, @writer.id])
    @membership.update!(rbac_role_ids: [@reader.id])
    assert_equal [@reader.id], @membership.rbac_role_assignments.pluck(:role_id)
    assert_equal Set["hr/employee.read"], @membership.rbac_permission_keys
  end

  test "invalid staged role blocks save and leaves assignments alone" do
    foreign = Plutonium::Rbac::Role.create!(name: "Foreign", entity: create_organization!, permissions: [])
    refute @membership.update(rbac_role_ids: [foreign.id])
    assert @membership.errors[:rbac_roles].any?
    assert_empty @membership.rbac_role_assignments.reload
  end

  test "blank ids from a form are ignored" do
    @membership.update!(rbac_role_ids: ["", @reader.id.to_s])
    assert_equal [@reader.id], @membership.rbac_role_ids
  end

  test "assigning roles stages them until save" do
    @membership.rbac_roles = [@reader]
    assert_empty Plutonium::Rbac::RoleAssignment.where(holder: @membership)

    @membership.save!
    assert_equal [@reader.id], @membership.rbac_role_assignments.pluck(:role_id)
    assert_equal [@reader], @membership.rbac_roles.to_a
  end

  test "an invalid role assigned as a record fails validation instead of raising" do
    foreign = Plutonium::Rbac::Role.create!(name: "Foreign", entity: create_organization!, permissions: [])
    @membership.rbac_roles = [foreign]
    refute @membership.save
    assert @membership.errors[:rbac_roles].any?
    assert_empty @membership.rbac_role_assignments.reload
  end

  test "the association input's sgid writer stages through rbac_roles=" do
    foreign = Plutonium::Rbac::Role.create!(name: "Foreign", entity: create_organization!, permissions: [])
    @membership.assign_attributes(rbac_role_sgids: [@reader.to_signed_global_id.to_s, foreign.to_signed_global_id.to_s])
    assert_empty Plutonium::Rbac::RoleAssignment.where(holder: @membership)
    refute @membership.save

    @membership.assign_attributes(rbac_role_sgids: [@reader.to_signed_global_id.to_s])
    assert @membership.save
    assert_equal [@reader.id], @membership.rbac_role_assignments.pluck(:role_id)
  end

  test "Rails' assignment writers are refused" do
    assert_raises(ArgumentError) { @membership.rbac_role_assignment_ids = [] }
    assert_raises(ArgumentError) { @membership.rbac_role_assignments = [] }
  end

  test "rbac_roles= only takes roles" do
    assert_raises(ActiveRecord::AssociationTypeMismatch) { @membership.rbac_roles = [@reader, User.new] }
  end

  test "non-integer ids fail validation instead of raising" do
    @membership.rbac_role_ids = ["abc"]
    refute @membership.save
    assert @membership.errors[:rbac_roles].any?

    @membership.rbac_role_ids = [@reader.id.to_s.rjust(3, "0")]
    assert @membership.save
    assert_equal [@reader.id], @membership.rbac_role_assignments.pluck(:role_id)
  end

  test "add and remove sgid helpers stage through validation" do
    foreign = Plutonium::Rbac::Role.create!(name: "Foreign", entity: create_organization!, permissions: [])
    @membership.add_rbac_role_sgid(foreign.to_signed_global_id.to_s)
    assert_empty Plutonium::Rbac::RoleAssignment.where(holder: @membership)
    refute @membership.save

    @membership.rbac_role_ids = []
    @membership.add_rbac_role_sgid(@reader.to_signed_global_id.to_s)
    @membership.add_rbac_role_sgid(@writer.to_signed_global_id.to_s)
    @membership.save!
    assert_equal [@reader.id, @writer.id].sort, @membership.rbac_role_assignments.pluck(:role_id).sort

    @membership.remove_rbac_role_sgid(@reader.to_signed_global_id.to_s)
    assert_equal 2, @membership.rbac_role_assignments.count
    @membership.save!
    assert_equal [@writer.id], @membership.rbac_role_assignments.pluck(:role_id)
  end

  test "changing a role's permissions invalidates cached keys" do
    @membership.update!(rbac_role_ids: [@reader.id])
    assert_equal Set["hr/employee.read"], @membership.rbac_permission_keys

    @reader.update!(permissions: ["hr/employee.read", "hr/employee.update"])
    assert_equal Set["hr/employee.read", "hr/employee.update"], @membership.rbac_permission_keys
  end
end
