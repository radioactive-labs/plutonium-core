# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# The OrgPortal is path-scoped (`/org/:organization_scoped`), so it has no
# bare `/org` route and the app has no root. Without a bridge, a logged-in
# user lands nowhere after sign-in. HomeController resolves the user's first
# organization and redirects both the app root and the bare portal mount
# into the scoped portal root (`/org/<id>`).
class OrgPortal::EntityEntryRedirectTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
  end

  test "unauthenticated root and bare /org redirect to login" do
    get "/"
    assert_redirected_to "/users/login"

    get "/org"
    assert_redirected_to "/users/login"
  end

  test "authenticated root redirects to the entity-scoped portal root" do
    login_as(@user, portal: :user)

    get "/"
    assert_redirected_to "/org/#{@org.to_param}"
  end

  test "authenticated bare /org redirects to the entity-scoped portal root" do
    login_as(@user, portal: :user)

    get "/org"
    assert_redirected_to "/org/#{@org.to_param}"
  end
end
