# Async Interactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an interaction enqueue its work as a persisted run that reports progress, records who started it, and appears as a browsable resource.

**Architecture:** A single STI table `plutonium_interaction_runs` holds every run; authors subclass `Plutonium::Interaction::Run` to define execution and failure policy, and options ride in a JSON column so an async action costs zero migrations. Interactions keep their existing job (inputs, validation, authorization) and only dispatch, so `Outcome` stays synchronous. The job rebuilds the `(initiator, scoped_entity)` policy context rather than inheriting one, and re-resolves targets through the policy scope at perform time.

**Tech Stack:** Rails 7.2+/8.x, ActiveJob, ActiveRecord STI, Phlex views, Turbo, minitest + appraisal.

**User Verification:** NO — no user verification required. The spec asks for a working subsystem; correctness is established by the test suite, particularly the authorization tests in Task 3.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/plutonium/interaction/runs/configuration.rb` | `enabled`, `queue`, `cleanup_after` config |
| `db/migrate/interaction_runs/20260817000001_create_plutonium_interaction_runs.rb` | The table |
| `lib/plutonium/interaction/run.rb` | STI base: state, progress, options, targets |
| `lib/plutonium/interaction/runs/context.rb` | Rebuilds `(initiator, scoped_entity)`; resolves targets through the policy scope |
| `lib/plutonium/interaction/runs/executor.rb` | Perform loop + failure policies |
| `lib/plutonium/interaction/runs/job.rb` | ActiveJob entry point |
| `lib/plutonium/interaction/concerns/dispatchable.rb` | `dispatches_to` on the interaction |
| `lib/plutonium/interaction/runs/definition.rb` | Resource definition for the run |
| `lib/plutonium/interaction/runs/policy.rb` | Who may see a run |
| `lib/plutonium/ui/interaction/run_progress.rb` | Progress panel (poll frame) |
| `lib/plutonium/ui/interaction/running_banner.rb` | In-progress list on a target index |

Task 3 is the security core. Tasks 1–2 are prerequisites for everything; 4–7 depend on 3.

---

### Task 1: Config, migration and registration

**Goal:** The `plutonium_interaction_runs` table exists in a host app when the feature is enabled, following the wizard subsystem's exact pattern.

**Files:**
- Create: `lib/plutonium/interaction/runs/configuration.rb`
- Create: `db/migrate/interaction_runs/20260817000001_create_plutonium_interaction_runs.rb`
- Modify: `lib/plutonium/railtie.rb` (beside the existing `Migrations.register(:wizards, ...)` call)
- Modify: `lib/plutonium/configuration.rb` (expose `interaction_runs`)
- Test: `test/plutonium/interaction/runs/configuration_test.rb`

**Acceptance Criteria:**
- [ ] `Plutonium.configuration.interaction_runs.enabled` defaults to `false`
- [ ] `Plutonium::Migrations.enabled_paths` includes the runs path only when enabled
- [ ] Polymorphic `*_id` columns are `string`, so uuid-keyed host apps work
- [ ] The migration runs cleanly on the dummy app

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/configuration_test.rb` → 0 failures

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/interaction/runs/configuration_test.rb
require "test_helper"

class Plutonium::Interaction::Runs::ConfigurationTest < ActiveSupport::TestCase
  test "is disabled by default" do
    refute Plutonium::Interaction::Runs::Configuration.new.enabled
  end

  test "migration path is surfaced only when enabled" do
    Plutonium::Migrations.reset!
    path = Plutonium.root.join("db/migrate/interaction_runs").to_s
    Plutonium::Migrations.register(:interaction_runs, path)

    Plutonium.configuration.interaction_runs.enabled = false
    refute_includes Plutonium::Migrations.enabled_paths, path

    Plutonium.configuration.interaction_runs.enabled = true
    assert_includes Plutonium::Migrations.enabled_paths, path
  ensure
    Plutonium.configuration.interaction_runs.enabled = false
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/configuration_test.rb`
Expected: FAIL — `uninitialized constant Plutonium::Interaction::Runs`

- [ ] **Step 3: Add the configuration class**

```ruby
# lib/plutonium/interaction/runs/configuration.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # Configuration for persisted interaction runs. Mirrors
      # Plutonium::Wizard::Configuration: `enabled` gates both the subsystem and
      # its migrations (see Plutonium::Migrations).
      class Configuration
        # @return [Boolean] whether runs (and their migrations) are enabled
        attr_accessor :enabled

        # @return [Symbol] ActiveJob queue for run jobs
        attr_accessor :queue

        def initialize
          @enabled = false
          @queue = :default
        end
      end
    end
  end
end
```

- [ ] **Step 4: Expose it on the main configuration**

In `lib/plutonium/configuration.rb`, beside `@wizards = Plutonium::Wizard::Configuration.new` in `initialize`:

```ruby
      @interaction_runs = Plutonium::Interaction::Runs::Configuration.new
```

and add `:interaction_runs` to the same `attr_reader` that exposes `:wizards`.

- [ ] **Step 5: Register the migration path**

In `lib/plutonium/railtie.rb`, directly below the existing wizard registration:

```ruby
      Plutonium::Migrations.register(:interaction_runs, Plutonium.root.join("db/migrate/interaction_runs").to_s)
```

- [ ] **Step 6: Write the migration**

```ruby
# db/migrate/interaction_runs/20260817000001_create_plutonium_interaction_runs.rb
# frozen_string_literal: true

class CreatePlutoniumInteractionRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :plutonium_interaction_runs do |t|
      # STI discriminator — the author's Run subclass.
      t.string :type, null: false
      t.string :state, null: false, default: "pending" # pending | running | completed | failed

      # JSON payloads are jsonb, matching plutonium_wizard_sessions: Postgres
      # hosts get equality and GIN indexing (plain json has neither), and SQLite
      # hosts get the type via PLUTONIUM_SQLITE_TYPE_ALIASES, which aliases
      # jsonb -> json. Changing a column type post-release costs every host app a
      # migration, so pick the queryable one now.
      #
      # The dispatching interaction's validated inputs.
      t.public_send(:jsonb, :options, null: false, default: {})

      # Targets. target_type is a REAL column, not JSON: the index feature
      # queries "runs for this resource", which cannot be indexed out of a
      # JSON array. Ids are stored as given and re-resolved through the policy
      # scope at perform time (see Runs::Context).
      t.string :target_type
      t.public_send(:jsonb, :target_ids, null: false, default: [])

      # Who started it, and in which tenant. BOTH are required to rebuild the
      # policy context: Plutonium authorizes on (user, entity_scope), so the
      # user alone would re-resolve targets under the wrong tenant — and that
      # fails OPEN. *_id is string-typed to accommodate bigint or uuid host
      # primary keys, matching plutonium_wizard_sessions.
      t.string :initiator_type, null: false
      t.string :initiator_id, null: false
      t.string :scoped_entity_type
      t.string :scoped_entity_id

      # Counts. Both nil for opaque (untargeted) work — the progress UI reads
      # nil as "indeterminate" rather than 0%.
      t.integer :progress_total
      t.integer :progress_done, null: false, default: 0

      t.public_send(:jsonb, :errors_log, null: false, default: [])

      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps

      t.index [:target_type, :state], name: "idx_pu_runs_on_target_and_state"
      t.index [:initiator_type, :initiator_id], name: "idx_pu_runs_on_initiator"
      t.index [:scoped_entity_type, :scoped_entity_id], name: "idx_pu_runs_on_scoped_entity"
    end
  end
end
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/configuration_test.rb`
Expected: PASS, 2 runs 0 failures

- [ ] **Step 8: Apply to the dummy app and commit**

```bash
cd test/dummy && bin/rails db:migrate && cd ../..
git add lib/plutonium/interaction/runs/configuration.rb db/migrate/interaction_runs lib/plutonium/railtie.rb lib/plutonium/configuration.rb test/plutonium/interaction/runs/configuration_test.rb
git commit -m "feat(runs): table, config and migration registration for interaction runs"
```

---

### Task 2: The Run model

**Goal:** `Plutonium::Interaction::Run` — STI base with state transitions, progress accounting, and typed access to options.

**Files:**
- Create: `lib/plutonium/interaction/run.rb`
- Test: `test/plutonium/interaction/run_test.rb`

**Acceptance Criteria:**
- [ ] `start!` / `finish!` / `fail!` move `state` and stamp `started_at` / `finished_at`
- [ ] `progress_fraction` returns nil when `progress_total` is nil (opaque work)
- [ ] `options` round-trips through JSON with symbol access
- [ ] `record_target_failure!` appends to `errors_log` without losing prior entries
- [ ] `targeted?` is true only when the subclass responds to `perform_on`

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/run_test.rb` → 0 failures

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/interaction/run_test.rb
require "test_helper"

class TestArchiveRun < Plutonium::Interaction::Run
  def perform_on(record) = record
end

class TestOpaqueRun < Plutonium::Interaction::Run
  def perform = :done
end

class Plutonium::Interaction::RunTest < ActiveSupport::TestCase
  def build(klass = TestArchiveRun, **attrs)
    klass.new(initiator_type: "User", initiator_id: "1", **attrs)
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

  test "targeted? reflects what the subclass implements" do
    assert build(TestArchiveRun).targeted?
    refute build(TestOpaqueRun).targeted?
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/run_test.rb`
Expected: FAIL — `uninitialized constant Plutonium::Interaction::Run`

- [ ] **Step 3: Implement the model**

```ruby
# lib/plutonium/interaction/run.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    # A persisted interaction run.
    #
    # STI base: authors subclass to define execution and failure policy, and the
    # subclass name lands in `type`. Options are JSON, so an async action costs
    # no migration.
    #
    # This class deliberately holds NO execution logic — see Runs::Executor. It
    # is the record; the executor is the behaviour. Keeping them apart is what
    # lets the job rebuild an authorization context around the work (Runs::Context)
    # without the model knowing anything about policies.
    class Run < ActiveRecord::Base
      self.table_name = "plutonium_interaction_runs"

      STATES = %w[pending running completed failed].freeze

      belongs_to :initiator, polymorphic: true
      belongs_to :scoped_entity, polymorphic: true, optional: true

      validates :state, inclusion: {in: STATES}
      # Required, not optional: a nullable initiator would drift into meaning
      # "unscoped", which is exactly the fail-open case this design guards.
      validates :initiator_type, :initiator_id, presence: true

      scope :in_progress, -> { where(state: %w[pending running]) }
      scope :for_target, ->(klass) { where(target_type: klass.to_s) }

      def start!
        update!(state: "running", started_at: Time.current)
      end

      def finish!
        update!(state: "completed", finished_at: Time.current)
      end

      def fail!(message = nil)
        record_target_failure!(id: nil, message: message) if message
        update!(state: "failed", finished_at: Time.current)
      end

      def in_progress? = %w[pending running].include?(state)

      # nil means INDETERMINATE, not zero: opaque work has no denominator, and
      # the progress UI renders a spinner rather than a 0% bar.
      def progress_fraction
        return nil if progress_total.nil? || progress_total.zero?

        progress_done.to_f / progress_total
      end

      def record_target_failure!(id:, message:)
        self.errors_log = errors_log + [{"target_id" => id, "message" => message}]
      end

      # Which shape of work this is, decided by what the subclass implements
      # rather than a mode flag — one less thing for an author to keep in sync.
      def targeted? = respond_to?(:perform_on)

      # Failure policy, overridden by subclasses via `on_failure`.
      def self.on_failure(policy)
        @failure_policy = policy
      end

      def self.failure_policy = @failure_policy || :halt

      def failure_policy = self.class.failure_policy
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/run_test.rb`
Expected: PASS, 5 runs 0 failures

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/interaction/run.rb test/plutonium/interaction/run_test.rb
git commit -m "feat(runs): Run model with state, progress and failure-policy hooks"
```

---

### Task 3: Authorization context and target resolution

**Goal:** Rebuild `(initiator, scoped_entity)` inside a job and resolve targets through the policy scope, so authorization survives leaving the request.

**This is the security core of the feature.** Both failure modes here fail *open*.

**Files:**
- Create: `lib/plutonium/interaction/runs/context.rb`
- Test: `test/plutonium/interaction/runs/context_test.rb`

**Acceptance Criteria:**
- [ ] Targets resolve through the target resource's policy scope for the stored initiator
- [ ] A target outside the stored `scoped_entity` is NOT returned
- [ ] A target whose id no longer exists is reported as missing, not silently dropped
- [ ] Resolution is a single query, not one per id

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/context_test.rb` → 0 failures

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/interaction/runs/context_test.rb
require "test_helper"

class Plutonium::Interaction::Runs::ContextTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    @org = create_organization!
    @other_org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)

    @mine = create_post!(user: @user, organization: @org)
    @theirs = create_post!(user: @user, organization: @other_org)
  end

  def run_for(ids)
    TestPostRun.new(
      initiator: @user,
      scoped_entity: @org,
      target_type: "Blogging::Post",
      target_ids: ids
    )
  end

  test "resolves targets inside the stored entity scope" do
    resolved = Plutonium::Interaction::Runs::Context.new(run_for([@mine.id])).targets
    assert_equal [@mine.id], resolved.records.map(&:id)
    assert_empty resolved.missing_ids
  end

  test "a target in another tenant is not returned" do
    resolved = Plutonium::Interaction::Runs::Context.new(run_for([@theirs.id])).targets
    assert_empty resolved.records,
      "a run must never reach outside the entity it was dispatched in"
    assert_equal [@theirs.id], resolved.missing_ids
  end

  test "a vanished target is reported, not silently dropped" do
    resolved = Plutonium::Interaction::Runs::Context.new(run_for([@mine.id, 999_999])).targets
    assert_equal [@mine.id], resolved.records.map(&:id)
    assert_equal [999_999], resolved.missing_ids
  end

  test "resolution is one query regardless of target count" do
    ids = [@mine.id] * 25
    queries = 0
    counter = ->(*, payload) { queries += 1 unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
      Plutonium::Interaction::Runs::Context.new(run_for(ids)).targets
    end
    assert_operator queries, :<=, 2, "targets must resolve in a single scoped query"
  end
end
```

- [ ] **Step 2: Add the dummy run subclass the test needs**

```ruby
# test/dummy/app/runs/test_post_run.rb
class TestPostRun < Plutonium::Interaction::Run
  def perform_on(post) = post.touch
end
```

- [ ] **Step 3: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/context_test.rb`
Expected: FAIL — `uninitialized constant Plutonium::Interaction::Runs::Context`

- [ ] **Step 4: Implement the context**

```ruby
# lib/plutonium/interaction/runs/context.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # Rebuilds the authorization context a run was dispatched under, and
      # resolves its targets through that context.
      #
      # ## Why this exists
      #
      # `perform` runs in a job: there is no controller, no `current_user`, no
      # request. Plutonium authorizes on the PAIR (user, entity_scope) —
      # Core::Controllers::Authorizable registers
      # `authorize :entity_scope, through: :entity_scope_for_authorize`. Rebuilding
      # only the user would resolve targets under the wrong tenant, and that
      # fails OPEN: a broader scope silently includes records the initiator could
      # not see when they dispatched.
      #
      # Authorization is therefore re-derived HERE, at perform time, and never
      # trusted from dispatch. Access revoked between enqueue and run stops the
      # work — otherwise a persisted run becomes a way to launder stale
      # permissions.
      class Context
        # Resolved targets, plus the ids that did not come back.
        #
        # `missing_ids` is deliberately surfaced rather than swallowed: a target
        # that vanished or fell out of scope is information the operator needs.
        # Silence there is how bulk operations quietly under-apply.
        Targets = Struct.new(:records, :missing_ids, keyword_init: true)

        def initialize(run)
          @run = run
        end

        attr_reader :run

        def initiator = run.initiator

        def scoped_entity = run.scoped_entity

        # One scoped query, never N locates. `policy_scope` composes the
        # resource's `relation_scope` with the rebuilt context, so authorization
        # is enforced by construction rather than checked afterwards — which is
        # also why ids beat GlobalIDs here: GlobalID::Locator bypasses the scope
        # entirely.
        def targets
          return Targets.new(records: [], missing_ids: []) if run.target_type.blank?

          ids = Array(run.target_ids)
          records = authorized_scope.where(id: ids).to_a
          found = records.map { |r| r.id.to_s }

          Targets.new(records: records, missing_ids: ids.reject { |id| found.include?(id.to_s) })
        end

        def target_class = run.target_type.constantize

        private

        def authorized_scope
          policy_class = Plutonium::Resource::Policy.infer_policy_class(target_class)
          policy_class.new(
            target_class,
            user: initiator,
            entity_scope: scoped_entity
          ).relation_scope(target_class.all)
        end
      end
    end
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/context_test.rb`
Expected: PASS, 4 runs 0 failures

If `infer_policy_class` does not exist under that name, find the codebase's existing policy-inference entry point (`grep -rn "def.*policy_class" lib/plutonium/`) and use it — do not introduce a second inference path.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/interaction/runs/context.rb test/plutonium/interaction/runs/context_test.rb test/dummy/app/runs/test_post_run.rb
git commit -m "feat(runs): rebuild the (initiator, scoped_entity) context and resolve targets through the policy scope"
```

---

### Task 4: Executor and failure policies

**Goal:** Run the work, honour `on_failure`, and keep progress current.

**Files:**
- Create: `lib/plutonium/interaction/runs/executor.rb`
- Create: `lib/plutonium/interaction/runs/job.rb`
- Test: `test/plutonium/interaction/runs/executor_test.rb`

**Acceptance Criteria:**
- [ ] `on_failure :continue` records the failure and processes remaining targets
- [ ] `on_failure :halt` stops at the first error and marks the run failed
- [ ] `on_failure :transactional` rolls every target back on any error
- [ ] Missing targets are recorded as per-target failures (not skipped)
- [ ] `progress_done` advances as targets complete
- [ ] An opaque run calls `perform` once and needs no targets

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/executor_test.rb` → 0 failures

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/interaction/runs/executor_test.rb
require "test_helper"

class ContinueRun < Plutonium::Interaction::Run
  on_failure :continue
  def perform_on(post)
    raise "boom" if post.title.include?("bad")
    post.touch
  end
end

class HaltRun < Plutonium::Interaction::Run
  on_failure :halt
  def perform_on(post) = raise("boom")
end

class OpaqueOkRun < Plutonium::Interaction::Run
  cattr_accessor :ran
  def perform = self.class.ran = true
end

class Plutonium::Interaction::Runs::ExecutorTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @good = create_post!(user: @user, organization: @org, title: "good one")
    @bad = create_post!(user: @user, organization: @org, title: "bad one")
  end

  def run!(klass, ids)
    run = klass.create!(
      initiator: @user, scoped_entity: @org,
      target_type: "Blogging::Post", target_ids: ids,
      progress_total: ids.size
    )
    Plutonium::Interaction::Runs::Executor.new(run).call
    run.reload
  end

  test "continue records the failure and keeps going" do
    run = run!(ContinueRun, [@bad.id, @good.id])
    assert_equal "completed", run.state
    assert_equal 1, run.errors_log.size
    assert_equal 2, run.progress_done
  end

  test "halt stops at the first error" do
    run = run!(HaltRun, [@bad.id, @good.id])
    assert_equal "failed", run.state
    assert_equal 1, run.errors_log.size
  end

  test "a missing target is recorded, not skipped" do
    run = run!(ContinueRun, [@good.id, 999_999])
    assert_equal 1, run.errors_log.size
    assert_match(/no longer available/i, run.errors_log.first["message"])
  end

  test "an opaque run performs once" do
    OpaqueOkRun.ran = false
    run = OpaqueOkRun.create!(initiator: @user, scoped_entity: @org)
    Plutonium::Interaction::Runs::Executor.new(run).call
    assert OpaqueOkRun.ran
    assert_equal "completed", run.reload.state
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/executor_test.rb`
Expected: FAIL — `uninitialized constant Plutonium::Interaction::Runs::Executor`

- [ ] **Step 3: Implement the executor**

```ruby
# lib/plutonium/interaction/runs/executor.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # Runs a run. Separate from the model so the record stays a record, and
      # separate from the job so it can be driven synchronously in tests.
      class Executor
        def initialize(run)
          @run = run
          @context = Context.new(run)
        end

        attr_reader :run, :context

        def call
          run.start!
          run.targeted? ? perform_targets : perform_opaque
        rescue => e
          run.fail!(e.message)
        end

        private

        def perform_opaque
          run.perform
          run.finish!
        end

        def perform_targets
          resolved = context.targets

          # Recorded, never skipped: "3 targets were no longer available" is
          # what tells an operator the run under-applied.
          resolved.missing_ids.each do |id|
            run.record_target_failure!(id: id, message: "Target #{id} was no longer available")
          end

          if run.failure_policy == :transactional
            run.class.transaction { resolved.records.each { |record| perform_one(record, reraise: true) } }
          else
            resolved.records.each do |record|
              break if perform_one(record) == :halt
            end
          end

          run.errors_log.any? && run.failure_policy == :halt ? run.fail! : run.finish!
        end

        # @return [Symbol, nil] :halt when the policy says to stop
        def perform_one(record, reraise: false)
          run.perform_on(record)
          run.progress_done += 1
          run.save!
          nil
        rescue => e
          raise e if reraise

          run.record_target_failure!(id: record.id, message: e.message)
          run.progress_done += 1
          run.save!
          (run.failure_policy == :halt) ? :halt : nil
        end
      end
    end
  end
end
```

- [ ] **Step 4: Add the job**

```ruby
# lib/plutonium/interaction/runs/job.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # The only thing that crosses the process boundary is the run's id. Every
      # scrap of context — who, which tenant, which targets — is re-read from the
      # row, so nothing is inherited from the dispatching request.
      class Job < ActiveJob::Base
        def perform(run_id)
          run = Plutonium::Interaction::Run.find_by(id: run_id)
          return if run.nil? || !run.in_progress?

          Executor.new(run).call
        end
      end
    end
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/executor_test.rb`
Expected: PASS, 4 runs 0 failures

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/interaction/runs/executor.rb lib/plutonium/interaction/runs/job.rb test/plutonium/interaction/runs/executor_test.rb
git commit -m "feat(runs): executor with continue/halt/transactional failure policies"
```

---

### Task 5: Interactions dispatch

**Goal:** `dispatches_to` turns an interaction into a dispatcher — it creates the run, enqueues it, and redirects.

**Files:**
- Create: `lib/plutonium/interaction/concerns/dispatchable.rb`
- Modify: `lib/plutonium/interaction/base.rb` (include the concern)
- Test: `test/plutonium/interaction/dispatchable_test.rb`

**Acceptance Criteria:**
- [ ] `dispatches_to SomeRun` makes `execute` create and enqueue a run
- [ ] The interaction's validated attributes land in `options`
- [ ] `initiator` and `scoped_entity` are taken from the interaction's context
- [ ] The outcome is a success whose response redirects to the run
- [ ] Validation failure enqueues nothing

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/dispatchable_test.rb` → 0 failures

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/interaction/dispatchable_test.rb
require "test_helper"

class DispatchDemoInteraction < Plutonium::Resource::Interaction
  dispatches_to TestPostRun
  attribute :notify_users, :boolean
  validates :notify_users, inclusion: {in: [true, false]}
end

class Plutonium::Interaction::DispatchableTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @post = create_post!(user: @user, organization: @org)
  end

  test "dispatch creates a run carrying the validated options" do
    outcome = nil
    assert_difference -> { Plutonium::Interaction::Run.count }, 1 do
      outcome = DispatchDemoInteraction.call(
        view_context: nil, notify_users: true,
        initiator: @user, scoped_entity: @org,
        target_type: "Blogging::Post", target_ids: [@post.id]
      )
    end

    assert outcome.success?
    run = Plutonium::Interaction::Run.last
    assert_equal "TestPostRun", run.type
    assert_equal true, run.options["notify_users"]
    assert_equal @user, run.initiator
    assert_equal @org, run.scoped_entity
    assert_equal [@post.id], run.target_ids
  end

  test "an invalid interaction enqueues nothing" do
    assert_no_difference -> { Plutonium::Interaction::Run.count } do
      outcome = DispatchDemoInteraction.call(view_context: nil, notify_users: nil, initiator: @user)
      assert outcome.failure?
    end
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/dispatchable_test.rb`
Expected: FAIL — `undefined method 'dispatches_to'`

- [ ] **Step 3: Implement the concern**

```ruby
# lib/plutonium/interaction/concerns/dispatchable.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    module Concerns
      # Turns an interaction into a dispatcher.
      #
      # The interaction keeps its whole existing job — declare inputs, validate,
      # authorize, render a form — and gains one new behaviour: on execute it
      # persists a run and enqueues it.
      #
      # Note what does NOT change: `call` still returns an Outcome synchronously,
      # because dispatching is what succeeded. That is why Outcome needs no
      # Pending state — the work's completion is the RUN's business, reported on
      # its own page, not this request's.
      module Dispatchable
        extend ActiveSupport::Concern

        class_methods do
          def dispatches_to(run_class)
            @run_class = run_class
          end

          def run_class = @run_class
        end

        included do
          # Dispatch context, supplied by the controller alongside the user's
          # own inputs. Kept as attributes rather than read from a global so the
          # interaction stays callable outside a request (and testable).
          attribute :initiator
          attribute :scoped_entity
          attribute :target_type, :string
          attribute :target_ids, default: -> { [] }
        end

        private

        # Everything the user declared, minus the dispatch plumbing above.
        def dispatch_options
          except = %w[initiator scoped_entity target_type target_ids]
          attributes.except(*except)
        end

        def dispatch!
          run = self.class.run_class.create!(
            initiator: initiator,
            scoped_entity: scoped_entity,
            target_type: target_type,
            target_ids: Array(target_ids),
            progress_total: Array(target_ids).presence&.size,
            options: dispatch_options
          )
          Plutonium::Interaction::Runs::Job
            .set(queue: Plutonium.configuration.interaction_runs.queue)
            .perform_later(run.id)
          run
        end

        def execute
          run = dispatch!
          succeed(run).with_redirect_response(run)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Include it**

In `lib/plutonium/interaction/base.rb`, alongside the other includes in the class body:

```ruby
      include Plutonium::Interaction::Concerns::Dispatchable
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/dispatchable_test.rb`
Expected: PASS, 2 runs 0 failures

If `with_redirect_response` is not the codebase's helper name, check `lib/plutonium/interaction/outcome.rb` for the actual redirect helper and use it — do not add a second one.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/interaction/concerns/dispatchable.rb lib/plutonium/interaction/base.rb test/plutonium/interaction/dispatchable_test.rb
git commit -m "feat(runs): dispatches_to — interactions enqueue a run and redirect to it"
```

---

### Task 6: The run as a resource, and its progress page

**Goal:** A portal can register runs; the show page is the progress page and refreshes itself.

**Files:**
- Create: `lib/plutonium/interaction/runs/definition.rb`
- Create: `lib/plutonium/interaction/runs/policy.rb`
- Create: `lib/plutonium/ui/interaction/run_progress.rb`
- Test: `test/plutonium/interaction/runs/policy_test.rb`
- Test: `test/integration/admin_portal/interaction_run_progress_test.rb`

**Acceptance Criteria:**
- [ ] `relation_scope` returns only runs in the current entity scope
- [ ] A user cannot see another tenant's run
- [ ] The show page renders state, progress and any recorded failures
- [ ] While in progress the page carries a self-refreshing turbo-frame; when finished it does not
- [ ] Progress renders as a spinner (not 0%) when `progress_total` is nil

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/policy_test.rb test/integration/admin_portal/interaction_run_progress_test.rb` → 0 failures

**Steps:**

- [ ] **Step 1: Write the failing policy test**

```ruby
# test/plutonium/interaction/runs/policy_test.rb
require "test_helper"

class Plutonium::Interaction::Runs::PolicyTest < ActiveSupport::TestCase
  include IntegrationTestHelper

  setup do
    @org = create_organization!
    @other = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)

    @mine = TestPostRun.create!(initiator: @user, scoped_entity: @org)
    @theirs = TestPostRun.create!(initiator: @user, scoped_entity: @other)
  end

  test "a run is visible only inside its own entity scope" do
    scope = Plutonium::Interaction::Runs::Policy
      .new(Plutonium::Interaction::Run, user: @user, entity_scope: @org)
      .relation_scope(Plutonium::Interaction::Run.all)

    assert_includes scope, @mine
    refute_includes scope, @theirs,
      "a run from another tenant must never be listed"
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/policy_test.rb`
Expected: FAIL — `uninitialized constant Plutonium::Interaction::Runs::Policy`

- [ ] **Step 3: Implement the policy**

```ruby
# lib/plutonium/interaction/runs/policy.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      # Runs are read-only to users: they are a record of something that
      # happened, so there is no create/update/destroy surface. Visibility is
      # scoped by the entity the run was dispatched in — the same boundary the
      # work itself respected.
      class Policy < Plutonium::Resource::Policy
        def index? = true

        def show? = true

        def create? = false

        def update? = false

        def destroy? = false

        def relation_scope(relation)
          scope = super
          return scope unless entity_scope

          scope.where(scoped_entity_type: entity_scope.class.name, scoped_entity_id: entity_scope.id.to_s)
        end

        def permitted_attributes_for_read
          %i[type state progress_done progress_total started_at finished_at initiator]
        end
      end
    end
  end
end
```

- [ ] **Step 4: Implement the definition**

```ruby
# lib/plutonium/interaction/runs/definition.rb
# frozen_string_literal: true

module Plutonium
  module Interaction
    module Runs
      class Definition < Plutonium::Resource::Definition
        field :type, as: :string
        field :state, as: :string
        field :started_at, as: :datetime
        field :finished_at, as: :datetime

        display :state, as: :badge

        column :type
        column :state
        column :started_at
      end
    end
  end
end
```

- [ ] **Step 5: Implement the progress panel**

```ruby
# lib/plutonium/ui/interaction/run_progress.rb
# frozen_string_literal: true

module Plutonium
  module UI
    module Interaction
      # The progress panel on a run's show page.
      #
      # Polls by default: a turbo-frame with a refresh interval needs no
      # ActionCable, so this works on any deployment. A run may opt into
      # realtime and reuse Kanban::Broadcaster, whose stream names are already
      # keyed on both resource_class AND scoped_entity so tenants can never
      # share a stream.
      #
      # The frame only refreshes WHILE the run is in progress — a finished run
      # is a static record, and leaving the poll running would be a background
      # request per viewer forever.
      class RunProgress < Plutonium::UI::Component::Base
        def initialize(run) = @run = run

        attr_reader :run

        def view_template
          turbo_frame_tag(dom_id(run), **frame_options) do
            div(class: "space-y-3") do
              render_state
              render_progress
              render_failures if run.errors_log.any?
            end
          end
        end

        private

        def frame_options
          return {} unless run.in_progress?

          {src: resource_url_for(run), loading: :lazy, data: {turbo_poll_interval: 2000}}
        end

        def render_state
          div(class: "text-sm font-medium") { plain run.state.humanize }
        end

        def render_progress
          fraction = run.progress_fraction
          if fraction.nil?
            # Indeterminate: opaque work has no denominator, and a 0% bar would
            # read as "nothing has happened" rather than "unknown".
            div(class: "text-xs text-[var(--pu-text-muted)]") { plain "Working…" }
          else
            div(class: "w-full h-2 rounded bg-[var(--pu-surface-alt)]") do
              div(class: "h-2 rounded bg-primary-600", style: "width: #{(fraction * 100).round}%")
            end
            div(class: "text-xs text-[var(--pu-text-muted)]") { plain "#{run.progress_done} of #{run.progress_total}" }
          end
        end

        def render_failures
          ul(class: "text-xs text-danger-600 space-y-1") do
            run.errors_log.each { |entry| li { plain entry["message"] } }
          end
        end
      end
    end
  end
end
```

- [ ] **Step 6: Write the integration test**

```ruby
# test/integration/admin_portal/interaction_run_progress_test.rb
require "test_helper"

class AdminPortal::InteractionRunProgressTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @org = create_organization!
    @user = create_user!
  end

  test "an in-progress run polls; a finished one does not" do
    run = TestPostRun.create!(initiator: @user, scoped_entity: @org, state: "running",
      progress_total: 4, progress_done: 1)

    get "/admin/interaction_runs/#{run.id}"
    assert_response :success
    assert_match(/turbo-poll-interval/, response.body,
      "an in-progress run must refresh itself")

    run.finish!
    get "/admin/interaction_runs/#{run.id}"
    refute_match(/turbo-poll-interval/, response.body,
      "a finished run is static; polling forever is a request per viewer")
  end
end
```

- [ ] **Step 7: Register the resource in the dummy admin portal**

In `test/dummy/packages/admin_portal/config/routes.rb`, beside the other `register_resource` calls:

```ruby
  register_resource ::Plutonium::Interaction::Run
```

- [ ] **Step 8: Run both tests to verify they pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction/runs/policy_test.rb test/integration/admin_portal/interaction_run_progress_test.rb`
Expected: PASS, 0 failures

- [ ] **Step 9: Commit**

```bash
git add lib/plutonium/interaction/runs/definition.rb lib/plutonium/interaction/runs/policy.rb lib/plutonium/ui/interaction/run_progress.rb test/plutonium/interaction/runs/policy_test.rb test/integration/admin_portal/interaction_run_progress_test.rb test/dummy/packages/admin_portal/config/routes.rb
git commit -m "feat(runs): run as a resource, with a self-refreshing progress page"
```

---

### Task 7: In-progress runs on the target index

**Goal:** A resource's index lists runs currently working on it, at the top.

**Files:**
- Create: `lib/plutonium/ui/interaction/running_banner.rb`
- Modify: `lib/plutonium/ui/page/index.rb` (render the banner above the collection)
- Test: `test/integration/admin_portal/interaction_run_banner_test.rb`

**Acceptance Criteria:**
- [ ] The index shows a banner listing in-progress runs whose `target_type` is this resource
- [ ] Completed runs do not appear
- [ ] Runs targeting a different resource do not appear
- [ ] Another tenant's run does not appear
- [ ] No banner renders when there are none (no empty chrome)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/interaction_run_banner_test.rb` → 0 failures

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/integration/admin_portal/interaction_run_banner_test.rb
require "test_helper"

class AdminPortal::InteractionRunBannerTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper

  setup do
    @admin = create_admin!
    login_as_admin(@admin)
    @user = create_user!
  end

  test "the index lists in-progress runs for this resource only" do
    running = TestPostRun.create!(initiator: @user, target_type: "Blogging::Post", state: "running")
    done = TestPostRun.create!(initiator: @user, target_type: "Blogging::Post", state: "completed")
    other = TestPostRun.create!(initiator: @user, target_type: "Catalog::Product", state: "running")

    get "/admin/blogging/posts"
    assert_response :success

    assert_match(/pu-running-banner/, response.body)
    assert_match(/data-run-id="#{running.id}"/, response.body)
    refute_match(/data-run-id="#{done.id}"/, response.body, "a finished run is not in progress")
    refute_match(/data-run-id="#{other.id}"/, response.body, "that run targets another resource")
  end

  test "no banner renders when nothing is running" do
    get "/admin/blogging/posts"
    assert_response :success
    refute_match(/pu-running-banner/, response.body, "an empty banner is chrome for nothing")
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/interaction_run_banner_test.rb`
Expected: FAIL — no `pu-running-banner` in the body

- [ ] **Step 3: Implement the banner**

```ruby
# lib/plutonium/ui/interaction/running_banner.rb
# frozen_string_literal: true

module Plutonium
  module UI
    module Interaction
      # Lists runs currently working on THIS resource, above its collection.
      #
      # Queried on target_type — which is why that is a real column rather than
      # a key inside the options JSON: this predicate has to be indexable.
      #
      # Renders nothing when there is nothing running. An always-present empty
      # banner is chrome that teaches the user to ignore the area.
      class RunningBanner < Plutonium::UI::Component::Base
        def initialize(resource_class:, runs:)
          @resource_class = resource_class
          @runs = runs
        end

        attr_reader :resource_class, :runs

        def view_template
          return if runs.empty?

          div(class: "pu-running-banner mb-3 rounded-[var(--pu-radius-md)] border border-[var(--pu-border)] bg-[var(--pu-surface-alt)] p-3 space-y-2") do
            runs.each { |run| render_run(run) }
          end
        end

        private

        def render_run(run)
          div(class: "flex items-center justify-between gap-3 text-sm", data: {run_id: run.id}) do
            span { plain "#{run.type.titleize} — #{run.state}" }
            a(href: resource_url_for(run), class: "pu-btn pu-btn-xs pu-btn-soft-primary") { plain "View progress" }
          end
        end
      end
    end
  end
end
```

- [ ] **Step 4: Render it from the index page**

In `lib/plutonium/ui/page/index.rb`, immediately above where the collection renders:

```ruby
          if Plutonium.configuration.interaction_runs.enabled
            render Plutonium::UI::Interaction::RunningBanner.new(
              resource_class: resource_class,
              runs: current_authorized_scope_for(Plutonium::Interaction::Run)
                .for_target(resource_class).in_progress.to_a
            )
          end
```

Use the index page's existing authorized-scope helper — `grep -n "authorized_scope" lib/plutonium/ui/page/index.rb` — so the banner is scoped exactly as the collection is, and a run from another tenant can never appear.

- [ ] **Step 5: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/interaction_run_banner_test.rb`
Expected: PASS, 2 runs 0 failures

- [ ] **Step 6: Run the full suite and commit**

```bash
bundle exec appraisal rails-8.1 rake test
bundle exec standardrb
git add lib/plutonium/ui/interaction/running_banner.rb lib/plutonium/ui/page/index.rb test/integration/admin_portal/interaction_run_banner_test.rb
git commit -m "feat(runs): list in-progress runs above a resource's collection"
```

---

## Deliberately deferred

**Opt-in realtime broadcast.** The spec offers it alongside polling; this plan
ships polling only. Polling satisfies the requirement on every deployment,
broadcast is an optimisation, and adding it now would put an ActionCable path
into a subsystem whose authorization story is the risky part. When it is wanted,
it is additive: `Kanban::Broadcaster` already builds tenant-safe stream names
from `(resource_class, scoped_entity)`, and `RunProgress` already branches on
`run.in_progress?` — the broadcast case slots into that branch.

The spec's own out-of-scope list (scheduling, approvals, retries, import/export
run types, sweeping) stands unchanged.

## Final verification

```bash
bundle exec appraisal rake test      # all three Rails versions
bundle exec standardrb
```

Expected: 0 failures across rails-7, rails-8.0 and rails-8.1; standardrb clean.
