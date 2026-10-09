# frozen_string_literal: true

require "test_helper"

# Resource controllers must keep Rails' default `protect_from_forgery with: :exception`
# for cookie sessions. A request can't opt out of the check by sending (or leaving
# out) an Authorization header.
class AdminPortal::CsrfProtectionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @post = create_post!
    @forgery_protection_was = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection_was
  end

  test "resource controllers use the exception strategy" do
    assert_equal ActionController::RequestForgeryProtection::ProtectionMethods::Exception,
      AdminPortal::Blogging::PostsController.forgery_protection_strategy
  end

  test "a cookie-session mutation without a token is rejected" do
    delete "/admin/blogging/posts/#{@post.id}"

    assert_response :unprocessable_content
    assert Blogging::Post.exists?(@post.id)
  end

  test "a junk Authorization header does not skip verification" do
    delete "/admin/blogging/posts/#{@post.id}", headers: {"Authorization" => "Bearer junk"}

    assert_response :unprocessable_content
    assert Blogging::Post.exists?(@post.id)
  end

  test "a cookie-session mutation with a valid token succeeds" do
    get "/admin/blogging/posts/#{@post.id}"
    token = css_select("meta[name=csrf-token]").first["content"]

    delete "/admin/blogging/posts/#{@post.id}", headers: {"X-CSRF-Token" => token}

    assert_redirected_to "/admin/blogging/posts"
    refute Blogging::Post.exists?(@post.id)
  end
end
