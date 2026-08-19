# frozen_string_literal: true

require "test_helper"

# The run's show page IS its progress page.
#
# Everything here is asserted against a live route, because that is the part
# that could not be asserted before: Task 5's redirect test had to stand in with
# a Blogging::Post since Run was not yet routable.
class AdminPortal::AsyncRunProgressTest < ActionDispatch::IntegrationTest
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

  def run_path(run) = "/admin/async_runs/#{run.to_param}"

  def create_run!(**attributes)
    TestPostRun.create!(initiator: @user, scoped_entity: @org, **attributes)
  end

  test "the run is routable and resource_url_for resolves its show URL" do
    run = create_run!(state: "running")

    get "/admin/async_runs"
    assert_response :success

    # Exactly the call Dispatchable#dispatch_redirect_target makes.
    resolved = @controller.helpers.resource_url_for(run)

    assert_equal run_path(run), resolved,
      "async redirects through resource_url_for; this is the URL it produces"

    get resolved
    assert_response :success
  end

  test "an in-progress run polls; a finished one does not" do
    run = create_run!(state: "running", progress_total: 4, progress_done: 1)

    get run_path(run)
    assert_response :success
    assert_match(/data-controller="run-progress"/, response.body,
      "an in-progress run must refresh itself")
    assert_match(/<turbo-frame[^>]*\bid="pu_run_progress_#{run.id}"/, response.body,
      "the panel must sit in a frame the poll can re-fetch")

    run.finish!

    get run_path(run)
    assert_response :success
    refute_match(/data-controller="run-progress"/, response.body,
      "a finished run is static; polling forever is a background request per viewer")
  end

  # The poll re-fetches the show URL with the frame's own name in the
  # Turbo-Frame header. DynaFrameContent wraps every response in a frame of that
  # name, so the response must be the panel alone — otherwise the whole page is
  # swapped inside the progress frame, and the next poll nests it again.
  test "a poll of the progress frame answers with the panel alone" do
    run = create_run!(state: "running", progress_total: 4, progress_done: 1)
    frame_id = "pu_run_progress_#{run.id}"

    get run_path(run), headers: {"Turbo-Frame" => frame_id}
    assert_response :success

    assert_equal 1, response.body.scan("<turbo-frame").size,
      "exactly one frame: the wrapper DynaFrameContent emits for the inbound header"
    assert_match(/data-controller="run-progress"/, response.body)
    refute_match(/pu-page-header|breadcrumb/i, response.body,
      "the page chrome must not come back inside the progress frame")
  end

  test "progress renders as indeterminate, not 0%, when no total was recorded" do
    run = create_run!(state: "running", progress_total: nil)

    get run_path(run)
    assert_response :success

    assert_match(/Working…/, response.body)
    refute_match(/0 of /, response.body,
      "opaque work has no denominator; a 0% bar claims nothing has happened")
  end

  # progress_done counts targets DISPOSITIONED, not applied: a refused
  # :halt/:transactional batch finishes with progress_done > 0 having performed
  # nothing (Async::Executor#refuse_partial_batch). Rendered alone it reads as
  # work done, so it is only ever rendered next to the state.
  test "progress is rendered paired with the run's state" do
    run = create_run!(state: "failed", progress_total: 3, progress_done: 3)
    run.record_target_failure!(id: nil, message: "3 of 3 targets could not be resolved")

    get run_path(run)
    assert_response :success

    assert_match(/Failed/, response.body)
    assert_match(/3 of 3 targets/, response.body)
  end

  # A :continue run that could not apply some of its targets ends as
  # `completed` by design (Async::Executor#perform_targets). If the page shows
  # that as a clean success, a run that under-applied becomes indistinguishable
  # from one that did everything.
  test "a completed run with recorded failures does not render as a clean success" do
    run = create_run!(state: "completed", progress_total: 3, progress_done: 3)
    run.record_target_failures!([
      {id: 41, message: "Target 41 is no longer available"},
      {id: 42, message: "Target 42 is no longer permitted by archive?"}
    ])

    get run_path(run)
    assert_response :success

    assert_match(/Completed with errors/, response.body,
      "a partially applied run must not read as Completed")
    refute_match(/pu-badge-success/, response.body,
      "the success badge is what makes an under-applied run look clean")
    assert_match(/2 errors/, response.body)
    assert_match(/Target 41 is no longer available/, response.body,
      "the recorded failures are the report of what did not happen")
    assert_match(/Target 42 is no longer permitted by archive\?/, response.body)
  end

  # The same requirement on the other surface: the index is where an operator
  # scans a list of runs looking for the one that under-applied.
  test "the index does not list a completed-with-errors run as a success" do
    run = create_run!(state: "completed", progress_total: 3, progress_done: 3)
    run.record_target_failure!(id: 41, message: "Target 41 is no longer available")

    get "/admin/async_runs"
    assert_response :success

    assert_match(/Completed with errors/, response.body)
    refute_match(/pu-badge-success/, response.body)
  end

  test "a clean completed run does render as a success" do
    run = create_run!(state: "completed", progress_total: 3, progress_done: 3)

    get run_path(run)
    assert_response :success

    assert_match(/pu-badge-success/, response.body)
    refute_match(/Completed with errors/, response.body)
  end

  # The interaction's own policy governed who could SUBMIT these values; the set
  # of people who can read the run is wider.
  test "the dispatching interaction's options are not rendered" do
    run = create_run!(state: "completed", options: {"reason" => "SECRET-REASON-SENTINEL"})

    get run_path(run)
    assert_response :success
    refute_match(/SECRET-REASON-SENTINEL/, response.body)
  end

  test "the target type renders as its humanized name, not the raw class string" do
    run = create_run!(state: "completed", target_type: "Blogging::Post")

    get run_path(run)
    assert_response :success
    assert_match(/Post/, response.body)
    refute_match(/Blogging::Post/, response.body)
  end

  test "a run offers no write actions" do
    run = create_run!(state: "completed")

    get run_path(run)
    assert_response :success
    refute_match(%r{#{run_path(run)}/edit}, response.body)

    get "#{run_path(run)}/edit"
    assert_response :forbidden
  end
end
