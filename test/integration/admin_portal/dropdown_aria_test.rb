# frozen_string_literal: true

require "test_helper"

# `resource-drop-down` owns aria-expanded on its trigger from the first show(),
# but the server-rendered markup has to be honest in the window before Stimulus
# hydrates. These tests cover that half — every trigger that reaches a page ships
# a collapsed state — so a new call site can't quietly omit it. The toggling half
# lives in the controller and has no JS test harness in this repo.
class AdminPortal::DropdownAriaTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    login_as_admin(@admin)
  end

  test "index page triggers ship a collapsed aria state" do
    create_post!(user: @user, organization: @org)

    get "/admin/blogging/posts"
    assert_response :success

    # The topbar user menu, the export split-button and the per-row action menu.
    assert_all_triggers_collapsed expected_at_least: 3
  end

  test "show page triggers ship a collapsed aria state" do
    post = create_post!(user: @user, organization: @org)

    get "/admin/blogging/posts/#{post.to_param}"
    assert_response :success

    assert_all_triggers_collapsed
  end

  test "the breadcrumb overflow trigger ships a collapsed aria state" do
    post = create_post!(user: @user, organization: @org)

    get "/admin/blogging/posts/#{post.to_param}/edit"
    assert_response :success

    overflow = trigger_tags.find { |tag| tag.include?("Show collapsed breadcrumbs") }
    assert overflow, "expected the breadcrumb overflow control to render as a dropdown trigger"
    assert_includes overflow, 'aria-expanded="false"'
  end

  private

  def assert_all_triggers_collapsed(expected_at_least: 1)
    triggers = trigger_tags
    assert_operator triggers.size, :>=, expected_at_least,
      "expected at least #{expected_at_least} dropdown trigger(s), got #{triggers.size}"

    triggers.each do |tag|
      assert_includes tag, 'aria-expanded="false"',
        "a resource-drop-down trigger renders without a collapsed aria state: #{tag}"
    end
  end

  # The opening tag of each element carrying the trigger target.
  def trigger_tags
    response.body.scan(/<[a-z]+[^>]*data-resource-drop-down-target="trigger"[^>]*>/)
  end
end
