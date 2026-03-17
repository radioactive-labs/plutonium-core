# frozen_string_literal: true

require "test_helper"

class OrgPortal::BloggingPostsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include SharedTests::BloggingPostTests

  setup do
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
    login_as_user(@user)
  end

  def path_prefix
    "/org/#{@org.to_param}"
  end

  test "scoping: only shows posts from current organization" do
    my_post = create_post!(organization: @org)
    other_org = create_organization!
    other_post = create_post!(organization: other_org)

    get "#{path_prefix}/blogging/posts"
    assert_response :success
    assert_match my_post.title, response.body
    refute_match other_post.title, response.body
  end
end
