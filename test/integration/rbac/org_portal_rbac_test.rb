# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# End to end in a `:path` entity-scoped portal: Hr policies use
# Plutonium::Rbac::Policy, so a member's tenant roles decide what they can do.
class OrgPortalRbacTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    Hr::Employee.delete_all

    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    @employee = Hr::Employee.create!(organization: @org, name: "Ada", salary: 98_765)
  end

  teardown do
    Plutonium::Rbac::RoleAssignment.delete_all
    Plutonium::Rbac::Role.delete_all
    Hr::Employee.delete_all
  end

  def prefix = "/org/#{@org.to_param}"

  def employee_path = "#{prefix}/hr/employees/#{@employee.id}"

  def grant(*keys)
    role = Plutonium::Rbac::Role.create!(name: "Role #{SecureRandom.hex(3)}", entity: @org, permissions: keys)
    @membership.update!(rbac_role_ids: @membership.rbac_role_ids + [role.id])
  end

  test "a granted read and custom action are allowed, an ungranted destroy is not" do
    grant("hr/employee.read", "hr/employee.promote")
    login_as(@user, portal: :user)

    get "#{prefix}/hr/employees"
    assert_response :success
    assert_includes response.body, "Ada"

    post "#{employee_path}/record_actions/promote",
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
    assert_response :success
    assert_equal "Ada (promoted)", @employee.reload.name

    delete employee_path
    assert_response :forbidden
    assert Hr::Employee.exists?(@employee.id)
  end

  test "an ungranted custom action is denied" do
    grant("hr/employee.read")
    login_as(@user, portal: :user)

    post "#{employee_path}/record_actions/promote",
      headers: {"Accept" => "text/vnd.turbo-stream.html"}
    assert_response :forbidden
    assert_equal "Ada", @employee.reload.name
  end

  test "a restricted field is hidden without its field grant" do
    grant("hr/employee.read")
    login_as(@user, portal: :user)

    get employee_path
    assert_response :success
    assert_includes response.body, "Ada"
    refute_match(/98,?765/, response.body)

    get "#{prefix}/hr/employees"
    refute_match(/98,?765/, response.body)
  end

  test "a restricted field is shown with its field grant" do
    grant("hr/employee.read", "hr/employee.salary.read")
    login_as(@user, portal: :user)

    get employee_path
    assert_response :success
    assert_match(/98,?765/, response.body)
  end

  test "the new-role page renders the permission grid" do
    grant("rbac_role.read", "rbac_role.create")
    login_as(@user, portal: :user)

    get "#{prefix}/rbac_roles/new"
    assert_response :success
    assert_includes response.body, 'name="rbac_role[permissions][]"'
    assert_includes response.body, 'data-controller="rbac-permissions"'
    assert_includes response.body, 'value="hr/employee.promote"'
  end

  test "a member creates a tenant role from the grid, tied to the current org" do
    grant("rbac_role.read", "rbac_role.create", "hr/employee.read")
    login_as(@user, portal: :user)

    assert_difference -> { Plutonium::Rbac::Role.count }, 1 do
      post "#{prefix}/rbac_roles", params: {rbac_role: {name: "Viewers", permissions: ["", "hr/employee.read"]}}
    end

    role = Plutonium::Rbac::Role.find_by!(name: "Viewers")
    assert_equal @org, role.entity
    assert_equal ["hr/employee.read"], role.permissions
  end

  test "a member cannot create a role granting a key they lack" do
    grant("rbac_role.read", "rbac_role.create")
    login_as(@user, portal: :user)

    post "#{prefix}/rbac_roles", params: {rbac_role: {name: "Escalate", permissions: ["", "hr/employee.destroy"]}}
    assert_response :unprocessable_entity
    refute Plutonium::Rbac::Role.exists?(name: "Escalate")
  end
end
