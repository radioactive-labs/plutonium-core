# frozen_string_literal: true

require "test_helper"

# How a LIVE controller answers an async dispatch, which is the one place the
# answer comes from Response::Redirect rather than the controller's own success
# branch.
class AdminPortal::AsyncDispatchResponseTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  TURBO_STREAM = {"Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml"}.freeze

  setup do
    Plutonium::Interaction::Async::Run.delete_all
    @admin = create_admin!
    login_as_admin(@admin)
    @task = Task.create!(title: "Ship it", status: "done")
  end

  teardown do
    Task.delete_all
    Plutonium::Interaction::Async::Run.delete_all
  end

  # The form opened as a full page (or in any frame but the modal) sends no
  # remote_modal Turbo-Frame header. A plain redirect there was followed by
  # fetch and its page rendered into whatever frame submitted the form.
  test "a turbo-stream dispatch outside the modal is answered with a stream redirect" do
    post "/admin/tasks/bulk_actions/archive_all_async",
      params: {ids: [@task.id], interaction: {reason: "Quarterly cleanup"}},
      headers: TURBO_STREAM

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    run = ArchiveTasksAsyncInteraction::Run.sole
    assert_match(/<turbo-stream[^>]*action="redirect"/, response.body)
    assert_match(%r{url="/admin/async_runs/#{run.to_param}"}, response.body)
  end
end
