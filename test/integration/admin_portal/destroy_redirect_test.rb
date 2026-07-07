# frozen_string_literal: true

require "test_helper"

class AdminPortal::DestroyRedirectTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @post = create_post!
  end

  test "delete from the show page falls back to the index instead of the deleted record" do
    show_path = "/admin/blogging/posts/#{@post.id}"

    delete show_path, params: {return_to: show_path}

    assert_redirected_to "/admin/blogging/posts"
  end

  test "delete from the edit page falls back to the index instead of the deleted record" do
    show_path = "/admin/blogging/posts/#{@post.id}"
    edit_path = "#{show_path}/edit"

    delete show_path, params: {return_to: edit_path}

    assert_redirected_to "/admin/blogging/posts"
  end

  test "delete honors a return_to that points somewhere other than the deleted record" do
    show_path = "/admin/blogging/posts/#{@post.id}"
    index_path = "/admin/blogging/posts"

    delete show_path, params: {return_to: index_path}

    assert_redirected_to index_path
  end
end
