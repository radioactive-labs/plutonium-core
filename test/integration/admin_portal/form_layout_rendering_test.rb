# frozen_string_literal: true

require "test_helper"

class AdminPortal::FormLayoutRenderingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
  end

  test "renders section headings and groups fields" do
    get "/admin/kitchen_sinks/new"
    assert_response :success
    assert_includes response.body, "Identity"
    assert_includes response.body, "Who this is"
    assert_includes response.body, "Everything else"
    assert_includes response.body, %(name="kitchen_sink[name]")
    assert_includes response.body, %(name="kitchen_sink[favorite_color]")
  end

  test "collapsible section renders a details element" do
    get "/admin/kitchen_sinks/new"
    assert_match(/<details[^>]*\bopen\b/, response.body)
    assert_includes response.body, "<summary"
  end

  test "a definition without form_layout still renders the single grid" do
    get "/admin/comments/new"
    assert_response :success
    assert_includes response.body, %(name="comment[)
    refute_match(/<details/, response.body)
  end
end
