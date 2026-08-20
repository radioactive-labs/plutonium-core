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

  test "the show page leaves the progress counters to the panel" do
    run = create_run!(state: "running", progress_total: 4, progress_done: 1)

    get run_path(run)
    assert_response :success

    # The panel already says "1 of 4 targets (25%)" over a bar. Rendering the
    # same two numbers again as fields is one report twice — and only the panel
    # is inside the polled frame, so the two drift apart the moment it advances.
    assert_match(/1 of 4 targets/, response.body, "the panel still reports progress")
    refute_match(/Progress done/i, response.body)
    refute_match(/Progress total/i, response.body)
  end

  test "the index still shows the counters, having no bar to show instead" do
    create_run!(state: "running", progress_total: 4, progress_done: 1)

    get "/admin/async_runs"
    assert_response :success

    assert_match(/Progress done/i, response.body)
  end

  test "the poll that finds the run finished tells the page to reload" do
    run = create_run!(state: "running", progress_total: 4, progress_done: 4)
    frame_id = "pu_run_progress_#{run.id}"
    run.finish!

    get run_path(run), headers: {"Turbo-Frame" => frame_id}
    assert_response :success

    # Only this panel is in the polled frame; the fields beside it were rendered
    # when the run was dispatched. Without this the page is left showing a green
    # "Completed, 4 of 4" above a list still reading "Running" and "0 done".
    assert_match(/data-run-progress-finished-value="true"/, response.body)
    refute_match(/data-run-progress-url-value/, response.body,
      "there is nothing left to poll for")
  end

  test "a full page render of a finished run carries no reload flag" do
    run = create_run!(state: "running", progress_total: 4, progress_done: 4)
    run.finish!

    get run_path(run)
    assert_response :success

    # The flag is what the reload acts on, so emitting it on the page the reload
    # lands on is an infinite refresh.
    refute_match(/data-run-progress-finished-value/, response.body)
    refute_match(/data-controller="run-progress"/, response.body)
  end

  test "an in-progress run with no total gets a moving bar, not just text" do
    run = create_run!(state: "running", progress_total: nil)

    get run_path(run)
    assert_response :success

    # "Working…" as bare text read as a stalled page: nothing on it moved, so
    # nothing said the run was alive.
    assert_match(/pu-run-progress-indeterminate/, response.body)
    assert_match(/Working/, response.body)
  end

  test "a settled run with no total gets no bar, having no motion to convey" do
    run = create_run!(state: "running", progress_total: nil)
    run.finish!

    get run_path(run)
    assert_response :success

    refute_match(/pu-run-progress-indeterminate/, response.body)
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

  # === the index refreshes itself while work is outstanding ===

  test "the index arms a poll while a run is working" do
    create_run!(state: "running")

    get "/admin/async_runs"
    assert_response :success

    assert_match(/<turbo-frame[^>]*\bid="pu_async_runs_index"/, response.body,
      "the collection must sit in a frame the poll can re-fetch")
    assert_match(/data-controller="run-progress"/, response.body)
  end

  test "the index carries no poll once nothing is working" do
    run = create_run!(state: "running")
    run.finish!

    get "/admin/async_runs"
    assert_response :success

    # The frame stays; only the timer goes. The controller lives INSIDE the
    # frame precisely so a swap can drop it — an attribute on the frame element
    # itself survives every navigation and would poll forever.
    assert_match(/<turbo-frame[^>]*\bid="pu_async_runs_index"/, response.body)
    refute_match(/data-controller="run-progress"/, response.body,
      "a settled index is static; a poll that never stops is a request per viewer, forever")
  end

  test "a poll of the index frame answers with the collection alone" do
    create_run!(state: "running")

    get "/admin/async_runs", headers: {"Turbo-Frame" => "pu_async_runs_index"}
    assert_response :success

    assert_equal 1, response.body.scan("<turbo-frame").size,
      "exactly one frame: the wrapper DynaFrameContent emits for the inbound header"
    assert_match(/data-controller="run-progress"/, response.body,
      "the refreshed markup must re-arm, or the second poll never happens")
    refute_match(/pu-page-header|breadcrumb/i, response.body,
      "the page chrome must not come back inside the frame")
  end

  test "the poll re-fetches the URL the operator is actually looking at" do
    create_run!(state: "running")

    get "/admin/async_runs?page=1"
    assert_response :success

    # Polling the bare index would answer page 1 unfiltered and swap THAT into
    # a frame the operator had scoped to something else.
    assert_match(/data-run-progress-url-value="[^"]*\/admin\/async_runs\?page=1"/, response.body)
  end
end
