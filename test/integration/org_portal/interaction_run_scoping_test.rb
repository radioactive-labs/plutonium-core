# frozen_string_literal: true

require "test_helper"
require "plutonium/testing"

# Runs in a `:path` entity-scoped portal.
#
# The policy test proves the relation scope filters on the tenant the run
# recorded; this proves it over HTTP, against the live route — and that the URL
# a dispatching interaction redirects to carries the tenant. Task 5's redirect
# test had to stand in with a Blogging::Post because Run was not routable yet.
class OrgPortal::InteractionRunScopingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::AuthHelpers

  setup do
    Plutonium::Interaction::Run.delete_all

    @org = create_organization!
    @other = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    login_as(@user, portal: :user)

    @mine = TestPostRun.create!(initiator: @user, scoped_entity: @org, state: "running")
    @theirs = TestPostRun.create!(initiator: @user, scoped_entity: @other, state: "running")
  end

  teardown { Plutonium::Interaction::Run.delete_all }

  def prefix = "/org/#{@org.to_param}"

  test "the run's URL is entity-prefixed, and that is where dispatch redirects" do
    get "#{prefix}/interaction_runs"
    assert_response :success

    # Exactly the call Dispatchable#dispatch_redirect_target makes. `url_for`
    # on the bare record cannot produce this: the helper is entity-prefixed and
    # takes the tenant as its first argument.
    resolved = @controller.helpers.resource_url_for(@mine)

    assert_equal "#{prefix}/interaction_runs/#{@mine.to_param}", resolved
    get resolved
    assert_response :success
  end

  test "a run dispatched in another tenant is not readable" do
    get "#{prefix}/interaction_runs/#{@theirs.to_param}"
    assert_response :not_found
  end

  test "the index lists only this tenant's runs" do
    get "#{prefix}/interaction_runs"
    assert_response :success

    assert_match(/#{prefix}\/interaction_runs\/#{@mine.to_param}/, response.body)
    refute_match(/#{prefix}\/interaction_runs\/#{@theirs.to_param}/, response.body,
      "another tenant's run must never be listed")
  end
end
