# frozen_string_literal: true

require "test_helper"

class AdminPortal::TurboStreamRedirectTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    login_as_admin(@admin)
    @post = create_post!(status: :published)
  end

  test "interactive action emits refresh stream when redirect target matches referer" do
    index_path = "/admin/blogging/posts"

    post "/admin/blogging/posts/#{@post.id}/record_actions/archive",
      params: {return_to: index_path},
      headers: {
        "Referer" => "http://www.example.com#{index_path}",
        "Accept" => "text/vnd.turbo-stream.html"
      }

    assert_response :success
    assert_match %r{<turbo-stream[^>]*action="refresh"}, response.body
    refute_match %r{<turbo-stream[^>]*action="redirect"}, response.body
  end

  test "interactive action emits redirect stream when redirect target differs from referer" do
    index_path = "/admin/blogging/posts"
    show_path = "/admin/blogging/posts/#{@post.id}"

    post "/admin/blogging/posts/#{@post.id}/record_actions/archive",
      params: {return_to: index_path},
      headers: {
        "Referer" => "http://www.example.com#{show_path}",
        "Accept" => "text/vnd.turbo-stream.html"
      }

    assert_response :success
    assert_match %r{<turbo-stream[^>]*action="redirect"}, response.body
    refute_match %r{<turbo-stream[^>]*action="refresh"}, response.body
  end
end
