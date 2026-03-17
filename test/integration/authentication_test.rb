# frozen_string_literal: true

require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  test "admin portal redirects unauthenticated users" do
    get "/admin"
    assert_response :redirect
  end

  test "org portal redirects unauthenticated users" do
    org = create_organization!
    get "/org/#{org.to_param}"
    assert_response :redirect
  end

  test "dashboard portal redirects unauthenticated users" do
    get "/locus"
    assert_response :redirect
  end

  test "storefront portal allows unauthenticated access" do
    get "/storefront"
    assert_response :success
  end

  test "admin login with valid credentials" do
    admin = create_admin!
    post "/admins/login", params: {email: admin.email, password: "password123"}
    assert_response :redirect
    follow_redirect!
    # Should be able to access admin portal now
    get "/admin"
    assert_response :success
  end

  test "user login with valid credentials" do
    user = create_user!
    post "/users/login", params: {email: user.email, password: "password123"}
    assert_response :redirect
    follow_redirect!
    # Should be able to access dashboard portal now
    get "/locus"
    assert_response :success
  end
end
