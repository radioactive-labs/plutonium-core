# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::SyncTest < ActiveSupport::TestCase
  setup do
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    @saved = Plutonium::Rbac.system_roles.dup
    Plutonium::Rbac.system_roles.clear
    Plutonium::Rbac.system_role :owner, name: "Owner", permissions: ["*"]
  end

  teardown do
    Plutonium::Rbac.system_roles.replace(@saved)
    Plutonium::Rbac::Role.delete_all
  end

  test "creates and then updates system roles idempotently" do
    Plutonium::Rbac::Sync.call
    Plutonium::Rbac.system_role :owner, name: "Account Owner", permissions: ["*"]
    Plutonium::Rbac::Sync.call

    roles = Plutonium::Rbac::Role.global.where(key: "owner")
    assert_equal 1, roles.count
    assert_equal "Account Owner", roles.first.name
    assert roles.first.system_role?
  end

  test "refuses to take over a global role that is not a system role" do
    custom = Plutonium::Rbac::Role.create!(name: "Custom Owner", key: "owner", permissions: [])

    assert_raises(Plutonium::Rbac::Sync::ConflictError) { Plutonium::Rbac::Sync.call }
    custom.reload
    refute custom.system_role?
    assert_equal "Custom Owner", custom.name
  end

  test "a failing role rolls back the whole sync" do
    Plutonium::Rbac.system_role :viewer, name: "Viewer", permissions: ["nope.read"]

    assert_raises(ActiveRecord::RecordInvalid) { Plutonium::Rbac::Sync.call }
    assert_equal 0, Plutonium::Rbac::Role.count
  end
end
