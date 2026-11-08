# frozen_string_literal: true

require "test_helper"

# Probe for restricted-attribute inference: RbacProbe::CommentPolicy -> Comment.
module RbacProbe
  class CommentPolicy < Plutonium::Resource::Policy
    include Plutonium::Rbac::Policy
    rbac_restricted_attributes :body
  end
end

class Plutonium::Rbac::CatalogTest < ActiveSupport::TestCase
  setup { Plutonium::Rbac::Catalog.reset! }
  teardown do
    Plutonium::Rbac.declared_permissions.delete("reports.view")
    Plutonium::Rbac::Catalog.reset!
  end

  test "standard permissions per resource" do
    %w[read create update destroy export].each do |action|
      assert Plutonium::Rbac::Catalog.key?("hr/employee.#{action}"), "missing hr/employee.#{action}"
    end
  end

  test "custom definition actions become permissions, built-in ones do not" do
    assert Plutonium::Rbac::Catalog.key?("hr/employee.promote")
    refute Plutonium::Rbac::Catalog.key?("hr/employee.edit")
    refute Plutonium::Rbac::Catalog.key?("hr/employee.show")
    assert_includes Plutonium::Rbac::Catalog.custom_actions_for(Hr::Employee), :promote
  end

  test "resources whose policies do not use RBAC are left out" do
    assert WidgetDefinition
    refute Plutonium::Rbac::Catalog.key?("widget.read")
  end

  test "every build eager loads, so a rebuild after a reload sees every class" do
    calls = 0
    eager_load = Rails.application.config.eager_load
    Rails.application.config.eager_load = false
    Rails.application.singleton_class.define_method(:eager_load!) { calls += 1 }
    Plutonium::Rbac::Catalog.new.build
    Plutonium::Rbac::Catalog.new.build
    assert_equal 2, calls
  ensure
    Rails.application.config.eager_load = eager_load
    Rails.application.singleton_class.remove_method(:eager_load!)
  end

  test "role management is itself in the catalog" do
    %w[read create update destroy export].each do |action|
      assert Plutonium::Rbac::Catalog.key?("rbac_role.#{action}"), "missing rbac_role.#{action}"
    end
  end

  test "declared permissions are included" do
    Plutonium::Rbac.permission "reports.view", label: "View reports"
    Plutonium::Rbac::Catalog.reset!

    permission = Plutonium::Rbac::Catalog.permissions.find { _1.key == "reports.view" }
    assert_equal "View reports", permission.label
  end

  test "grouped returns permissions keyed by group label" do
    groups = Plutonium::Rbac::Catalog.grouped
    assert groups.values.flatten.all?(Plutonium::Rbac::Permission)
  end

  test "restricted attributes add field permissions" do
    assert Plutonium::Rbac::Catalog.key?("comment.body.read")
    assert Plutonium::Rbac::Catalog.key?("comment.body.write")
  end
end
