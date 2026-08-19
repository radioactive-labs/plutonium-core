# frozen_string_literal: true

require "test_helper"

# The banner reads a DIFFERENT resource than the index it sits on, so it is its
# own authorization surface. If it queried Run directly instead of going through
# authorized_resource_scope, it would be a way to see runs from other tenants
# from inside your own portal — and the leak would look like a UI detail.
class OrgPortal::AsyncRunBannerScopingTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    Plutonium::Interaction::AsyncRun.delete_all

    @org = create_organization!
    @other_org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)

    login_as_user(@user)
  end

  teardown { Plutonium::Interaction::AsyncRun.delete_all }

  def posts_index = "/org/#{@org.to_param}/blogging/posts"

  def create_run!(entity)
    TestPostRun.create!(
      initiator: @user,
      scoped_entity: entity,
      target_type: "Blogging::Post",
      state: "running",
      progress_total: 3
    )
  end

  test "a run from another tenant is not listed on this tenant's index" do
    mine = create_run!(@org)
    theirs = create_run!(@other_org)

    get posts_index
    assert_response :success

    assert_match(/data-run-id="#{mine.id}"/, response.body)
    refute_match(/data-run-id="#{theirs.id}"/, response.body,
      "the banner reads another resource, so it is its own authorization surface")
  end

  test "a run dispatched outside any tenant is not listed inside one" do
    # nil scoped_entity means "dispatched outside any tenant", which is not the
    # same as "belongs to every tenant".
    unscoped = create_run!(nil)

    get posts_index
    refute_match(/data-run-id="#{unscoped.id}"/, response.body)
  end
end
