# frozen_string_literal: true

require "test_helper"

class TestArchiveRun < Plutonium::Interaction::Run
  def perform_on(record) = record
end

class TestOpaqueRun < Plutonium::Interaction::Run
  def perform = :done
end

class TestPrivateWorkRun < Plutonium::Interaction::Run
  private

  def perform_on(record) = record
end

class TestContinuingRun < Plutonium::Interaction::Run
  on_failure :continue
end

# Grandchild: the failure policy must survive a second level of STI.
class TestDeepContinuingRun < TestContinuingRun
end

class Plutonium::Interaction::RunTest < ActiveSupport::TestCase
  include DataHelpers

  # This suite has no transactional rollback (test_helper doesn't load
  # rails/test_help), so rows persist across tests — the scope assertions below
  # count rows globally and would see everything an earlier test left behind.
  setup { Plutonium::Interaction::Run.delete_all }

  def build(klass = TestArchiveRun, **attrs)
    klass.new(initiator: (@initiator ||= create_user!), **attrs)
  end

  test "lifecycle stamps state and timestamps" do
    run = build
    run.start!
    assert_equal "running", run.state
    refute_nil run.started_at

    run.finish!
    assert_equal "completed", run.state
    refute_nil run.finished_at
  end

  test "progress is indeterminate for opaque work" do
    assert_nil build(TestOpaqueRun).progress_fraction
  end

  test "progress is a fraction for targeted work" do
    run = build(progress_total: 4, progress_done: 1)
    assert_in_delta 0.25, run.progress_fraction, 0.001
  end

  test "target failures accumulate" do
    run = build
    run.record_target_failure!(id: 1, message: "boom")
    run.record_target_failure!(id: 2, message: "bang")
    assert_equal 2, run.errors_log.size
    assert_equal "boom", run.errors_log.first["message"]
  end

  test "target failures persist without a later save" do
    run = build
    run.record_target_failure!(id: 1, message: "boom")
    run.record_target_failure!(id: 2, message: "bang")

    # Re-read through a fresh instance: nothing may depend on a caller
    # remembering to flush.
    reloaded = Plutonium::Interaction::Run.find(run.id)
    assert_equal ["boom", "bang"], reloaded.errors_log.map { |e| e["message"] }
    assert_equal [1, 2], reloaded.errors_log.map { |e| e["target_id"] }
  end

  test "targeted? reflects what the subclass implements" do
    assert build(TestArchiveRun).targeted?
    refute build(TestOpaqueRun).targeted?
  end

  test "heartbeat! refreshes the stall clock without bumping lock_version" do
    run = build(TestOpaqueRun, state: "running", last_activity_at: 3.hours.ago)
    run.save!
    # The executor's own in-memory copy, exactly as it holds it mid-perform.
    version = run.lock_version

    beat = run.heartbeat!

    assert_in_delta beat, run.reload.last_activity_at, 1
    assert_equal version, run.lock_version,
      "touch and update! both bump the lock column; that would invalidate the " \
      "executor's own record and make its next save! raise against a row nobody took"
    assert_empty Plutonium::Interaction::Run.stalled(before: 1.hour.ago).to_a,
      "the whole point: a beating run is no longer stalled"
  end

  test "heartbeat! tells a superseded worker that the run is no longer its own" do
    run = build(TestOpaqueRun, state: "running")
    run.save!
    # A reaper judged this run stalled and a second executor claimed it, while
    # this worker was still inside a long perform. For opaque work this beat is
    # the ONLY place it can find out before finish!.
    Plutonium::Interaction::Run.where(id: run.id).update_all("lock_version = lock_version + 1")

    error = assert_raises(ActiveRecord::StaleObjectError) { run.heartbeat! }

    assert_equal run.id, error.record.id,
      "Runs::Executor#superseded? reads the errored record to tell this apart " \
      "from an author's own lost update"
  end

  test "targeted? counts a non-public perform_on" do
    # `private def perform_on` is a natural idiom for work only the executor is
    # meant to invoke. Ruby's public-only respond_to? default would read it as
    # opaque work and route it to #perform, failing every dispatch of a run whose
    # perform_on is right there.
    assert build(TestPrivateWorkRun).targeted?
  end

  test "target_label humanizes the target class, falls back on a stale one, and is nil for opaque work" do
    assert_equal "Post", build(TestArchiveRun, target_type: "Blogging::Post").target_label
    assert_nil build(TestOpaqueRun).target_label

    stale = build(TestArchiveRun, target_type: "NoLongerAClass")
    assert_equal "NoLongerAClass", stale.target_label
  end

  test "options round-trip through JSON" do
    run = build(options: {"title" => "hi", "count" => 2, "flags" => ["a"]})
    run.save!

    reloaded = Plutonium::Interaction::Run.find(run.id)
    assert_equal({"title" => "hi", "count" => 2, "flags" => ["a"]}, reloaded.options)
    assert_equal [], reloaded.errors_log
    assert_instance_of TestArchiveRun, reloaded
  end

  test "errors_log survives a round-trip" do
    run = build
    run.record_target_failure!(id: 7, message: "boom")
    run.save!

    assert_equal [{"target_id" => 7, "message" => "boom"}], run.reload.errors_log
  end

  test "failure policy defaults to halt and is inherited through STI" do
    assert_equal :halt, TestArchiveRun.failure_policy
    assert_equal :continue, TestContinuingRun.failure_policy
    assert_equal :continue, TestDeepContinuingRun.failure_policy
    assert_equal :continue, build(TestDeepContinuingRun).failure_policy
    # A subclass declaring a policy must not leak it back onto the base.
    assert_equal :halt, Plutonium::Interaction::Run.failure_policy
  end

  test "fail! records the message and stamps finished_at" do
    run = build
    run.fail!("kaboom")

    assert_equal "failed", run.state
    refute_nil run.finished_at
    assert_equal "kaboom", run.reload.errors_log.first["message"]
    refute run.in_progress?
  end

  test "fail! keeps target failures already recorded and marks its own as run-level" do
    run = build
    run.record_target_failure!(id: 3, message: "one target died")
    run.fail!("and then the whole run did")

    log = run.reload.errors_log
    assert_equal 2, log.size
    assert_equal 3, log.first["target_id"]
    # nil target_id is the run-level sentinel.
    assert_nil log.last["target_id"]
    assert_equal "and then the whole run did", log.last["message"]
  end

  test "fail! without a message logs nothing" do
    run = build
    run.fail!

    assert_equal "failed", run.state
    assert_equal [], run.reload.errors_log
  end

  test "in_progress scope selects pending and running only" do
    pending = build(state: "pending")
    running = build(state: "running")
    completed = build(state: "completed")
    failed = build(state: "failed")
    [pending, running, completed, failed].each(&:save!)

    selected = Plutonium::Interaction::Run.in_progress.pluck(:id)
    assert_equal [pending.id, running.id].sort, selected.sort
    refute_includes selected, completed.id
    refute_includes selected, failed.id
  end

  test "for_target scope filters by target_type and accepts a class or a string" do
    posts = build(target_type: "Blogging::Post")
    tags = build(target_type: "Blogging::Tag")
    untargeted = build
    [posts, tags, untargeted].each(&:save!)

    assert_equal [posts.id], Plutonium::Interaction::Run.for_target(Blogging::Post).pluck(:id)
    assert_equal [posts.id], Plutonium::Interaction::Run.for_target("Blogging::Post").pluck(:id)
    assert_equal [tags.id], Plutonium::Interaction::Run.for_target(Blogging::Tag).pluck(:id)
  end

  test "for_target composes with in_progress, as the index banner uses it" do
    wanted = build(target_type: "Blogging::Post", state: "running")
    done = build(target_type: "Blogging::Post", state: "completed")
    other = build(target_type: "Blogging::Tag", state: "running")
    [wanted, done, other].each(&:save!)

    scoped = Plutonium::Interaction::Run.for_target(Blogging::Post).in_progress
    assert_equal [wanted.id], scoped.pluck(:id)
  end

  test "stalled scope selects in-progress rows with no activity since the threshold" do
    stale = build(state: "running", last_activity_at: 2.hours.ago)
    fresh = build(state: "running", last_activity_at: 10.minutes.ago)
    stale_but_done = build(state: "completed", last_activity_at: 2.hours.ago)
    [stale, fresh, stale_but_done].each(&:save!)

    selected = Plutonium::Interaction::Run.stalled(before: 1.hour.ago).pluck(:id)

    assert_equal [stale.id], selected
  end

  test "state must be one of STATES" do
    run = build(state: "nonsense")
    assert run.invalid?
    assert_includes run.errors[:state], "is not included in the list"

    Plutonium::Interaction::Run::STATES.each do |state|
      assert build(state: state).valid?, "expected #{state} to be a valid state"
    end
  end

  test "on_failure rejects an unknown policy at class-definition time" do
    error = assert_raises(ArgumentError) do
      Class.new(Plutonium::Interaction::Run) { on_failure :continu }
    end
    assert_match(/unknown failure policy/, error.message)

    # All three policies the executor implements must be accepted.
    Plutonium::Interaction::Run::FAILURE_POLICIES.each do |policy|
      klass = Class.new(Plutonium::Interaction::Run) { on_failure policy }
      assert_equal policy, klass.failure_policy
    end
  end
end
