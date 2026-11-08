# frozen_string_literal: true

require "test_helper"

class Plutonium::Rbac::ConfigurationTest < ActiveSupport::TestCase
  test "disabled by default" do
    refute Plutonium::Rbac::Configuration.new.enabled
  end

  test "exposed on the plutonium configuration" do
    assert_kind_of Plutonium::Rbac::Configuration, Plutonium.configuration.rbac
  end

  test "dummy app enables rbac, so its tables exist" do
    ActiveRecord::Base.with_connection do |conn|
      assert conn.table_exists?(:plutonium_rbac_roles)
      assert conn.table_exists?(:plutonium_rbac_role_assignments)
    end
  end

  test "migration path is registered under :rbac" do
    assert_includes Plutonium::Migrations.enabled_paths, Plutonium.root.join("db/migrate/rbac").to_s
  end
end
