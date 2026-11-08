# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Display::Components::RbacPermissionsTest < ActiveSupport::TestCase
  def render_value(permissions, system_role: false)
    role = Plutonium::Rbac::Role.new(name: "Editor", system_role:)
    role.write_attribute(:permissions, permissions)
    html = Plutonium::UI::Display::Base.new(role).field(:permissions).component_for(:rbac_permissions).call
    Nokogiri::HTML.fragment(html)
  end

  test "groups granted permissions by resource" do
    html = render_value(["hr/employee.read", "hr/employee.promote"])
    group = Plutonium::Rbac::Catalog.permissions.find { it.key == "hr/employee.read" }.group

    assert_equal [group], html.css("dt").map { it.text.strip }
    assert_equal %w[Read Promote].sort, html.css("dd span").map { it.text.strip }.sort
  end

  test "keys missing from the catalog stay visible" do
    assert_includes render_value(["gone.read"]).css("dd span").map { it.text.strip }, "gone.read"
  end

  test "the wildcard reads as all permissions" do
    assert_equal "All permissions", render_value(["*"], system_role: true).text.strip
  end
end
