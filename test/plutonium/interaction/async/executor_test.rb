# frozen_string_literal: true

require "test_helper"

# These run subclasses live here rather than in test/dummy/app/runs because
# their BEHAVIOUR is the fixture: each exists to push the executor down one
# branch, and a script hook lets a single test say exactly what perform_on does.
# The dummy app's runs (TestPostRun and friends) are deliberately inert, which is
# what the context tests needed and what these tests cannot use.
class ScriptedRun < Plutonium::Interaction::Async::Run
  # Shared with the subclasses below — a class variable, which is what we want:
  # only one of them is exercised per test, and assertions can always read
  # ScriptedRun.
  cattr_accessor :script
  cattr_accessor :performed

  def perform_on(record)
    self.class.performed << record.id
    # A real database write, so the transactional test can assert it was undone.
    record.update!(title: "#{record.title} [done]")
    self.class.script&.call(record)
  end
end

class ContinuingScriptedRun < ScriptedRun
  on_failure :continue
end

class TransactionalScriptedRun < ScriptedRun
  on_failure :transactional
end

class OpaqueScriptedRun < Plutonium::Interaction::Async::Run
  cattr_accessor :calls

  def perform = self.class.calls += 1
end

# perform_on declared PRIVATE — a natural idiom for work only the executor is
# meant to invoke. It must be detected and performed exactly like a public one.
class PrivateWorkRun < Plutonium::Interaction::Async::Run
  cattr_accessor :performed

  private

  def perform_on(record) = self.class.performed << record.id
end

# Long opaque work that beats while it runs — the shape Run#heartbeat! exists
# for, since the executor writes nothing between the claim and finish!.
class BeatingOpaqueRun < Plutonium::Interaction::Async::Run
  cattr_accessor :beats
  cattr_accessor :before_beat

  def perform
    2.times do
      self.class.before_beat&.call(self)
      self.class.beats << heartbeat!
    end
  end
end

# Implements NEITHER perform nor perform_on: an author error that must surface
# as a diagnosis, not a NoMethodError from inside the loop.
class UndefinedWorkRun < Plutonium::Interaction::Async::Run
end

# A check whose behaviour each test scripts. `checked` records what the check
# was handed, so a test can assert which records a targeted check saw.
class CheckedRun < ScriptedRun
  on_failure :continue
  cattr_accessor :check
  cattr_accessor :checked

  def pre_check(records)
    self.class.checked = records.map(&:id)
    self.class.check&.call(self, records)
  end
end

# Records whether the batch transaction opened. Executor#perform_all_or_nothing
# is the only caller of Run.transaction; update! goes through the connection.
class TransactionalCheckedRun < CheckedRun
  on_failure :transactional
  cattr_accessor :batch_opened

  def self.transaction(...)
    self.batch_opened = true
    super
  end
end

class CheckedOpaqueRun < Plutonium::Interaction::Async::Run
  cattr_accessor :check
  cattr_accessor :calls

  def pre_check = self.class.check&.call(self)

  def perform = self.class.calls += 1
end

# Opaque-shaped check declared on a targeted run: the arity mistake an author
# makes when copying an opaque example.
class MisdeclaredCheckRun < ScriptedRun
  def pre_check = nil
end

# Keyword-only: arity 1, but a positional call raises a bare ArgumentError.
class KeywordCheckRun < ScriptedRun
  def pre_check(records:) = nil
end

class RecordsCheckOpaqueRun < Plutonium::Interaction::Async::Run
  def pre_check(records) = nil

  def perform = nil
end

class Plutonium::Interaction::Async::ExecutorTest < ActiveSupport::TestCase
  include DataHelpers
  include ActiveSupport::Testing::TimeHelpers

  Executor = Plutonium::Interaction::Async::Executor
  Job = Plutonium::Interaction::Async::Job

  # No transactional rollback in this suite (test_helper never loads
  # rails/test_help), so rows and class-level state persist between tests.
  setup do
    Plutonium::Interaction::Async::Run.delete_all

    ScriptedRun.script = nil
    ScriptedRun.performed = []
    OpaqueScriptedRun.calls = 0
    CheckedRun.check = nil
    CheckedRun.checked = nil
    TransactionalCheckedRun.batch_opened = false
    CheckedOpaqueRun.check = nil
    CheckedOpaqueRun.calls = 0

    @user = create_user!
    @org = create_organization!
    @other_org = create_organization!
  end

  teardown { Plutonium::Interaction::Async::Run.delete_all }

  # touch? is unconditionally true in Blogging::PostPolicy, so tests that are not
  # about permission do not accidentally depend on one.
  def create_run!(klass = ScriptedRun, target_ids: [], policy_action: "touch?", **attrs)
    klass.create!(
      initiator: @user,
      scoped_entity: @org,
      target_type: "Blogging::Post",
      target_ids: target_ids,
      policy_class_name: "Blogging::PostPolicy",
      policy_action: policy_action,
      progress_total: target_ids.size,
      **attrs
    )
  end

  def execute!(run)
    Executor.new(run).call
    run.reload
  end

  def messages(run) = run.errors_log.map { |entry| entry["message"] }

  def failed_ids(run) = run.errors_log.map { |entry| entry["target_id"] }

  # Real statements only, dropping schema reflection and BEGIN/COMMIT noise.
  def capture_sql
    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql] unless %w[SCHEMA TRANSACTION].include?(payload[:name])
    end
    yield
    statements
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  # --- failure policies ----------------------------------------------------

  test "continue records the failure and processes the remaining targets" do
    good = create_post!(user: @user, organization: @org, title: "good")
    bad = create_post!(user: @user, organization: @org, title: "bad")
    later = create_post!(user: @user, organization: @org, title: "later")
    ScriptedRun.script = ->(record) { raise "boom" if record.title.include?("bad") }

    run = execute!(create_run!(ContinuingScriptedRun, target_ids: [bad.id, good.id, later.id]))

    assert_equal [bad.id, good.id, later.id], ScriptedRun.performed,
      "continue must keep going past a failed target"
    assert_equal "completed", run.state
    assert_equal ["boom"], messages(run)
    assert_equal [bad.id], failed_ids(run)
    assert_equal 3, run.progress_done, "every resolved target must advance progress"
  end

  test "halt stops at the first error and marks the run failed" do
    bad = create_post!(user: @user, organization: @org, title: "bad")
    later = create_post!(user: @user, organization: @org, title: "later")
    ScriptedRun.script = ->(record) { raise "boom" if record.title.include?("bad") }

    run = execute!(create_run!(ScriptedRun, target_ids: [bad.id, later.id]))

    assert_equal [bad.id], ScriptedRun.performed, "halt must not attempt the remaining targets"
    assert_equal "failed", run.state
    assert_includes messages(run), "boom"
    assert_includes messages(run),
      "stopped at the first target failure (halt policy); 1 target was not attempted"
    assert_equal 1, run.progress_done
    assert_equal "later", later.reload.title, "the untouched target must be untouched"
  end

  test "transactional rolls every target back when one fails" do
    first = create_post!(user: @user, organization: @org, title: "first")
    bad = create_post!(user: @user, organization: @org, title: "bad")
    ScriptedRun.script = ->(record) { raise "boom" if record.title.include?("bad") }

    run = execute!(create_run!(TransactionalScriptedRun, target_ids: [first.id, bad.id]))

    assert_equal "failed", run.state
    assert_equal "first", first.reload.title, "a target applied before the failure must be rolled back"
    assert_equal "bad", bad.reload.title
    # progress_done and any per-target errors_log entry were written INSIDE the
    # transaction and went back with it. What survives is the truth: nothing was
    # applied, and one entry saying which target killed it.
    assert_equal 0, run.progress_done
    assert_equal 1, run.errors_log.size
    assert_match(/target #{bad.id} failed/, messages(run).first)
    assert_match(/boom/, messages(run).first)
    assert_match(/no targets were applied/, messages(run).first)
  end

  test "transactional commits the whole batch when nothing fails" do
    first = create_post!(user: @user, organization: @org, title: "first")
    second = create_post!(user: @user, organization: @org, title: "second")

    run = execute!(create_run!(TransactionalScriptedRun, target_ids: [first.id, second.id]))

    assert_equal "completed", run.state
    assert_equal "first [done]", first.reload.title
    assert_equal "second [done]", second.reload.title
    assert_equal 2, run.progress_done
  end

  # --- unresolved targets --------------------------------------------------

  test "a missing target is recorded, not skipped" do
    good = create_post!(user: @user, organization: @org)

    run = execute!(create_run!(ContinuingScriptedRun, target_ids: [good.id, 999_999]))

    assert_equal [good.id], ScriptedRun.performed
    assert_equal [999_999], failed_ids(run)
    assert_match(/no longer available/i, messages(run).first)
    assert_equal "completed", run.state
    assert_equal 2, run.progress_done,
      "an unresolvable target still advances progress; the bar must reach the end"
  end

  test "missing targets cost one write regardless of how many there are" do
    one = capture_sql { execute!(create_run!(ContinuingScriptedRun, target_ids: [900_001])) }
    many = capture_sql { execute!(create_run!(ContinuingScriptedRun, target_ids: (900_001..900_010).to_a)) }

    assert_equal run_updates(one), run_updates(many),
      "recording M missing targets must not cost M writes — each one rewrites the whole errors_log"
  end

  test "a target the initiator may no longer act on is recorded, not skipped" do
    published = create_post!(user: @user, organization: @org, status: :published)
    draft = create_post!(user: @user, organization: @org, status: :draft)

    # Blogging::PostPolicy#archive? is `record.published?`.
    run = execute!(create_run!(ContinuingScriptedRun, target_ids: [published.id, draft.id],
      policy_action: "archive?"))

    assert_equal [published.id], ScriptedRun.performed
    assert_equal [draft.id], failed_ids(run)
    assert_match(/no longer permitted/i, messages(run).first)
    assert_equal "completed", run.state
  end

  test "halt and transactional refuse to perform a partial batch" do
    [ScriptedRun, TransactionalScriptedRun].each do |klass|
      ScriptedRun.performed = []
      good = create_post!(user: @user, organization: @org, title: "good")

      run = execute!(create_run!(klass, target_ids: [good.id, 999_999]))

      assert_empty ScriptedRun.performed,
        "#{klass} must not apply part of a batch it cannot apply in full"
      assert_equal "failed", run.state
      assert_equal "good", good.reload.title
      assert_match(/no longer available/i, messages(run).first)
      assert_equal "1 of 2 targets could not be resolved; a #{run.failure_policy} run does not apply a partial batch",
        messages(run).last
    end
  end

  # --- just-in-time re-authorization ---------------------------------------

  test "a target whose permission is revoked mid-run is recorded, not performed" do
    first = create_post!(user: @user, organization: @org, status: :published, title: "first")
    second = create_post!(user: @user, organization: @org, status: :published, title: "second")

    # Revoke through a SEPARATE instance while the first target is being
    # processed: the record the executor holds still says published, so only a
    # re-read immediately before the check can see this.
    ScriptedRun.script = ->(_) { Blogging::Post.find(second.id).update!(status: :draft) }

    run = execute!(create_run!(ContinuingScriptedRun, target_ids: [first.id, second.id],
      policy_action: "archive?"))

    assert_equal [first.id], ScriptedRun.performed,
      "a target that lost permission mid-run must not be performed"
    assert_equal "second", second.reload.title
    assert_equal [second.id], failed_ids(run)
    assert_match(/no longer permitted/i, messages(run).first)
    assert_equal 2, run.progress_done
  end

  test "a target that leaves the tenant mid-run is recorded, not performed" do
    first = create_post!(user: @user, organization: @org, title: "first")
    second = create_post!(user: @user, organization: @org, title: "second")

    ScriptedRun.script = ->(_) { Blogging::Post.find(second.id).update!(organization: @other_org) }

    run = execute!(create_run!(ContinuingScriptedRun, target_ids: [first.id, second.id]))

    assert_equal [first.id], ScriptedRun.performed,
      "the re-check goes through the policy SCOPE, so a record that left the " \
      "tenant is no longer resolvable"
    assert_equal [second.id], failed_ids(run)
    assert_match(/no longer available/i, messages(run).first)
  end

  test "the authorization subjects are refreshed on an interval, not per record" do
    ids = 3.times.map { create_post!(user: @user, organization: @org).id }

    fast = capture_sql { execute!(create_run!(ContinuingScriptedRun, target_ids: ids)) }

    ScriptedRun.script = ->(_) { travel Executor::SUBJECT_REFRESH_INTERVAL * 2 }
    slow = capture_sql { execute!(create_run!(ContinuingScriptedRun, target_ids: ids)) }

    assert_operator user_selects(fast), :<, ids.size,
      "the subjects must not be re-read once per target"
    assert_equal user_selects(fast) + 2, user_selects(slow),
      "a run that spends longer than the interval between targets must re-read " \
      "the subjects, or a mid-run revocation is invisible to every remaining target"
  end

  # --- shapes of work ------------------------------------------------------

  test "a run whose perform_on is private is performed, not misread as opaque work" do
    PrivateWorkRun.performed = []
    post = create_post!(user: @user, organization: @org)

    run = execute!(create_run!(PrivateWorkRun, target_ids: [post.id]))

    assert_equal [post.id], PrivateWorkRun.performed,
      "visibility must not decide whether the framework can invoke declared work"
    assert_equal "completed", run.state
  end

  # The shape dispatch writes for opaque work started from a resource's index:
  # the resource named, no ids, no policy pinned.
  test "an opaque run that names its resource is performed, not refused for a missing policy" do
    run = execute!(TestReportRun.create!(initiator: @user, scoped_entity: @org,
      target_type: "Blogging::Post"))

    assert_equal "completed", run.state, messages(run).inspect
  end

  test "an opaque run that heartbeats stays out of the reaper's reach" do
    BeatingOpaqueRun.beats = []
    BeatingOpaqueRun.before_beat = nil
    run = BeatingOpaqueRun.create!(initiator: @user, scoped_entity: @org)

    travel_to 3.hours.from_now do
      run = execute!(run)
    end

    assert_equal 2, BeatingOpaqueRun.beats.size
    assert_equal "completed", run.state
    # Mid-perform the run was three hours past its claim. Without the beats it
    # would have been reaped and — having no handled_target_ids — re-run whole.
    assert_empty Plutonium::Interaction::Async::Run.stalled(before: 2.hours.from_now).to_a
  end

  test "a superseded opaque run abandons at its heartbeat, not after the work" do
    BeatingOpaqueRun.beats = []
    run = create_run!(BeatingOpaqueRun)
    # Claimed away by a second executor once the work is already under way —
    # after #claim!, which reloads and would otherwise hand this executor the
    # new version.
    BeatingOpaqueRun.before_beat = lambda do |r|
      Plutonium::Interaction::Async::Run.where(id: r.id).update_all("lock_version = lock_version + 1")
    end

    run = execute!(run)

    assert_empty BeatingOpaqueRun.beats, "the first beat must be the one that raises"
    assert_equal "running", run.state, "a superseded worker must not settle the run"
    assert_empty run.errors_log
  end

  test "an opaque run performs once and needs no targets" do
    run = OpaqueScriptedRun.create!(initiator: @user, scoped_entity: @org)

    Executor.new(run).call

    assert_equal 1, OpaqueScriptedRun.calls
    assert_equal "completed", run.reload.state
  end

  # --- re-entrancy ----------------------------------------------------------

  test "a run already running is not reprocessed" do
    good = create_post!(user: @user, organization: @org, title: "good")
    run = create_run!(ContinuingScriptedRun, target_ids: [good.id])
    run.start!

    Executor.new(run).call

    assert_empty ScriptedRun.performed, "a running run must not be replayed from scratch"
    assert_equal "running", run.reload.state, "a stalled run is left for an operator, not silently redone"
  end

  test "two concurrent deliveries of the same pending run only one of them performs the work" do
    good = create_post!(user: @user, organization: @org, title: "good")
    run = create_run!(ContinuingScriptedRun, target_ids: [good.id])

    Executor.new(Plutonium::Interaction::Async::Run.find(run.id)).call
    Executor.new(Plutonium::Interaction::Async::Run.find(run.id)).call

    assert_equal [good.id], ScriptedRun.performed, "the second delivery must not repeat the first's work"
    assert_equal "completed", run.reload.state
  end

  test "a resumed run skips targets it already handled before an interruption" do
    good = create_post!(user: @user, organization: @org, title: "good")
    remaining = create_post!(user: @user, organization: @org, title: "remaining")
    run = create_run!(ContinuingScriptedRun, target_ids: [good.id, remaining.id])

    # Simulate a crash right after `good` was applied and recorded, but
    # before `remaining` was ever touched.
    Executor.new(run).send(:advance!, good.id)
    run.update!(state: "running")

    assert_equal [remaining.id], run.reload.unhandled_target_ids.map(&:to_i)

    # Resume: reset to pending (what an operator/reaper would do) and re-run.
    run.update!(state: "pending")
    Executor.new(run).call

    assert_equal [remaining.id], ScriptedRun.performed,
      "a resumed run must not redo a target it already handled"
    assert_equal "completed", run.reload.state
    assert_equal 2, run.progress_done
  end

  test "an executor superseded mid-run abandons the pass instead of failing the run" do
    first = create_post!(user: @user, organization: @org, title: "first")
    second = create_post!(user: @user, organization: @org, title: "second")
    run = create_run!(ContinuingScriptedRun, target_ids: [first.id, second.id])

    # A reaper judged this run stalled and a second executor claimed it while the
    # first target was in flight — which is exactly what bumping lock_version
    # looks like from in here (see Async::ReapJob#reap and Executor#claim!).
    ScriptedRun.script = lambda do |_|
      Plutonium::Interaction::Async::Run.where(id: run.id).update_all("lock_version = lock_version + 1")
    end

    execute!(run)

    assert_equal [first.id], ScriptedRun.performed,
      "the superseded executor must stop at its first write, not work the rest of the batch"
    assert_equal "running", run.state,
      "the run belongs to whoever claimed it; a superseded executor must not mark it failed"
    assert_empty run.errors_log,
      "being superseded is not a failure of the run — it must not land in the operator's log"
  end

  test "the author's own StaleObjectError is a target failure, not a supersession" do
    first = create_post!(user: @user, organization: @org, title: "first")
    second = create_post!(user: @user, organization: @org, title: "second")
    run = create_run!(ContinuingScriptedRun, target_ids: [first.id, second.id])

    # perform_on touching a record that carries its own lock_version and losing
    # the race — nothing to do with THIS run's row. Told apart by the errored
    # record, not the exception class (see Executor#superseded?): keying off the
    # class alone abandons the whole batch with an empty errors_log and leaves
    # the run wedged at "running" for ReapJob to resume, and re-apply, forever.
    ScriptedRun.script = lambda do |record|
      raise ActiveRecord::StaleObjectError.new(record, "update") if record.id == first.id
    end

    execute!(run)

    assert_equal [first.id, second.id], ScriptedRun.performed,
      "a :continue run must carry on to the remaining targets"
    assert_equal "completed", run.state
    assert_equal [first.id], failed_ids(run)
    assert_equal 2, run.progress_done
  end

  test "a failed advance! does not get counted twice by the failure it causes" do
    post = create_post!(user: @user, organization: @org)
    run = create_run!(ContinuingScriptedRun, target_ids: [post.id])
    ScriptedRun.script = nil

    # advance! mutates progress_done/handled_target_ids in memory and THEN
    # saves. When that save is what fails, the values never reached the row —
    # so recording the failure must not read them back as though they had.
    run.instance_variable_set(:@blown, false)
    run.define_singleton_method(:save!) do |*args, **kw|
      unless @blown
        @blown = true
        raise ActiveRecord::StatementInvalid, "connection lost"
      end
      super(*args, **kw)
    end

    run = execute!(run)

    assert_equal 1, run.progress_done, "a one-target run cannot finish 2 of 1 done"
    assert_equal [post.id.to_s], run.handled_target_ids
    assert_equal 1, run.errors_log.size
  end

  test "a run whose failure cannot be recorded does not escape into a job retry" do
    bad = create_post!(user: @user, organization: @org, title: "bad")
    run = create_run!(ScriptedRun, target_ids: [bad.id])
    ScriptedRun.script = ->(_) { raise "boom" }

    # The run fails, and then recording that failure fails too — a dropped
    # connection, a statement timeout. Nothing may escape: the row is already
    # "running", so every ActiveJob retry's claim! would match zero rows and
    # silently no-op while burning the queue's retry budget.
    executor = Executor.new(run)
    def run.fail!(*) = raise(ActiveRecord::StatementInvalid, "connection lost")

    assert_nothing_raised { executor.call }
  end

  test "a run implementing neither perform nor perform_on fails naming the class" do
    run = execute!(create_run!(UndefinedWorkRun, target_ids: []))

    assert_equal "failed", run.state
    assert_match(/UndefinedWorkRun/, messages(run).first)
    assert_match(/perform_on/, messages(run).first)
  end

  test "a policy predicate renamed since enqueue fails the run once, not once per target" do
    ids = 3.times.map { create_post!(user: @user, organization: @org).id }

    run = execute!(create_run!(ContinuingScriptedRun, target_ids: ids, policy_action: "vanished_action?"))

    assert_empty ScriptedRun.performed, "a missing predicate must never collapse into permission"
    assert_equal "failed", run.state
    assert_equal 1, run.errors_log.size,
      "a systemic failure belongs to the run; one entry per target would write the " \
      "whole errors_log back M times"
    assert_match(/vanished_action\?/, messages(run).first)
  end

  # Context has this failure mode covered on its own; what this pins is that the
  # two classes COMPOSE — that a deliberately designed "this run can no longer be
  # trusted" error is not quietly demoted to a target failure by the per-target
  # rescue it happens to pass through.
  test "an authorization context that dies mid-run fails the run once, not once per remaining target" do
    ids = 4.times.map { create_post!(user: @user, organization: @org).id }
    run = create_run!(ContinuingScriptedRun, target_ids: ids)

    # The tenant vanishes while the first target is being performed. Writing the
    # dangling id onto the executor's own run instance is how a hard-deleted
    # tenant presents itself: the association reloads to nil while the *_type
    # column still says there is one.
    ScriptedRun.script = lambda do |_|
      run.update_columns(scoped_entity_id: "999999999")
      travel Executor::SUBJECT_REFRESH_INTERVAL * 2
    end

    execute!(run)

    assert_equal 1, ScriptedRun.performed.size,
      "nothing may be performed once the context the run authorizes under is gone"
    assert_equal "failed", run.state,
      "a run whose authorization context died did not do its job, whatever :continue says"
    assert_equal 1, run.errors_log.size,
      "systemic: one run-level entry, not the same diagnosis copied onto every remaining target"
    assert_match(/no longer exists/, messages(run).first)
    assert_equal 1, run.progress_done
  end

  test "a run whose initiator was deleted fails instead of crashing" do
    run = create_run!(ContinuingScriptedRun, target_ids: [])
    run.update_columns(initiator_id: "999999999")

    run = execute!(run)

    assert_equal "failed", run.state
    assert_match(/no initiator/, messages(run).first)
  end

  test "a run whose stored context cannot be rebuilt fails instead of crashing" do
    # A policy renamed between enqueue and perform: the context refuses, and the
    # run has to carry that refusal rather than raising into the job forever.
    run = execute!(create_run!(ContinuingScriptedRun, target_ids: [],
      policy_class_name: "StorefrontPortal::Blogging::PostPolicy"))

    assert_equal "failed", run.state
    assert_match(/dispatched under StorefrontPortal::Blogging::PostPolicy/, messages(run).first)
  end

  # --- the job -------------------------------------------------------------

  test "the job rebuilds everything from the row, given only an id" do
    post = create_post!(user: @user, organization: @org, title: "first")
    run = create_run!(ContinuingScriptedRun, target_ids: [post.id])

    Job.perform_now(run.id)

    assert_equal [post.id], ScriptedRun.performed
    assert_equal "completed", run.reload.state
  end

  test "the job is a no-op for a run that is gone or already settled" do
    run = create_run!(ContinuingScriptedRun, target_ids: [create_post!(user: @user, organization: @org).id])
    run.finish!

    Job.perform_now(run.id)
    Job.perform_now(-1)

    assert_empty ScriptedRun.performed, "a settled run must never be performed again"
    assert_equal "completed", run.reload.state
  end

  test "the job takes its queue from configuration" do
    Plutonium.configuration.async_interactions.queue = :low
    assert_equal "low", Job.new.queue_name
  ensure
    Plutonium.configuration.async_interactions.queue = :default
  end

  # --- pre_check ------------------------------------------------------------

  test "an opaque run whose check rejects nothing performs" do
    run = execute!(CheckedOpaqueRun.create!(initiator: @user, scoped_entity: @org))

    assert_equal 1, CheckedOpaqueRun.calls
    assert_equal "completed", run.state
  end

  test "an opaque run whose check rejects is not performed" do
    CheckedOpaqueRun.check = ->(run) { run.reject("missing header: email") }

    run = execute!(CheckedOpaqueRun.create!(initiator: @user, scoped_entity: @org))

    assert_equal 0, CheckedOpaqueRun.calls
    assert_equal "rejected", run.outcome
    assert_equal ["missing header: email"], messages(run)
  end

  test "a targeted check receives the resolved records and gates the work" do
    first = create_post!(user: @user, organization: @org, title: "first")
    second = create_post!(user: @user, organization: @org, title: "second")
    CheckedRun.check = ->(run, records) { run.reject("mixed") if records.size > 1 }

    run = execute!(create_run!(CheckedRun, target_ids: [first.id, second.id]))

    assert_equal [first.id, second.id].sort, CheckedRun.checked.sort
    assert_empty ScriptedRun.performed, "a rejected run must not touch a target"
    assert_equal "rejected", run.outcome
    assert_equal 0, run.progress_done
    assert_equal "first", first.reload.title
  end

  test "a targeted run whose check passes performs every target" do
    post = create_post!(user: @user, organization: @org)

    run = execute!(create_run!(CheckedRun, target_ids: [post.id]))

    assert_equal [post.id], ScriptedRun.performed
    assert_equal "completed", run.state
  end

  test "every rejection is recorded, in order" do
    CheckedOpaqueRun.check = ->(run) { 3.times { |i| run.reject("line #{i + 2}: missing email") } }

    run = execute!(CheckedOpaqueRun.create!(initiator: @user, scoped_entity: @org))

    assert_equal ["line 2: missing email", "line 3: missing email", "line 4: missing email"], messages(run)
  end

  test "rejections past max_rejections are summarized with the exact remainder" do
    config = Plutonium.configuration.async_interactions
    previous = config.max_rejections
    config.max_rejections = 2
    CheckedOpaqueRun.check = ->(run) { 7.times { |i| run.reject("line #{i}") } }

    run = execute!(CheckedOpaqueRun.create!(initiator: @user, scoped_entity: @org))

    assert_equal ["line 0", "line 1", "and 5 more problems were found"], messages(run)
  ensure
    config.max_rejections = previous
  end

  # "Your input is wrong" and "the check itself broke" are different reports.
  test "an exception raised in the check fails the run rather than rejecting it" do
    CheckedOpaqueRun.check = ->(_run) { raise "unreadable file" }

    run = execute!(CheckedOpaqueRun.create!(initiator: @user, scoped_entity: @org))

    assert_equal "failed", run.outcome
    assert_equal ["unreadable file"], messages(run)
    assert_equal 0, CheckedOpaqueRun.calls
  end

  test "a check declared with the wrong arguments names the expected signature" do
    post = create_post!(user: @user, organization: @org)

    run = execute!(create_run!(MisdeclaredCheckRun, target_ids: [post.id]))

    assert_equal "failed", run.state
    assert_match(/MisdeclaredCheckRun#pre_check must take the records/, messages(run).first)
    assert_empty ScriptedRun.performed
  end

  test "a resumed targeted run checks only the records it has left" do
    done = create_post!(user: @user, organization: @org, title: "done")
    remaining = create_post!(user: @user, organization: @org, title: "remaining")
    run = create_run!(CheckedRun, target_ids: [done.id, remaining.id])

    # Simulate an interruption after `done` was dispositioned WITHOUT being
    # applied (a failure), then a reap: the earlier pass approved nothing.
    run.record_target_failure!(id: done.id, message: "missing")
    run.update!(state: "pending")

    execute!(run)

    assert_equal [remaining.id], CheckedRun.checked
  end

  test "a transactional run is rejected without opening a transaction" do
    post = create_post!(user: @user, organization: @org)
    CheckedRun.check = ->(run, _records) { run.reject("no") }

    run = execute!(create_run!(TransactionalCheckedRun, target_ids: [post.id]))

    assert_equal "rejected", run.outcome
    refute TransactionalCheckedRun.batch_opened, "the batch transaction must never open"
    assert_empty ScriptedRun.performed
  end

  # The control for the test above: a passing check does reach the batch.
  test "a transactional run whose check passes opens its batch" do
    post = create_post!(user: @user, organization: @org)

    run = execute!(create_run!(TransactionalCheckedRun, target_ids: [post.id]))

    assert_equal "completed", run.state
    assert TransactionalCheckedRun.batch_opened
  end

  test "a resumed run whose earlier pass applied a target skips the check" do
    first = create_post!(user: @user, organization: @org, title: "first")
    second = create_post!(user: @user, organization: @org, title: "second")
    run = create_run!(CheckedRun, target_ids: [first.id, second.id])

    # An earlier pass applied `first`, so its check had passed.
    Executor.new(run).send(:advance!, first.id)
    CheckedRun.check = ->(r, _records) { r.reject("would reject") }
    run.update!(state: "pending")

    execute!(run)

    assert_equal "completed", run.state
    assert_nil CheckedRun.checked
    assert_equal [second.id], ScriptedRun.performed
  end

  test "a check declared with required keywords names the expected signature" do
    post = create_post!(user: @user, organization: @org)

    run = execute!(create_run!(KeywordCheckRun, target_ids: [post.id]))

    assert_equal "failed", run.state
    assert_match(/KeywordCheckRun#pre_check must take the records/, messages(run).first)
    assert_empty ScriptedRun.performed
  end

  test "an opaque run whose check takes records names the opaque signature" do
    run = execute!(RecordsCheckOpaqueRun.create!(initiator: @user, scoped_entity: @org))

    assert_equal "failed", run.state
    assert_match(/RecordsCheckOpaqueRun#pre_check must take no arguments/, messages(run).first)
  end

  test "a rejection keeps the unresolved entry recorded before it" do
    post = create_post!(user: @user, organization: @org)
    CheckedRun.check = ->(run, _records) { run.reject("no") }

    run = execute!(create_run!(CheckedRun, target_ids: [post.id, post.id + 10_000]))

    assert_equal "rejected", run.outcome
    assert_equal 2, run.errors_log.size
    assert_includes messages(run), "no"
    assert(run.errors_log.any? { |entry| entry["target_id"].to_s == (post.id + 10_000).to_s })
    assert_empty ScriptedRun.performed
  end

  test "supersession during the check abandons the run instead of failing it" do
    CheckedOpaqueRun.check = lambda do |run|
      run.class.where(id: run.id).update_all("lock_version = lock_version + 1")
      run.heartbeat!
    end

    run = execute!(CheckedOpaqueRun.create!(initiator: @user, scoped_entity: @org))

    assert_equal "running", run.reload.state
    assert_empty run.errors_log
    assert_equal 0, CheckedOpaqueRun.calls
  end

  private

  def run_updates(statements) = statements.grep(/UPDATE\s+"?plutonium_async_runs/).size

  def user_selects(statements) = statements.grep(/FROM\s+"?users"?/).size
end
