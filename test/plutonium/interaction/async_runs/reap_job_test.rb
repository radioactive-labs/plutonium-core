# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::AsyncRuns::ReapJobTest < ActiveSupport::TestCase
  include DataHelpers
  include ActiveJob::TestHelper

  ReapJob = Plutonium::Interaction::AsyncRuns::ReapJob
  Job = Plutonium::Interaction::AsyncRuns::Job

  setup do
    Plutonium::Interaction::AsyncRun.delete_all
    @user = create_user!
    @org = create_organization!
  end

  teardown { Plutonium::Interaction::AsyncRun.delete_all }

  def create_run!(**attrs)
    TestPostRun.create!(initiator: @user, scoped_entity: @org, **attrs)
  end

  test "a running run with no activity past the threshold is reset to pending and re-enqueued" do
    run = create_run!(state: "running", started_at: 2.hours.ago, last_activity_at: 2.hours.ago)

    assert_enqueued_with(job: Job, args: [run.id]) do
      ReapJob.perform_now(stall_after: 1.hour)
    end

    assert_equal "pending", run.reload.state
  end

  test "a run with recent activity is left alone" do
    run = create_run!(state: "running", started_at: 10.minutes.ago, last_activity_at: 10.minutes.ago)

    assert_no_enqueued_jobs(only: Job) { ReapJob.perform_now(stall_after: 1.hour) }

    assert_equal "running", run.reload.state
  end

  test "a pending run that never started is reaped the same way" do
    run = create_run!(state: "pending", last_activity_at: 2.hours.ago)

    assert_enqueued_with(job: Job, args: [run.id]) do
      ReapJob.perform_now(stall_after: 1.hour)
    end

    assert_equal "pending", run.reload.state
  end

  test "completed and failed runs are never touched, regardless of age" do
    completed = create_run!(state: "completed", finished_at: 3.hours.ago, last_activity_at: 3.hours.ago)
    failed = create_run!(state: "failed", finished_at: 3.hours.ago, last_activity_at: 3.hours.ago)

    assert_no_enqueued_jobs(only: Job) { ReapJob.perform_now(stall_after: 1.hour) }

    assert_equal "completed", completed.reload.state
    assert_equal "failed", failed.reload.state
  end

  test "reaping bumps lock_version so the still-live worker cannot keep writing" do
    run = create_run!(state: "running", started_at: 2.hours.ago, last_activity_at: 2.hours.ago)
    # The worker that is still alive holds the row as it was before the reap.
    live_worker_copy = Plutonium::Interaction::AsyncRun.find(run.id)

    ReapJob.perform_now(stall_after: 1.hour)

    assert_operator run.reload.lock_version, :>, live_worker_copy.lock_version,
      "without a bump the superseded worker keeps writing and one side's progress is lost"
    assert_raises(ActiveRecord::StaleObjectError) do
      live_worker_copy.update!(progress_done: 99)
    end
  end

  test "a reaped run leaves the stalled scope instead of being reaped again" do
    run = create_run!(state: "running", started_at: 3.hours.ago, last_activity_at: 3.hours.ago)

    ReapJob.perform_now(stall_after: 1.hour)
    version_after_first = run.reload.lock_version

    refute Plutonium::Interaction::AsyncRun.stalled(before: 1.hour.ago).exists?(id: run.id),
      "a run the sweep just resumed is not still stalled"

    ReapJob.perform_now(stall_after: 1.hour)

    assert_equal version_after_first, run.reload.lock_version,
      "the next sweep must not reap it again — on a backed-up queue that is an " \
      "unbounded pile of duplicate deliveries for one run"
  end

  test "a run whose activity advanced just before the reap is left alone" do
    run = create_run!(state: "running", last_activity_at: 3.hours.ago)
    threshold = 1.hour.ago
    # Simulate a progress write landing after ReapJob's initial query but
    # before it reaps this specific row — the atomic conditional UPDATE must
    # still see it as no-longer-stalled.
    run.update!(last_activity_at: Time.current)

    ReapJob.new.send(:reap, run, threshold)

    assert_equal "running", run.reload.state
  end
end
