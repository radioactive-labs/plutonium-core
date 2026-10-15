# frozen_string_literal: true

require "test_helper"

# A CSV import through the real dispatch path: the file is staged at dispatch,
# revived in the job, checked whole before a single task is created.
class AdminPortal::AsyncImportPreCheckTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  Executor = Plutonium::Interaction::Async::Executor

  setup do
    Plutonium::Interaction::Async::Run.delete_all
    Task.delete_all
    @admin = create_admin!
    login_as_admin(@admin)
  end

  teardown do
    Task.delete_all
    Plutonium::Interaction::Async::Run.delete_all
  end

  def import(csv)
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "tasks.csv")
    post "/admin/tasks/resource_actions/import_tasks", params: {interaction: {import_file: file}}
    assert_response :redirect

    # The test queue adapter never performs; drive the job's work directly.
    run = ImportTasksInteraction::Run.sole
    Executor.new(run).call
    run.reload
  end

  test "a file with bad rows is rejected whole, every problem listed, nothing imported" do
    run = import("title,status\nShip it,todo\n,doing\nWrite docs,someday\n")

    assert_equal "rejected", run.outcome
    assert_equal ["line 3: title is missing", "line 4: unknown status \"someday\""],
      run.errors_log.map { |entry| entry["message"] }
    assert_equal 0, Task.count, "a rejected import must not create anything"

    get "/admin/async_runs/#{run.to_param}"
    assert_match(/Rejected/, response.body)
    assert_match(/Nothing was processed/, response.body)
    assert_match(/line 3: title is missing/, response.body)
  end

  test "a valid file is imported" do
    run = import("title,status\nShip it,todo\nWrite docs,\n")

    assert_equal "completed", run.state
    assert_equal [["Ship it", "todo"], ["Write docs", "todo"]], Task.order(:id).pluck(:title, :status)
  end

  test "a non-ASCII title and an Excel byte-order mark import cleanly" do
    run = import("\uFEFFtitle,status\nCaf\u00e9,todo\n")

    assert_equal "completed", run.state
    assert_equal ["Caf\u00e9"], Task.pluck(:title)
  end

  test "a trailing blank line is not a rejection" do
    run = import("title,status\nShip it,todo\n\n")

    assert_equal "completed", run.state
    assert_equal ["Ship it"], Task.pluck(:title)
  end

  test "malformed CSV is rejected, not failed" do
    run = import("title,status\n\"unclosed,todo\n")

    assert_equal "rejected", run.outcome
    assert_match(/not valid CSV/, run.errors_log.sole["message"])
    assert_equal 0, Task.count
  end

  test "a file without a title column is rejected with one message" do
    run = import("name,status\nShip it,todo\nWrite docs,todo\n")

    assert_equal "rejected", run.outcome
    assert_equal ["missing column: title"], run.errors_log.map { |entry| entry["message"] }
  end

  test "a file with only a header is rejected" do
    run = import("title,status\n")

    assert_equal "rejected", run.outcome
    assert_equal ["the file has no rows to import"], run.errors_log.map { |entry| entry["message"] }
  end
end
