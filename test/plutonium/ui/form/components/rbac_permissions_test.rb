# frozen_string_literal: true

require "test_helper"

class Plutonium::UI::Form::Components::RbacPermissionsTest < ActiveSupport::TestCase
  def component(role) = Plutonium::UI::Form::Base.new(role).field(:permissions).component_for(:rbac_permissions)

  def render_input(permissions: [])
    Nokogiri::HTML.fragment(component(Plutonium::Rbac::Role.new(name: "Editor", permissions:)).call)
  end

  def permission_boxes(html) = html.css("input[type=checkbox][data-rbac-permissions-target=permission]")

  test "one checkbox per catalog key under a collection param" do
    boxes = permission_boxes(render_input)

    assert_equal Plutonium::Rbac::Catalog.keys.sort, boxes.map { _1["value"] }.sort
    assert boxes.all? { _1["name"] == "rbac_role[permissions][]" }
    assert boxes.any? { _1["value"] == "hr/employee.promote" }
  end

  test "a blank hidden input keeps an empty selection submittable" do
    hidden = render_input.at_css("input[type=hidden]")

    assert_equal "rbac_role[permissions][]", hidden["name"]
    assert_equal "", hidden["value"]
  end

  test "wired to the rbac-permissions controller" do
    assert render_input.at_css("[data-controller=rbac-permissions]")
  end

  test "checkboxes are grouped by resource" do
    html = render_input
    groups = html.css("fieldset[data-rbac-permissions-target=group]")

    assert_equal Plutonium::Rbac::Catalog.grouped.keys, groups.map { _1.at_css("legend").text.strip }
    assert html.css("[data-action='rbac-permissions#toggleAction']").any?
  end

  test "checked state reflects the record" do
    html = render_input(permissions: ["hr/employee.read"])

    assert_equal ["hr/employee.read"], html.css("input[data-rbac-permissions-target=permission][checked]").map { _1["value"] }
  end

  test "extracts the submitted keys without the blank" do
    extracted = component(Plutonium::Rbac::Role.new).extract_input({permissions: ["", "hr/employee.read", "hr/employee.update"]})

    assert_equal({permissions: ["hr/employee.read", "hr/employee.update"]}, extracted)
  end

  test "an all-blank submission extracts an empty list" do
    assert_equal({permissions: []}, component(Plutonium::Rbac::Role.new).extract_input({permissions: [""]}))
  end
end
