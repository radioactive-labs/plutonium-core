# frozen_string_literal: true

require "test_helper"

# In-progress runs surface at the top of the index of the resource they are
# working on.
#
# The point is that a user who dispatched a bulk action and navigated away can
# find it again without knowing the run's URL. So every assertion here is about
# what the INDEX shows, not what the run's own page shows — that is Task 6.
class AdminPortal::AsyncRunBannerTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    # No transactional rollback in this suite, and runs are not in
    # IntegrationTestHelper#cleanup_test_data.
    Plutonium::Interaction::Async::Run.delete_all

    @admin = create_admin!
    login_as_admin(@admin)
    @org = create_organization!
    @user = create_user!
  end

  teardown { Plutonium::Interaction::Async::Run.delete_all }

  POSTS_INDEX = "/admin/blogging/posts"

  def create_run!(**attributes)
    TestPostRun.create!(
      initiator: @user,
      scoped_entity: @org,
      target_type: "Blogging::Post",
      **attributes
    )
  end

  test "an in-progress run for this resource is listed above the collection" do
    run = create_run!(state: "running", progress_total: 4, progress_done: 1)

    get POSTS_INDEX
    assert_response :success

    assert_match(/pu-running-banner/, response.body,
      "a user who navigated away from a dispatch needs to find it from the index")
    assert_match(/data-run-id="#{run.id}"/, response.body)
  end

  test "a pending run counts as in progress" do
    # A run sits pending between dispatch and the job being picked up. That gap
    # is exactly when a user is most likely to come looking for it.
    run = create_run!(state: "pending", progress_total: 2)

    get POSTS_INDEX
    assert_match(/data-run-id="#{run.id}"/, response.body)
  end

  test "settled runs are not listed" do
    completed = create_run!(state: "completed", progress_total: 1, progress_done: 1)
    failed = create_run!(state: "failed")

    get POSTS_INDEX
    refute_match(/data-run-id="#{completed.id}"/, response.body,
      "a finished run belongs in the run index, not on top of this one")
    refute_match(/data-run-id="#{failed.id}"/, response.body)
  end

  test "a run targeting a different resource is not listed" do
    other = create_run!(state: "running", target_type: "Catalog::Product")

    get POSTS_INDEX
    refute_match(/data-run-id="#{other.id}"/, response.body,
      "this is the posts index; a product run is somebody else's business")
  end

  test "an opaque run is not listed on any resource index" do
    # No target_type at all — it belongs to no resource, so it has no index to
    # sit on top of.
    opaque = create_run!(state: "running", target_type: nil)

    get POSTS_INDEX
    refute_match(/data-run-id="#{opaque.id}"/, response.body)
  end

  test "no banner renders when nothing is running" do
    create_run!(state: "completed", progress_total: 1, progress_done: 1)

    get POSTS_INDEX
    assert_response :success
    refute_match(/pu-running-banner/, response.body,
      "an always-present empty banner is chrome that teaches the user to ignore the area")
  end
end
