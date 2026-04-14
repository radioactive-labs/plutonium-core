# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::PortalAccessTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::PortalAccess

  portal_access_for portals: %i[admin org],
    matrix: {admin: %i[admin], member: %i[org]}

  setup do
    @admin = create_admin!
    @user = create_user!
    @org = create_organization!
    create_membership!(organization: @org, user: @user)
  end

  def login_as_role(role_sym)
    case role_sym
    when :admin then login_as(@admin, portal: :admin)
    when :member then login_as(@user, portal: :user)
    end
  end

  def portal_root_path(portal_sym)
    case portal_sym
    when :admin then "/admin"
    when :org then "/org/#{@org.id}"
    end
  end
end
