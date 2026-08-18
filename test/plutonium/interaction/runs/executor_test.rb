# frozen_string_literal: true

require "test_helper"

# These run subclasses live here rather than in test/dummy/app/runs because
# their BEHAVIOUR is the fixture: each exists to push the executor down one
# branch, and a script hook lets a single test say exactly what perform_on does.
# The dummy app's runs (TestPostRun and friends) are deliberately inert, which is
# what the context tests needed and what these tests cannot use.
class ScriptedRun < Plutonium::Interaction::Run
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

class OpaqueScriptedRun < Plutonium::Interaction::Run
  cattr_accessor :calls

  def perform = self.class.calls += 1
end

# Implements NEITHER perform nor perform_on: an author error that must surface
# as a diagnosis, not a NoMethodError from inside the loop.
class UndefinedWorkRun < Plutonium::Interaction::Run
end

class Plutonium::Interaction::Runs::ExecutorTest < ActiveSupport::TestCase
  include DataHelpers
  include ActiveSupport::Testing::TimeHelpers

  Executor = Plutonium::Interaction::Runs::Executor
  Job = Plutonium::Interaction::Runs::Job

  # No transactional rollback in this suite (test_helper never loads
  # rails/test_help), so rows and class-level state persist between tests.
  setup do
    Plutonium::Interaction::Run.delete_all

    ScriptedRun.script = nil
    ScriptedRun.performed = []
    OpaqueScriptedRun.calls = 0

    @user = create_user!
    @org = create_organization!
    @other_org = create_organization!
  end

  teardown { Plutonium::Interaction::Run.delete_all }

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
      assert_match(/#{run.failure_policy}/, messages(run).last)
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

    Executor.new(Plutonium::Interaction::Run.find(run.id)).call
    Executor.new(Plutonium::Interaction::Run.find(run.id)).call

    assert_equal [good.id], ScriptedRun.performed, "the second delivery must not repeat the first's work"
    assert_equal "completed", run.reload.state
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
    Plutonium.configuration.interaction_runs.queue = :low
    assert_equal "low", Job.new.queue_name
  ensure
    Plutonium.configuration.interaction_runs.queue = :default
  end

  private

  def run_updates(statements) = statements.grep(/UPDATE\s+"?plutonium_interaction_runs/).size

  def user_selects(statements) = statements.grep(/FROM\s+"?users"?/).size
end
