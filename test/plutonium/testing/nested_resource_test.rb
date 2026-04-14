# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::NestedResourceTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::NestedResource

  resource_tests_for Blogging::Post, portal: :org, parent: :organization

  setup do
    @user = create_user!
    @org_a = create_organization!
    @org_b = create_organization!
    create_membership!(organization: @org_a, user: @user)
    create_membership!(organization: @org_b, user: @user)
    login_as(@user, portal: :user)
  end

  def parent_record!; @org_a; end
  def other_parent_record!; @org_b; end

  def create_resource!(parent:)
    create_post!(user: @user, organization: parent)
  end
end
