# Async Run pre_check Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give async runs an optional `pre_check` stage that can reject the run's input, reporting every problem at once, before any work is done.

**Architecture:** `Run` gains a no-op `pre_check`, a `reject` collector that is only live while the check runs, and `reject_run!`, which writes tagged `errors_log` entries and `failed` in one update. `Executor` calls the check after the claim (and, for targeted runs, after target resolution) and stops if anything was rejected. `outcome` reads `"rejected"` from the tagged entries; the progress page and badges render it.

**Tech Stack:** Ruby, Rails (ActiveRecord, I18n), Phlex, Minitest via Appraisal.

**Spec:** `docs/superpowers/specs/2026-10-15-async-run-pre-check-design.md`

**User Verification:** NO. No user verification required.

---

## Ground rules for every task

- Run tests through Appraisal from the repo root:
  `bundle exec appraisal rails-8.1 ruby -Itest <file>` (add `-n "/pattern/"` to pick tests).
- **Never stage or commit** unless the user has asked for commits. Each task ends with a suggested commit message for when they do.
- Test files have no transactional rollback (`test_helper` does not load `rails/test_help`); every suite deletes the rows it creates in `setup` / `teardown`. Follow that.
- Appraisal rewrites `gemfiles/*.gemfile.lock`. Do not stage those.
- Ruby style: no defensive `respond_to?` checks; comments explain *why*, matching the density of the surrounding code; no em dashes in docs.

## File map

| File | Change |
|---|---|
| `lib/plutonium/interaction/async/configuration.rb` | `max_rejections` setting |
| `lib/plutonium/interaction/async/run.rb` | `PRE_CHECK_STAGE`, `pre_check`, `reject`, `collect_rejections`, `reject_run!`, `rejected?`, `outcome` |
| `lib/plutonium/interaction/async/executor.rb` | call the check, arity guard |
| `lib/plutonium/interaction/async/run_definition.rb` | `rejected: :warning` badge colour |
| `lib/plutonium/ui/interaction/async/run_progress.rb` | badge variant, "Nothing was processed" line |
| `config/locales/en/async.yml` | `executor.rejections_truncated`, `executor.pre_check_arity`, `run.reject_outside_pre_check`, `progress.rejected` |
| `test/plutonium/interaction/async/run_test.rb` | model tests |
| `test/plutonium/interaction/async/executor_test.rb` | executor tests |
| `test/integration/admin_portal/async_run_progress_test.rb` | display tests |
| `test/dummy/app/interactions/import_tasks_interaction.rb` | new: CSV import with a pre_check |
| `test/dummy/app/policies/task_policy.rb` | `import_tasks?` |
| `test/dummy/app/definitions/task_definition.rb` | `action :import_tasks` |
| `test/integration/admin_portal/async_import_pre_check_test.rb` | new: end-to-end |
| `docs/reference/behavior/async-interactions.md` | new section, config line, outcome, heartbeat |
| `.claude/skills/plutonium-async-interactions/SKILL.md` | matching section, Critical note |

---

### Task 1: Run model: reject, reject_run!, rejected outcome, max_rejections

**Goal:** `Run` can collect rejections during a check, persist them in one write, and report `outcome == "rejected"`.

**Files:**
- Modify: `lib/plutonium/interaction/async/configuration.rb`
- Modify: `lib/plutonium/interaction/async/run.rb`
- Modify: `config/locales/en/async.yml`
- Test: `test/plutonium/interaction/async/run_test.rb`

**Acceptance Criteria:**
- [ ] `config.async_interactions.max_rejections` defaults to 100.
- [ ] `reject` raises outside `collect_rejections`; inside, it stores up to `max_rejections` messages and counts the rest.
- [ ] `reject_run!(messages, overflow:)` writes entries tagged `"stage" => "pre_check"`, a truncation entry when `overflow > 0`, and `state: "failed"` in a single UPDATE.
- [ ] `outcome` is `"rejected"` for a failed run with a tagged entry; untagged failed runs still read `"failed"`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/run_test.rb` → 0 failures, 0 errors

**Steps:**

- [ ] **Step 1: Write the failing tests**

Append inside `class Plutonium::Interaction::RunTest` in `test/plutonium/interaction/async/run_test.rb` (before its final `end`):

```ruby
  # --- pre_check rejections -------------------------------------------------

  def with_max_rejections(limit)
    config = Plutonium.configuration.async_interactions
    previous = config.max_rejections
    config.max_rejections = limit
    yield
  ensure
    config.max_rejections = previous
  end

  test "max_rejections defaults to 100" do
    assert_equal 100, Plutonium::Interaction::Async::Configuration.new.max_rejections
  end

  # A rejection outside the check would be collected by nothing and lost.
  test "reject outside a check raises" do
    error = assert_raises(RuntimeError) { build.reject("bad row") }
    assert_match(/only available inside pre_check/, error.message)
  end

  test "collect_rejections returns the messages and how many went past the cap" do
    run = build

    messages, overflow = with_max_rejections(2) do
      run.collect_rejections { 5.times { |i| run.reject("row #{i}") } }
    end

    assert_equal ["row 0", "row 1"], messages
    assert_equal 3, overflow
  end

  test "reject is closed again once the check is over" do
    run = build
    run.collect_rejections { run.reject("inside") }

    assert_raises(RuntimeError) { run.reject("after") }
  end

  test "reject_run! records tagged entries and fails the run in one write" do
    run = build(TestOpaqueRun)
    run.save!

    statements = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      statements << payload[:sql] if payload[:sql].start_with?("UPDATE")
    end
    run.reject_run!(["line 2: missing email", "line 9: missing email"], overflow: 0)
    ActiveSupport::Notifications.unsubscribe(subscriber)

    assert_equal 1, statements.size, "entries and state must land together"
    run.reload
    assert_equal "failed", run.state
    refute_nil run.finished_at
    assert_equal ["line 2: missing email", "line 9: missing email"], run.errors_log.map { |e| e["message"] }
    assert(run.errors_log.all? { |e| e["stage"] == "pre_check" && e["target_id"].nil? })
    assert_equal 0, run.progress_done
  end

  test "reject_run! adds one entry for the problems past the cap" do
    run = build(TestOpaqueRun)
    run.save!

    run.reject_run!(["line 2: missing email"], overflow: 4_900)

    last = run.reload.errors_log.last
    assert_equal "and 4900 more problems were found", last["message"]
    assert_equal "pre_check", last["stage"]
  end

  test "a run rejected by its check reads rejected, not failed" do
    run = build(TestOpaqueRun, state: "failed",
      errors_log: [{"target_id" => nil, "message" => "bad header", "stage" => "pre_check"}])

    assert_equal "rejected", run.outcome
    assert run.rejected?
  end

  test "a failed run without check entries still reads failed" do
    run = build(TestOpaqueRun, state: "failed",
      errors_log: [{"target_id" => nil, "message" => "boom"}])

    assert_equal "failed", run.outcome
    refute run.rejected?
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/run_test.rb -n "/reject|max_rejections/"`
Expected: FAIL / ERROR (`undefined method 'max_rejections'`, `undefined method 'reject'`, ...)

- [ ] **Step 3: Add the setting**

In `lib/plutonium/interaction/async/configuration.rb`, after the `attachment_backend` accessor:

```ruby
        # @return [Integer] how many pre_check rejections a run stores. The rest
        #   are counted and reported as one "and N more" entry, so a file that is
        #   bad on every row cannot write tens of thousands of entries into the
        #   errors_log column (and onto the progress page).
        attr_accessor :max_rejections
```

and in `initialize`, after `@stall_after = 1.hour`:

```ruby
          @max_rejections = 100
```

- [ ] **Step 4: Add the locale keys**

In `config/locales/en/async.yml`, under `plutonium.async.run` add:

```yaml
        reject_outside_pre_check: "%{run_class}#reject is only available inside pre_check"
```

and under `plutonium.async.executor` add:

```yaml
        rejections_truncated:
          one: "and %{count} more problem was found"
          other: "and %{count} more problems were found"
```

- [ ] **Step 5: Implement on Run**

In `lib/plutonium/interaction/async/run.rb`, after `FAILURE_POLICIES = ...`:

```ruby
        # Tags the errors_log entries a pre_check rejection writes, which is what
        # #outcome reads "rejected" from. A key in the existing JSON rather than a
        # column: older entries simply lack it.
        PRE_CHECK_STAGE = "pre_check"
```

Replace `#outcome` with:

```ruby
        def outcome
          return "rejected" if rejected?

          (state == "completed" && errors_log.any?) ? "completed_with_errors" : state
        end

        # Failed because its pre_check refused the input, as opposed to failing
        # while doing the work. Nothing was processed. state stays "failed", so
        # every reader keyed on state (ReapJob, in_progress, the banner) is
        # unaffected.
        def rejected? = state == "failed" && errors_log.any? { |entry| entry["stage"] == PRE_CHECK_STAGE }
```

After `#record_target_failures!`, add:

```ruby
        # Fails the run with its pre_check's rejections, in ONE write, for the
        # reason record_target_failures! gives: a crash between two writes must
        # not leave a failed run without its reasons, or reasons on a run still
        # marked running. Entries carry the run-level nil target_id, so progress
        # and handled_target_ids are untouched: nothing was processed.
        #
        # @param messages [Array<String>] the rejections that were stored
        # @param overflow [Integer] how many more were rejected past max_rejections
        def reject_run!(messages, overflow: 0)
          entries = messages.map { |message| pre_check_entry(message) }
          entries << pre_check_entry(I18n.t("plutonium.async.executor.rejections_truncated", count: overflow)) if overflow.positive?

          now = Time.current
          update!(errors_log: errors_log + entries, state: "failed", finished_at: now, last_activity_at: now)
        end

        # Runs the block with #reject live, and closes it again afterwards.
        # Called by Async::Executor around pre_check.
        #
        # @return [Array(Array<String>, Integer)] the stored messages, and how
        #   many more were rejected past max_rejections
        def collect_rejections
          @rejections = []
          @rejection_count = 0
          yield
          [@rejections, @rejection_count - @rejections.size]
        ensure
          @rejections = nil
        end

        # Records one problem with the run's input and returns, so a check can
        # report every bad row in one pass. Only live inside pre_check: a
        # rejection from perform would be collected by nothing.
        #
        # Counts past max_rejections but stores no more than that, so memory
        # stays bounded and the "and N more" count is exact.
        #
        # @param message [String]
        # @return [void]
        def reject(message)
          raise I18n.t("plutonium.async.run.reject_outside_pre_check", run_class: self.class) if @rejections.nil?

          @rejection_count += 1
          @rejections << message.to_s if @rejections.size < Plutonium.configuration.async_interactions.max_rejections
          nil
        end
```

After the base `#perform` (the one raising `NotImplementedError`), add:

```ruby
        # Checks the run's input before any work, and refuses it with #reject.
        # Optional: the default checks nothing. Override it as
        # +pre_check(records)+ in a run with +perform_on+ (it receives the
        # resolved, authorized records), or +pre_check+ for opaque work.
        # See Async::Executor#pre_check_passed?.
        def pre_check(*) = nil
```

In the `private` section, add:

```ruby
        def pre_check_entry(message) = {"target_id" => nil, "message" => message, "stage" => PRE_CHECK_STAGE}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/run_test.rb`
Expected: 0 failures, 0 errors

- [ ] **Step 7: Suggested commit (only when the user asks for commits)**

`feat(async): let a run reject its input with reject / reject_run!`

```json:metadata
{"files": ["lib/plutonium/interaction/async/configuration.rb", "lib/plutonium/interaction/async/run.rb", "config/locales/en/async.yml", "test/plutonium/interaction/async/run_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/run_test.rb", "acceptanceCriteria": ["max_rejections defaults to 100", "reject raises outside collect_rejections and caps stored messages", "reject_run! writes tagged entries and failed in one UPDATE", "outcome reads rejected only for tagged failed runs"], "requiresUserVerification": false}
```

---

### Task 2: Executor runs the check before the work

**Goal:** The executor calls `pre_check` with the right arguments for the run's shape and stops before any work when it rejects.

**Files:**
- Modify: `lib/plutonium/interaction/async/executor.rb` (`perform_opaque`, `perform_targets`, new private methods)
- Modify: `config/locales/en/async.yml`
- Test: `test/plutonium/interaction/async/executor_test.rb`

**Acceptance Criteria:**
- [ ] Opaque and targeted runs whose check rejects nothing perform as before.
- [ ] A rejection stops `perform` / `perform_on`; `progress_done` stays 0; `outcome == "rejected"`.
- [ ] Every rejection is recorded; past `max_rejections`, one "and N more" entry with the exact remainder.
- [ ] An exception raised in `pre_check` reads `failed`, not `rejected`.
- [ ] A wrong-arity `pre_check` fails the run with a message naming the class and expected signature.
- [ ] A resumed targeted run's check receives only the unhandled records.
- [ ] A `:transactional` run is rejected without opening a transaction.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/executor_test.rb` → 0 failures, 0 errors

**Steps:**

- [ ] **Step 1: Write the failing tests**

In `test/plutonium/interaction/async/executor_test.rb`, add these fixture classes after `class UndefinedWorkRun ... end` (top level, before the test class):

```ruby
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
```

In the test class `setup`, after `OpaqueScriptedRun.calls = 0`, add:

```ruby
    CheckedRun.check = nil
    CheckedRun.checked = nil
    TransactionalCheckedRun.batch_opened = false
    CheckedOpaqueRun.check = nil
    CheckedOpaqueRun.calls = 0
```

Append these tests inside the test class (before its final `end`):

```ruby
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

    # Simulate an interruption after `done` was applied, then a reap.
    Executor.new(run).send(:advance!, done.id)
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/executor_test.rb -n "/check|rejection/"`
Expected: FAIL (rejected runs still perform; outcome reads `completed`)

- [ ] **Step 3: Add the arity message**

In `config/locales/en/async.yml`, under `plutonium.async.executor`:

```yaml
        pre_check_arity:
          targeted: "%{run_class}#pre_check must take the records: define pre_check(records) on a run with perform_on"
          opaque: "%{run_class}#pre_check must take no arguments: define pre_check on a run with perform"
```

- [ ] **Step 4: Wire the check into the executor**

In `lib/plutonium/interaction/async/executor.rb`, replace `perform_opaque` with:

```ruby
        def perform_opaque
          return unless pre_check_passed?

          run.send(:perform)
          run.finish!
        end
```

In `perform_targets`, after the line `return refuse_partial_batch(resolved) if unresolved?(resolved) && !continue?`, add:

```ruby
          return unless pre_check_passed?(resolved.records)
```

Add these private methods after `perform_targets`:

```ruby
        # Runs the run's pre_check with #reject live, and fails the run with
        # whatever it rejected. Before any work: a rejected run touches no
        # target. Outside the :transactional batch, which never opens for a
        # rejected run.
        #
        # An exception from the check is NOT a rejection. It propagates to #call
        # and fails the run the ordinary way, so "your input is wrong" and "the
        # check itself broke" stay distinguishable (Run#outcome).
        #
        # send, for the reason #perform_opaque gives.
        #
        # @return [Boolean] whether the work may go ahead
        def pre_check_passed?(*args)
          verify_pre_check_arity!(args.size)

          messages, overflow = run.collect_rejections { run.send(:pre_check, *args) }
          return true if messages.empty? && overflow.zero?

          run.reject_run!(messages, overflow: overflow)
          false
        end

        # A targeted check declared opaque-style (or the reverse) would raise a
        # bare "wrong number of arguments" from inside the executor, naming
        # neither the class nor the fix.
        #
        # Raised as NotImplementedError ("the run class is written wrong"), which
        # #call records like any other failure.
        def verify_pre_check_arity!(given)
          arity = run.method(:pre_check).arity
          return if arity.negative? ? given >= arity.abs - 1 : arity == given

          raise NotImplementedError, I18n.t(
            "plutonium.async.executor.pre_check_arity.#{run.targeted? ? "targeted" : "opaque"}",
            run_class: run.class
          )
        end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/executor_test.rb`
Expected: 0 failures, 0 errors (all pre-existing executor tests still pass, since the base `pre_check(*)` accepts any arity and rejects nothing)

- [ ] **Step 6: Run the rest of the async suite**

Run: `bundle exec appraisal rails-8.1 ruby -Itest -e 'Dir["test/plutonium/interaction/async/*_test.rb"].each { |f| require File.expand_path(f) }'`
Expected: 0 failures, 0 errors

- [ ] **Step 7: Suggested commit (only when the user asks for commits)**

`feat(async): run a pre_check before the work and stop on rejection`

```json:metadata
{"files": ["lib/plutonium/interaction/async/executor.rb", "config/locales/en/async.yml", "test/plutonium/interaction/async/executor_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/async/executor_test.rb", "acceptanceCriteria": ["passing checks perform as before", "rejection stops work, progress_done 0, outcome rejected", "cap with exact remainder", "exception in check reads failed", "wrong arity names expected signature", "resumed run checks remaining records only", "transactional rejection opens no batch transaction"], "requiresUserVerification": false}
```

---

### Task 3: Show rejected runs on the progress page and index

**Goal:** A rejected run shows a warning "Rejected" badge, a "Nothing was processed" line, and its messages.

**Files:**
- Modify: `lib/plutonium/ui/interaction/async/run_progress.rb` (`BADGE_VARIANTS`, `render_panel`, new `render_rejected`)
- Modify: `lib/plutonium/interaction/async/run_definition.rb` (both `colors:` hashes)
- Modify: `config/locales/en/async.yml`
- Test: `test/integration/admin_portal/async_run_progress_test.rb`

**Acceptance Criteria:**
- [ ] The show page renders a `pu-badge-warning` badge reading "Rejected", the line "Nothing was processed", and every rejection message.
- [ ] A plain failed run does not show "Nothing was processed".
- [ ] The index renders "Rejected" for the run.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_run_progress_test.rb` → 0 failures, 0 errors

**Steps:**

- [ ] **Step 1: Write the failing tests**

Append inside `AdminPortal::AsyncRunProgressTest` (before its final `end`):

```ruby
  def rejection(message) = {"target_id" => nil, "message" => message, "stage" => "pre_check"}

  test "a rejected run says so, says nothing was processed, and lists every problem" do
    run = create_run!(state: "failed", progress_total: 3, progress_done: 0,
      errors_log: [rejection("line 2: missing email"), rejection("line 7: missing email")])

    get run_path(run)
    assert_response :success

    assert_match(/pu-badge-warning[^>]*>\s*Rejected\s*</, response.body)
    assert_match(/Nothing was processed/, response.body)
    assert_match(/line 2: missing email/, response.body)
    assert_match(/line 7: missing email/, response.body)
  end

  test "a run that failed while working does not claim nothing was processed" do
    run = create_run!(state: "failed", errors_log: [{"target_id" => nil, "message" => "boom"}])

    get run_path(run)

    refute_match(/Nothing was processed/, response.body)
  end

  test "the index shows a rejected run as rejected" do
    create_run!(state: "failed", errors_log: [rejection("bad header")])

    get "/admin/async_runs"

    assert_match(/Rejected/, response.body)
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_run_progress_test.rb -n "/rejected|nothing was processed/"`
Expected: FAIL (no "Nothing was processed"; badge variant is `neutral`)

- [ ] **Step 3: Add the locale key**

In `config/locales/en/async.yml`, under `plutonium.async.progress`:

```yaml
        rejected: "Nothing was processed"
```

- [ ] **Step 4: Render it**

In `lib/plutonium/ui/interaction/async/run_progress.rb`, add to `BADGE_VARIANTS` after `"completed_with_errors" => "warning",`:

```ruby
            # The input was refused, nothing broke: see Run#rejected?.
            "rejected" => "warning",
```

Replace `render_panel` with:

```ruby
          def render_panel
            div(class: "pu-card pu-run-progress", **poll_attributes) do
              div(class: "pu-card-body space-y-4") do
                render_status
                render_progress
                render_rejected if run.rejected?
                render_failures if run.errors_log.any?
              end
            end
          end
```

Add after `render_status`:

```ruby
          # "0 of 50 targets" under a red list reads as a run that died at its
          # first target. A rejected run never started, and says so.
          def render_rejected
            div(class: "text-sm text-[var(--pu-text-muted)]") do
              plain t("plutonium.async.progress.rejected")
            end
          end
```

In `lib/plutonium/interaction/async/run_definition.rb`, change both `colors:` hashes (on `display :outcome` and `column :outcome`) to:

```ruby
          colors: {running: :info, completed_with_errors: :warning, rejected: :warning}
```

and add `rejected` to the comment above them: "`running`, `completed_with_errors` and `rejected` are coloured explicitly".

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_run_progress_test.rb`
Expected: 0 failures, 0 errors

- [ ] **Step 6: Suggested commit (only when the user asks for commits)**

`feat(async): show rejected runs as rejected on the progress page and index`

```json:metadata
{"files": ["lib/plutonium/ui/interaction/async/run_progress.rb", "lib/plutonium/interaction/async/run_definition.rb", "config/locales/en/async.yml", "test/integration/admin_portal/async_run_progress_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_run_progress_test.rb", "acceptanceCriteria": ["warning Rejected badge, Nothing was processed, all messages on show page", "plain failed run lacks the line", "index shows Rejected"], "requiresUserVerification": false}
```

---

### Task 4: Dummy CSV import with a pre_check, end to end

**Goal:** A real interaction in the dummy app exercises dispatch → staged file → pre_check → rejected or completed, and backs the docs example.

**Files:**
- Create: `test/dummy/app/interactions/import_tasks_interaction.rb`
- Modify: `test/dummy/app/policies/task_policy.rb` (after `archive_all_async?`)
- Modify: `test/dummy/app/definitions/task_definition.rb` (after `action :archive_all_async`)
- Create: `test/integration/admin_portal/async_import_pre_check_test.rb`

**Acceptance Criteria:**
- [ ] Posting a CSV with bad rows creates a run that, once executed, reads `rejected`, lists one message per bad row, and creates no tasks.
- [ ] Posting a valid CSV creates the tasks and the run reads `completed`.
- [ ] The rejected run's progress page shows the badge and messages.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_import_pre_check_test.rb` → 0 failures, 0 errors

**Steps:**

- [ ] **Step 1: Write the failing test**

Create `test/integration/admin_portal/async_import_pre_check_test.rb`:

```ruby
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
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_import_pre_check_test.rb`
Expected: ERROR, `uninitialized constant ImportTasksInteraction`

- [ ] **Step 3: Write the interaction**

Create `test/dummy/app/interactions/import_tasks_interaction.rb`:

```ruby
# frozen_string_literal: true

require "csv"

# A CSV import that checks the WHOLE file before creating anything: the
# browser-drivable example of an async run's pre_check. A file with a bad row
# is rejected with every problem listed, and no task is created.
class ImportTasksInteraction < ::ResourceInteraction
  presents label: "Import tasks (async)",
    icon: Phlex::TablerIcons::Upload

  attribute :import_file
  input :import_file, as: :file

  validates :import_file, presence: true

  async do
    def pre_check
      each_row do |row, line|
        reject "line #{line}: title is missing" if row["title"].blank?
        unless row["status"].blank? || Task::IMPORTABLE_STATUSES.include?(row["status"])
          reject "line #{line}: unknown status #{row["status"].inspect}"
        end
      end
    end

    def perform
      each_row { |row, _line| Task.create!(title: row["title"], status: row["status"].presence || "todo") }
    end

    private

    # Line numbers as a spreadsheet shows them: the header is line 1.
    def each_row(&)
      attachment(:import_file).open do |file|
        CSV.new(file, headers: true).each.with_index(2, &)
      end
    end
  end
end
```

Add the constant to `test/dummy/app/models/task.rb`, under `# add constants above.` (put it above that marker comment):

```ruby
  IMPORTABLE_STATUSES = %w[todo doing done review].freeze
```

- [ ] **Step 4: Gate and declare the action**

In `test/dummy/app/policies/task_policy.rb`, after `archive_all_async?`:

```ruby
  # Resource action: a CSV import dispatched to a run whose pre_check checks
  # the whole file first.
  def import_tasks?
    create?
  end
```

In `test/dummy/app/definitions/task_definition.rb`, after `action :archive_all_async, ...`:

```ruby
  # Resource action, dispatched to a run that checks the whole file before
  # importing any of it (see ImportTasksInteraction#pre_check).
  action :import_tasks, interaction: ImportTasksInteraction
```

- [ ] **Step 5: Run it to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_import_pre_check_test.rb`
Expected: 0 failures, 0 errors

If `post` answers with a non-redirect (422), print `response.body` and check the form param key; the interactive action form posts `interaction[...]` (see `test/integration/admin_portal/async_dispatch_response_test.rb`).

- [ ] **Step 6: Run the full suite**

Run: `bundle exec appraisal rails-8.1 rake test`
Expected: 0 failures, 0 errors. (Task actions appear in other Task integration tests; a new resource-action button must not break their assertions.)

- [ ] **Step 7: Suggested commit (only when the user asks for commits)**

`test(async): CSV import in the dummy app exercising pre_check end to end`

```json:metadata
{"files": ["test/dummy/app/interactions/import_tasks_interaction.rb", "test/dummy/app/models/task.rb", "test/dummy/app/policies/task_policy.rb", "test/dummy/app/definitions/task_definition.rb", "test/integration/admin_portal/async_import_pre_check_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/async_import_pre_check_test.rb", "acceptanceCriteria": ["bad CSV rejected whole with one message per bad row and no tasks", "valid CSV imported and completed", "progress page shows Rejected and messages"], "requiresUserVerification": false}
```

---

### Task 5: Docs and skill

**Goal:** The reference doc and the shipped skill explain `pre_check`, `reject`, the `rejected` outcome, `max_rejections`, and the heartbeat requirement, with samples that match the dummy app.

**Files:**
- Modify: `docs/reference/behavior/async-interactions.md`
- Modify: `.claude/skills/plutonium-async-interactions/SKILL.md`

**Acceptance Criteria:**
- [ ] A "Checking input before processing" section after "### Files" in the doc, and after "## Attributes and files" in the skill.
- [ ] `max_rejections` in the doc's Enabling config block.
- [ ] "Outcome vs state" documents `rejected`.
- [ ] Both heartbeat warnings mention `pre_check`.
- [ ] No em dashes; samples match `ImportTasksInteraction`.
- [ ] `yarn docs:build` passes.

**Verify:** `yarn docs:build` → completes without dead-link errors

**Steps:**

- [ ] **Step 1: Doc, config block**

In `docs/reference/behavior/async-interactions.md`, in the Enabling block, after the `stall_after` line:

```ruby
  config.async_interactions.max_rejections = 100     # pre_check problems stored per run
```

- [ ] **Step 2: Doc, new section**

Insert before `### Sharing one run across interactions`:

````markdown
### Checking input before processing

Validations on the interaction run in the request, so they suit cheap checks (an uploader's size and type rules already fail the form there). A check too slow for a request, like reading every row of a large file, goes in the run's `pre_check`. It runs in the job, before any work, and refuses the input with `reject`:

```ruby
async do
  def pre_check
    each_row do |row, line|
      reject "line #{line}: title is missing" if row["title"].blank?
    end
  end

  def perform
    each_row { |row, _line| Task.create!(title: row["title"]) }
  end

  private

  def each_row(&)
    attachment(:import_file).open do |file|
      CSV.new(file, headers: true).each.with_index(2, &)
    end
  end
end
```

- `reject` records a problem and returns, so one pass reports every bad row.
- If anything was rejected, the run ends `failed` with `outcome == "rejected"`, the problems listed on its progress page, and `perform` / `perform_on` never runs.
- A run with `perform_on` declares `pre_check(records)` and receives the resolved, authorized records the loop is about to process.
- An exception raised inside `pre_check` fails the run the ordinary way (`outcome == "failed"`): the check broke, the input was not judged.
- Only the first `config.async_interactions.max_rejections` problems (default 100) are stored, followed by one "and N more problems were found" entry.
- The check runs again when a stalled run is resumed, so it must only read. A resumed targeted run checks the records it has left, unless an earlier pass already applied a target (that pass's check passed, so it is not repeated).
- A targeted check receives the records as loaded when the run resolved its targets. `perform_on` gets each record re-read just before it runs, so a verdict based on record state can be stale by then; re-check anything that must hold at the moment of the work inside `perform_on`.
- A long check must call `heartbeat!` (see [Long work must say it is alive](#long-work-must-say-it-is-alive)).
````

- [ ] **Step 3: Doc, outcome section**

In "## Outcome vs state", after the code block, add:

```markdown
A run whose `pre_check` rejected its input reads `outcome == "rejected"` (its `state` is `"failed"`, and nothing was processed). A run that failed while working reads `"failed"`.
```

- [ ] **Step 4: Doc, heartbeat section**

In "### Long work must say it is alive", change the first bullet's opening to:
"**Opaque work, and any `pre_check`.** Between the claim and `finish!` the executor writes nothing, because there is nothing to count."

- [ ] **Step 5: Skill**

In `.claude/skills/plutonium-async-interactions/SKILL.md`:

In the Critical bullet "**Long work must call `heartbeat!`.**", after "so opaque `perform` writes nothing at all between claim and finish." add: "The same holds for `pre_check`."

Insert a section before `## Registering the Run resource`:

````markdown
## Checking input before processing (`pre_check`)

For checks too slow for the request (every row of a large file, lookups per row), define `pre_check` in the run. It runs in the job before any work; `reject` records a problem and keeps going:

```ruby
async do
  def pre_check                     # targeted runs: def pre_check(records)
    each_row do |row, line|
      reject "line #{line}: title is missing" if row["title"].blank?
    end
  end

  def perform
    each_row { |row, _line| Task.create!(title: row["title"]) }
  end

  private

  def each_row(&)
    attachment(:import_file).open { |f| CSV.new(f, headers: true).each.with_index(2, &) }
  end
end
```

- Any rejection: run ends `failed`, `outcome == "rejected"`, problems on the progress page, no work done.
- An exception in `pre_check` is a plain `failed`, not `rejected`.
- `config.async_interactions.max_rejections` (default 100) caps stored problems; the rest become one "and N more" entry.
- It re-runs on resume, so it must only read. Long checks must `heartbeat!`.
- `reject` outside `pre_check` raises.
````

- [ ] **Step 6: Build the docs**

Run: `yarn docs:build`
Expected: build completes; no dead-link errors.

- [ ] **Step 7: Suggested commit (only when the user asks for commits)**

`docs(async): document pre_check, reject and the rejected outcome`

```json:metadata
{"files": ["docs/reference/behavior/async-interactions.md", ".claude/skills/plutonium-async-interactions/SKILL.md"], "verifyCommand": "yarn docs:build", "acceptanceCriteria": ["new section in doc and skill", "max_rejections in config block", "rejected in Outcome vs state", "heartbeat notes mention pre_check", "no em dashes", "docs build passes"], "requiresUserVerification": false}
```

---

## Final verification

- [ ] `bundle exec appraisal rails-8.1 rake test` → 0 failures, 0 errors
- [ ] `bundle exec appraisal rails-7 ruby -Itest -e 'Dir["test/plutonium/interaction/async/*_test.rb", "test/integration/admin_portal/async_*_test.rb"].each { |f| require File.expand_path(f) }'` → 0 failures, 0 errors
- [ ] `yarn docs:build` passes
- [ ] `git status` shows no staged `gemfiles/*.gemfile.lock`
