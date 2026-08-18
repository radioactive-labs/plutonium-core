# frozen_string_literal: true

require "test_helper"

class Plutonium::Interaction::Runs::ReapJobTest < ActiveSupport::TestCase
  include DataHelpers
  include ActiveJob::TestHelper

  ReapJob = Plutonium::Interaction::Runs::ReapJob
  Job = Plutonium::Interaction::Runs::Job

  setup do
    Plutonium::Interaction::Run.delete_all
    @user = create_user!
    @org = create_organization!
  end

  teardown { Plutonium::Interaction::Run.delete_all }

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
