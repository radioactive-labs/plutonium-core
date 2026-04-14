# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::AuthHelpersTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::DSL
  include Plutonium::Testing::AuthHelpers

  resource_tests_for Blogging::Post, portal: :admin

  test "login_as uses default portal from DSL" do
    admin = create_admin!
    login_as(admin)
    get "/admin"
    assert_response :success
    assert_equal admin, current_account
  end

  test "login_as with explicit portal kwarg" do
    user = create_user!
    login_as(user, portal: :user)
    assert_equal user, current_account(portal: :user)
  end

  test "with_portal switches default for block scope" do
    with_portal(:user) do
      assert_equal :user, current_portal
    end
    assert_equal :admin, current_portal
  end

  test "sign_out clears current_account" do
    admin = create_admin!
    login_as(admin)
    sign_out
    assert_nil current_account
  end
end

class Plutonium::Testing::AuthHelpersOverrideTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::DSL
  include Plutonium::Testing::AuthHelpers

  resource_tests_for Blogging::Post, portal: :admin

  attr_reader :sign_in_calls

  def sign_in_for_tests(account, portal:)
    @sign_in_calls ||= []
    @sign_in_calls << [account, portal]
  end

  test "delegates to sign_in_for_tests when defined" do
    admin = Admin.new(email: "x@example.com")
    login_as(admin)
    assert_equal [[admin, :admin]], sign_in_calls
  end
end
