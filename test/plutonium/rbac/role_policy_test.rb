# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::RolePolicyTest < ActiveSupport::TestCase
  include IntegrationTestHelper
  include RbacHelpers

  setup do
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    stub_rbac_holder { user }
    @org = create_organization!
    @other = create_organization!
    @user = create_user!
    @global = Plutonium::Rbac::Role.create!(name: "Global", permissions: [])
    @system = Plutonium::Rbac::Role.create!(name: "Owner", permissions: ["*"], system_role: true)
    @mine = Plutonium::Rbac::Role.create!(name: "Mine", entity: @org, permissions: [])
    @theirs = Plutonium::Rbac::Role.create!(name: "Theirs", entity: @other, permissions: [])
    Plutonium::Rbac::Current.permission_override = Set["rbac_role.*"]
  end

  teardown do
    Plutonium::Rbac::Current.reset
    Plutonium::Rbac::Role.delete_all
  end

  def policy(record, entity_scope:)
    Plutonium::Rbac::RolePolicy.new(record, user: @user, entity_scope:)
  end

  def scoped_ids(entity_scope:)
    policy(Plutonium::Rbac::Role, entity_scope:)
      .apply_scope(Plutonium::Rbac::Role.all, type: :active_record_relation)
      .pluck(:id).sort
  end

  test "tenant scope: global + own, never another tenant's" do
    assert_equal [@global, @system, @mine].map(&:id).sort, scoped_ids(entity_scope: @org)
  end

  test "unscoped portal sees global roles only" do
    assert_equal [@global, @system].map(&:id).sort, scoped_ids(entity_scope: nil)
  end

  test "system roles and other-scope roles are read-only" do
    refute policy(@system, entity_scope: nil).update?
    refute policy(@system, entity_scope: nil).destroy?
    refute policy(@global, entity_scope: @org).update?
    refute policy(@global, entity_scope: @org).destroy?
    assert policy(@mine, entity_scope: @org).update?
    assert policy(@global, entity_scope: nil).destroy?
  end

  test "the index leaves out the permission list" do
    refute_includes policy(Plutonium::Rbac::Role, entity_scope: nil).permitted_attributes_for_index, :permissions
    assert_includes policy(@mine, entity_scope: @org).permitted_attributes_for_show, :permissions
  end

  test "management is RBAC-gated" do
    Plutonium::Rbac::Current.permission_override = Set["rbac_role.read"]

    assert policy(@mine, entity_scope: @org).read?
    refute policy(@mine, entity_scope: @org).update?
    refute policy(Plutonium::Rbac::Role, entity_scope: @org).create?
  end

  test "create? on a record requires the current tenant" do
    Plutonium::Rbac::Current.permission_override = Set["rbac_role.create"]

    assert policy(Plutonium::Rbac::Role, entity_scope: @org).create?
    assert policy(Plutonium::Rbac::Role.new(entity: @org), entity_scope: @org).create?
    refute policy(Plutonium::Rbac::Role.new(entity: @other), entity_scope: @org).create?
    refute policy(Plutonium::Rbac::Role.new, entity_scope: @org).create?
    assert policy(Plutonium::Rbac::Role.new, entity_scope: nil).create?
    refute policy(Plutonium::Rbac::Role.new(entity: @org), entity_scope: nil).create?
  end
end
