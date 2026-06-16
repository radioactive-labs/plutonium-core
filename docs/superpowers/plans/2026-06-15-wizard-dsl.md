# Wizard DSL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `Plutonium::Wizard` subsystem — a declarative, DB-backed, multi-step data-capture wizard — per `docs/superpowers/specs/2026-06-15-wizard-dsl-design.md`.

**Architecture:** A self-contained data-capture wizard. A wizard class declares ordered `step`s (own fields, or `using:` an interaction/definition), branches via `condition:`, stages typed `data` in one framework table (`plutonium_wizard_sessions`), and commits at the end via `execute` (or per-step `on_submit`/`persist`/`on_rollback`). A single controller drives all surfaces (record action, collection, standalone, one-time); identity is a derived `instance_key` digest; cleanup is TTL-swept.

**Tech Stack:** Ruby, Rails (7.2/8.0/8.1 via Appraisal), ActiveModel::Attributes, Phlex (Phlexi forms/display), Stimulus, Minitest. Reuses `Plutonium::Interaction`, `Plutonium::Definition` (DefineableProps/FormLayout/StructuredInputs), `Plutonium::Action`, `Plutonium::Routing`, `Plutonium::UI`.

**User Verification:** NO — the originating request ("explore a DSL for creating wizards") requires no human-in-the-loop validation of outcomes; correctness is verified by the test suite.

**Spec reference:** `docs/superpowers/specs/2026-06-15-wizard-dsl-design.md` — section numbers (§N) below point into it. Read it before starting.

**Conventions for every task:** TDD (write failing test → run red → implement → run green → commit). Run a focused test with `bundle exec appraisal rails-8.1 ruby -Itest <file>`; run the suite with `bundle exec appraisal rails-8.1 rake test`. Use `with_connection` for DB access; bang methods (`create!`) in examples; register Stimulus controllers; inline indexes in `create_table`.

---

## File Structure

```
lib/plutonium/wizard.rb                         # namespace + autoloads + error classes
lib/plutonium/wizard/errors.rb                  # NotAnchoredError, StepError
lib/plutonium/wizard/configuration.rb           # WizardConfiguration (enabled/cleanup_after/database)
lib/plutonium/migrations.rb                     # per-feature migration-path registry
db/migrate/wizard/<ts>_create_plutonium_wizard_sessions.rb
app/models/plutonium/wizard/session.rb          # AR model (polymorphic owner/anchor/scope, instance_key, json, encrypts)
lib/plutonium/wizard/state.rb                   # value object: wizard, current_step, data, persisted, owner/anchor/scope/token
lib/plutonium/wizard/instance_key.rb            # digest recipe
lib/plutonium/wizard/store/base.rb              # port
lib/plutonium/wizard/store/active_record.rb     # shipped store
lib/plutonium/wizard/store/memory.rb            # test store
lib/plutonium/wizard/step.rb                    # step metadata value object
lib/plutonium/wizard/review_step.rb             # terminal review step
lib/plutonium/wizard/data.rb                    # typed, dot-accessible snapshot builder
lib/plutonium/wizard/field_importer.rb          # resolves using: (interaction/definition)
lib/plutonium/wizard/dsl.rb                     # step/review/anchored/navigation/cleanup_after/one_time/encrypt_data macros
lib/plutonium/wizard/base.rb                    # author class
lib/plutonium/wizard/runner.rb                  # path computation, validation, on_submit/execute, completeness/prune, lock, cleanup
lib/plutonium/wizard/sweep_job.rb              # abandonment sweep
lib/plutonium/wizard/gate.rb                    # ensure_wizard_completed controller concern
lib/plutonium/definition/wizards.rb             # `wizard` DSL macro (mixed into Definition::Base)
lib/plutonium/routing/wizard_registration.rb    # register_wizard + per-resource wizard routes
app/controllers/plutonium/wizard/controller.rb  # single controller mixin
lib/plutonium/ui/page/wizard.rb                 # page class
lib/plutonium/ui/wizard/stepper.rb              # stepper component
lib/plutonium/ui/wizard/review.rb               # review auto-summary component
test/plutonium/wizard/*_test.rb                 # unit tests (Memory store)
test/integration/.../wizard_*_test.rb           # dummy-app integration tests
.claude/skills/plutonium-wizard/SKILL.md        # skill
docs/guides/wizards.md + docs/reference/wizard/*.md
```

Each task below is a coherent, committable unit. TDD cycles happen inside a task.

---

### Task 0: Namespace, errors, configuration, migrations registry

**Goal:** The plumbing every later task depends on — namespace + autoloading, error classes, namespaced `config.wizards`, and the per-feature migration registry + Railtie hook (no table yet).

**Files:**
- Create: `lib/plutonium/wizard.rb`, `lib/plutonium/wizard/errors.rb`, `lib/plutonium/wizard/configuration.rb`, `lib/plutonium/migrations.rb`
- Modify: `lib/plutonium/configuration.rb` (add `wizards` nested config), `lib/plutonium/railtie.rb` (migrations initializer), `lib/plutonium.rb` (require wizard namespace if not zeitwerk-autoloaded)
- Test: `test/plutonium/wizard/configuration_test.rb`, `test/plutonium/migrations_test.rb`

**Acceptance Criteria:**
- [ ] `Plutonium.configuration.wizards.enabled` defaults to `false`; `.cleanup_after` defaults to `30.days`; `.database` defaults to `:primary`.
- [ ] `Plutonium::Wizard::NotAnchoredError` and `Plutonium::Wizard::StepError` exist (both `< StandardError`).
- [ ] `Plutonium::Migrations.register(:wizard, path)` + `Plutonium::Migrations.enabled_paths` returns the wizard path only when `config.wizards.enabled`.
- [ ] The Railtie initializer is declared `after: :load_config_initializers`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/configuration_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test — config defaults + migrations gating**

```ruby
# test/plutonium/wizard/configuration_test.rb
require "test_helper"

class Plutonium::Wizard::ConfigurationTest < Minitest::Test
  def setup
    @config = Plutonium::Wizard::Configuration.new
  end

  def test_defaults
    refute @config.enabled
    assert_equal 30.days, @config.cleanup_after
    assert_equal :primary, @config.database
  end

  def test_error_classes
    assert Plutonium::Wizard::NotAnchoredError < StandardError
    assert Plutonium::Wizard::StepError < StandardError
  end
end
```

```ruby
# test/plutonium/migrations_test.rb
require "test_helper"

class Plutonium::MigrationsTest < Minitest::Test
  def setup
    Plutonium::Migrations.reset!
    Plutonium::Migrations.register(:wizard, "/gem/db/migrate/wizard")
  end

  def test_enabled_paths_gated_by_config
    Plutonium.configuration.wizards.enabled = false
    assert_empty Plutonium::Migrations.enabled_paths
    Plutonium.configuration.wizards.enabled = true
    assert_includes Plutonium::Migrations.enabled_paths, "/gem/db/migrate/wizard"
  ensure
    Plutonium.configuration.wizards.enabled = false
  end
end
```

- [ ] **Step 2: Run red** — `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/configuration_test.rb` → FAIL (NameError).

- [ ] **Step 3: Implement errors + namespace**

```ruby
# lib/plutonium/wizard/errors.rb
module Plutonium
  module Wizard
    # Raised by `anchor` on a wizard that was not declared `anchored`.
    class NotAnchoredError < StandardError; end

    # Raise inside on_submit/execute (usually via `fail!`) for a custom,
    # non-ActiveRecord::RecordInvalid step failure. `attribute` defaults to :base.
    class StepError < StandardError
      attr_reader :attribute

      def initialize(message = nil, attribute: :base)
        @attribute = attribute
        super(message)
      end
    end
  end
end
```

```ruby
# lib/plutonium/wizard.rb
module Plutonium
  module Wizard
    # Eager-required; the rest is zeitwerk-autoloaded by the host engine/app.
  end
end
require_relative "wizard/errors"
require_relative "wizard/configuration"
```

- [ ] **Step 4: Implement configuration + wire into Configuration**

```ruby
# lib/plutonium/wizard/configuration.rb
module Plutonium
  module Wizard
    class Configuration
      attr_accessor :enabled, :cleanup_after, :database

      def initialize
        @enabled = false
        @cleanup_after = 30.days
        @database = :primary
      end
    end
  end
end
```

In `lib/plutonium/configuration.rb`, add to the `Configuration` class (mirroring the `@assets` precedent at lines 102-122):

```ruby
attr_reader :wizards

# inside initialize:
@wizards = Plutonium::Wizard::Configuration.new
```

Ensure `require_relative "wizard"` (or the errors/configuration files) loads before `Configuration#initialize` runs.

- [ ] **Step 5: Implement migrations registry**

```ruby
# lib/plutonium/migrations.rb
module Plutonium
  # Registry mapping a feature → its gem-shipped migration directory.
  # The Railtie appends only enabled features' paths (see railtie.rb).
  module Migrations
    @registry = {}

    class << self
      # feature → gem subdir path
      def register(feature, path)
        @registry[feature.to_sym] = path
      end

      def reset! = @registry = {}

      # Paths whose feature flag is enabled. Each feature's flag lives under
      # config.<feature> with an `.enabled` reader.
      def enabled_paths
        @registry.filter_map do |feature, path|
          cfg = Plutonium.configuration.public_send(feature) if Plutonium.configuration.respond_to?(feature)
          path if cfg&.respond_to?(:enabled) && cfg.enabled
        end
      end
    end
  end
end
```

- [ ] **Step 6: Railtie initializer + register the wizard feature**

In `lib/plutonium/railtie.rb` add (per spec §10):

```ruby
require "plutonium/migrations"

initializer "plutonium.register_migrations" do
  Plutonium::Migrations.register(:wizards, Plutonium.root.join("db/migrate/wizard").to_s)
end

# Runs AFTER config/initializers/* so config.wizards.enabled is set (railtie inits run before app inits).
initializer "plutonium.migrations", after: :load_config_initializers do |app|
  Plutonium::Migrations.enabled_paths.each do |path|
    db = Plutonium.configuration.wizards.database
    if db == :primary
      app.config.paths["db/migrate"] << path
    end
    ActiveRecord::Migrator.migrations_paths << path unless
      ActiveRecord::Migrator.migrations_paths.include?(path)
    # Multi-db: also register on the named database's migrations_paths if not primary.
    # (Resolved lazily; see spec §10. For :primary the global path above suffices.)
  end
end
```

> NOTE: the registry keys on the config method name — register under `:wizards` (matching `config.wizards`), not `:wizard`. Update the test's `register(:wizard, ...)` → `register(:wizards, ...)` and the assertion accordingly.

- [ ] **Step 7: Run green** — `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/configuration_test.rb test/plutonium/migrations_test.rb` → PASS

- [ ] **Step 8: Commit**

```bash
git add lib/plutonium/wizard.rb lib/plutonium/wizard/errors.rb lib/plutonium/wizard/configuration.rb lib/plutonium/migrations.rb lib/plutonium/configuration.rb lib/plutonium/railtie.rb test/plutonium/wizard/configuration_test.rb test/plutonium/migrations_test.rb
git commit -m "feat(wizard): namespace, errors, config.wizards, migrations registry"
```

```json:metadata
{"files": ["lib/plutonium/wizard.rb", "lib/plutonium/wizard/errors.rb", "lib/plutonium/wizard/configuration.rb", "lib/plutonium/migrations.rb", "lib/plutonium/configuration.rb", "lib/plutonium/railtie.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/configuration_test.rb test/plutonium/migrations_test.rb", "acceptanceCriteria": ["config.wizards defaults (enabled=false, cleanup_after=30.days, database=:primary)", "NotAnchoredError + StepError exist", "Migrations.enabled_paths gated by config", "railtie initializer after :load_config_initializers"], "requiresUserVerification": false}
```

---

### Task 1: Migration, Session model, instance_key, State, Store (Memory + ActiveRecord)

**Goal:** Persistence layer — the table, the AR model, the identity digest, the `State` value object, and the Store port with both adapters. This is the foundation the runner uses.

**Files:**
- Create: `db/migrate/wizard/20260615000001_create_plutonium_wizard_sessions.rb`, `app/models/plutonium/wizard/session.rb`, `lib/plutonium/wizard/instance_key.rb`, `lib/plutonium/wizard/state.rb`, `lib/plutonium/wizard/store/base.rb`, `lib/plutonium/wizard/store/memory.rb`, `lib/plutonium/wizard/store/active_record.rb`
- Test: `test/plutonium/wizard/instance_key_test.rb`, `test/plutonium/wizard/store/memory_test.rb`, `test/plutonium/wizard/store/active_record_test.rb`

**Acceptance Criteria:**
- [ ] Migration creates `plutonium_wizard_sessions` with all columns/indexes from spec §8.1 (polymorphic owner/anchor/scope, `instance_key` unique, `status`, `current_step`, `data`/`persisted` json, `expires_at`, `completed_at`, timestamps; sweep/listing/once-per indexes).
- [ ] `InstanceKey.for(wizard:, scope:, anchor:, token:, owner:)` == `SHA256("#{wizard}|#{scope_gid}|#{anchor_gid}|#{token.presence || owner_gid}")`, blanks for nils, **owner excluded when token present**.
- [ ] `Store::Memory` and `Store::ActiveRecord` both satisfy the port: `read/write/complete/clear/completed?/in_progress_for` with identical behavior (shared test module).
- [ ] `write` upserts by `instance_key`, sets owner/anchor/scope/token columns and `expires_at = now + cleanup_after`.
- [ ] `complete` sets `status: "completed"`, `completed_at`, nulls `data`/`persisted`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/store/active_record_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test — instance_key recipe**

```ruby
# test/plutonium/wizard/instance_key_test.rb
require "test_helper"

class Plutonium::Wizard::InstanceKeyTest < Minitest::Test
  def key(**kw) = Plutonium::Wizard::InstanceKey.for(**kw)

  def test_token_excludes_owner
    with_token   = key(wizard: "W", scope: nil, anchor: nil, token: "abc", owner: nil)
    after_auth   = key(wizard: "W", scope: nil, anchor: nil, token: "abc", owner: gid("User", 1))
    assert_equal with_token, after_auth, "owner must not change the digest when a token is present"
  end

  def test_owner_principal_without_token
    a = key(wizard: "W", scope: nil, anchor: nil, token: nil, owner: gid("User", 1))
    b = key(wizard: "W", scope: nil, anchor: nil, token: nil, owner: gid("User", 2))
    refute_equal a, b
  end

  def test_scope_distinguishes
    a = key(wizard: "W", scope: gid("Org", 1), anchor: nil, token: nil, owner: gid("User", 1))
    b = key(wizard: "W", scope: gid("Org", 2), anchor: nil, token: nil, owner: gid("User", 1))
    refute_equal a, b
  end

  def gid(type, id) = "gid://dummy/#{type}/#{id}"
end
```

- [ ] **Step 2: Run red** → FAIL.

- [ ] **Step 3: Implement instance_key**

```ruby
# lib/plutonium/wizard/instance_key.rb
require "digest"

module Plutonium
  module Wizard
    module InstanceKey
      # Identity digest. Token is the principal when present (so pre-auth→auth
      # doesn't rekey); otherwise the owner GID is the principal. Scope + anchor
      # always participate when present. Spec §4 / §17.13.
      def self.for(wizard:, scope:, anchor:, token:, owner:)
        principal = token.presence || gid(owner)
        Digest::SHA256.hexdigest([wizard, gid(scope), gid(anchor), principal].map(&:to_s).join("|"))
      end

      def self.gid(obj)
        return obj if obj.nil? || obj.is_a?(String)
        obj.to_global_id.to_s
      end
    end
  end
end
```

- [ ] **Step 4: Run green (instance_key)** → PASS. Commit-worthy checkpoint.

- [ ] **Step 5: Migration** (per spec §8.1 — inline indexes; `jsonb` on PG via `connection.adapter_name`)

```ruby
# db/migrate/wizard/20260615000001_create_plutonium_wizard_sessions.rb
class CreatePlutoniumWizardSessions < ActiveRecord::Migration[7.2]
  def change
    json_type = (connection.adapter_name =~ /postgres/i) ? :jsonb : :json

    create_table :plutonium_wizard_sessions do |t|
      t.string :wizard, null: false
      t.string :status, null: false, default: "in_progress"  # in_progress | completing | completed
      t.string :current_step

      t.string :instance_key, null: false

      t.string :owner_type
      t.string :owner_id
      t.string :anchor_type
      t.string :anchor_id
      t.string :scope_type
      t.string :scope_id
      t.string :token

      t.public_send(json_type, :data, null: false, default: {})
      t.public_send(json_type, :persisted, null: false, default: {})

      t.datetime :expires_at
      t.datetime :completed_at
      t.timestamps

      t.index :instance_key, unique: true
      t.index [:status, :expires_at]
      t.index [:owner_type, :owner_id, :status]
      t.index [:scope_type, :scope_id, :status]
      t.index [:wizard, :anchor_type, :anchor_id, :status]
    end
  end
end
```

Add to a dummy-app/CI setup: ensure the dummy app enables `config.wizards.enabled = true` so the migration runs in the test DB (mirror how other features are toggled in `test/dummy`).

- [ ] **Step 6: Session model**

```ruby
# app/models/plutonium/wizard/session.rb
module Plutonium
  module Wizard
    class Session < ActiveRecord::Base
      self.table_name = "plutonium_wizard_sessions"

      belongs_to :owner, polymorphic: true, optional: true
      belongs_to :anchor, polymorphic: true, optional: true
      belongs_to :scope, polymorphic: true, optional: true

      enum :status, { in_progress: "in_progress", completing: "completing", completed: "completed" },
        prefix: true

      scope :sweepable, ->(now) {
        where(status: %w[in_progress completing]).where.not(expires_at: nil).where(expires_at: ..now)
      }
    end
  end
end
```

> Encryption (`encrypt_data`) is applied conditionally by the wizard class, not statically here — see Task 2/4. The model stays plaintext by default.

- [ ] **Step 7: State value object**

```ruby
# lib/plutonium/wizard/state.rb
module Plutonium
  module Wizard
    # In-memory snapshot of one wizard instance's stored state.
    State = Struct.new(
      :wizard, :instance_key, :current_step, :status,
      :data, :persisted, :owner, :anchor, :scope, :token
    ) do
      def data = super || {}
      def persisted = super || {}
    end
  end
end
```

- [ ] **Step 8: Store port + Memory + ActiveRecord (shared behavior test)**

```ruby
# lib/plutonium/wizard/store/base.rb
module Plutonium
  module Wizard
    module Store
      class Base
        def read(instance_key) = raise NotImplementedError
        def write(instance_key, state, cleanup_after:) = raise NotImplementedError
        def complete(instance_key) = raise NotImplementedError
        def clear(instance_key) = raise NotImplementedError
        def completed?(wizard:, owner: nil, anchor: nil) = raise NotImplementedError
        def in_progress_for(owner) = raise NotImplementedError
      end
    end
  end
end
```

```ruby
# lib/plutonium/wizard/store/active_record.rb
module Plutonium
  module Wizard
    module Store
      class ActiveRecord < Base
        def read(instance_key)
          row = Session.find_by(instance_key:)
          row && to_state(row)
        end

        def write(instance_key, state, cleanup_after:)
          row = Session.find_or_initialize_by(instance_key:)
          row.wizard = state.wizard
          row.current_step = state.current_step
          row.status ||= "in_progress"
          row.data = state.data
          row.persisted = state.persisted
          row.owner = state.owner
          row.anchor = state.anchor
          row.scope = state.scope
          row.token = state.token
          row.expires_at = cleanup_after ? Time.current + cleanup_after : nil
          row.save!
          to_state(row)
        end

        def complete(instance_key)
          row = Session.find_by!(instance_key:)
          row.update!(status: "completed", completed_at: Time.current, data: {}, persisted: {})
        end

        def clear(instance_key) = Session.where(instance_key:).delete_all

        def completed?(wizard:, owner: nil, anchor: nil)
          scope = Session.status_completed.where(wizard: wizard.to_s)
          scope = scope.where(owner:) if owner
          scope = scope.where(anchor:) if anchor
          scope.exists?
        end

        def in_progress_for(owner) = Session.status_in_progress.where(owner:).map { to_state(_1) }

        private

        def to_state(row)
          State.new(
            wizard: row.wizard, instance_key: row.instance_key, current_step: row.current_step,
            status: row.status, data: row.data, persisted: row.persisted,
            owner: row.owner, anchor: row.anchor, scope: row.scope, token: row.token
          )
        end
      end
    end
  end
end
```

```ruby
# lib/plutonium/wizard/store/memory.rb
module Plutonium
  module Wizard
    module Store
      class Memory < Base
        def initialize = @rows = {}
        def read(k) = @rows[k]&.dup
        def write(k, state, cleanup_after:)
          state = state.dup
          state.instance_key = k
          state.status ||= "in_progress"
          @rows[k] = state
        end
        def complete(k)
          s = @rows.fetch(k); s.status = "completed"; s.data = {}; s.persisted = {}; s
        end
        def clear(k) = @rows.delete(k)
        def completed?(wizard:, owner: nil, anchor: nil)
          @rows.values.any? { _1.status == "completed" && _1.wizard == wizard.to_s &&
            (owner.nil? || _1.owner == owner) && (anchor.nil? || _1.anchor == anchor) }
        end
        def in_progress_for(owner) = @rows.values.select { _1.status == "in_progress" && _1.owner == owner }
      end
    end
  end
end
```

```ruby
# test/plutonium/wizard/store/shared.rb  (shared behavior)
module WizardStoreBehavior
  def test_write_then_read_roundtrip
    st = build_state(data: {"a" => 1})
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    got = @store.read(st.instance_key)
    assert_equal({"a" => 1}, got.data)
    assert_equal "in_progress", got.status
  end

  def test_complete_nulls_payload
    st = build_state(data: {"a" => 1})
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    @store.complete(st.instance_key)
    assert_equal "completed", @store.read(st.instance_key).status
    assert_empty @store.read(st.instance_key).data
  end

  def test_completed_query
    st = build_state
    @store.write(st.instance_key, st, cleanup_after: 1.day)
    @store.complete(st.instance_key)
    assert @store.completed?(wizard: "W")
  end

  def build_state(data: {})
    Plutonium::Wizard::State.new(wizard: "W", instance_key: "key-#{data.hash}",
      current_step: "one", data: data, persisted: {})
  end
end
```

```ruby
# test/plutonium/wizard/store/memory_test.rb
require "test_helper"; require_relative "shared"
class Plutonium::Wizard::Store::MemoryTest < Minitest::Test
  include WizardStoreBehavior
  def setup = @store = Plutonium::Wizard::Store::Memory.new
end
```

```ruby
# test/plutonium/wizard/store/active_record_test.rb
require "test_helper"; require_relative "shared"
class Plutonium::Wizard::Store::ActiveRecordTest < ActiveSupport::TestCase
  include WizardStoreBehavior
  setup { @store = Plutonium::Wizard::Store::ActiveRecord.new }
  # NOTE: build_state in shared uses fixed instance_key strings; AR store keys on instance_key column — OK.
end
```

- [ ] **Step 9: Run green** — both store tests + instance_key → PASS.

- [ ] **Step 10: Commit**

```bash
git add db/migrate/wizard app/models/plutonium/wizard/session.rb lib/plutonium/wizard/instance_key.rb lib/plutonium/wizard/state.rb lib/plutonium/wizard/store test/plutonium/wizard/instance_key_test.rb test/plutonium/wizard/store
git commit -m "feat(wizard): sessions table, Session model, instance_key, State, Store (memory + AR)"
```

```json:metadata
{"files": ["db/migrate/wizard/20260615000001_create_plutonium_wizard_sessions.rb", "app/models/plutonium/wizard/session.rb", "lib/plutonium/wizard/instance_key.rb", "lib/plutonium/wizard/state.rb", "lib/plutonium/wizard/store/base.rb", "lib/plutonium/wizard/store/memory.rb", "lib/plutonium/wizard/store/active_record.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/store/active_record_test.rb test/plutonium/wizard/instance_key_test.rb", "acceptanceCriteria": ["table + indexes per spec 8.1", "instance_key recipe (token principal, owner excluded when token present)", "Memory + AR stores satisfy shared behavior", "write upserts + stamps expires_at", "complete nulls payload"], "requiresUserVerification": false}
```

---

### Task 2: Wizard DSL — Base, Step, ReviewStep, typed `data`, anchoring, navigation, cleanup_after, one_time, encrypt_data

**Goal:** The author-facing class. Declaring `step`/`review`/`anchored`/`navigation`/`cleanup_after`/`one_time`/`encrypt_data`/`presents` works; a wizard exposes its ordered steps, union attribute schema, and a typed `data` snapshot; `anchor`/`persisted`/`fail!` accessors behave per spec. (No HTTP/runner yet — pure object behavior.)

**Files:**
- Create: `lib/plutonium/wizard/step.rb`, `lib/plutonium/wizard/review_step.rb`, `lib/plutonium/wizard/data.rb`, `lib/plutonium/wizard/dsl.rb`, `lib/plutonium/wizard/base.rb`
- Test: `test/plutonium/wizard/base_test.rb`, `test/plutonium/wizard/data_test.rb`

**Acceptance Criteria:**
- [ ] `step :k, label:, condition:` registers an ordered `Step`; the step block evaluates `attribute`/`input`/`validates`/`structured_input` into a per-step field surface (reusing `Definition::StructuredInputs::FieldsDefinition`-style capture).
- [ ] `review label:` registers a terminal `ReviewStep`; declaring any step after `review` raises at class-eval time (spec §2.5 terminality).
- [ ] `anchored with: T` / `with: [A, B]` / `anchored` / omit recorded; `anchor` accessor returns the bound record or raises `NotAnchoredError` when not anchored.
- [ ] `navigation` (default `:linear`), `cleanup_after` (default from config), `one_time once_per:`, `encrypt_data` recorded and readable.
- [ ] `data` is an ActiveModel::Attributes-backed snapshot over the **union** of all steps' attributes, cast to declared types, with uncollected fields `nil`; `data.foo` works; structured arrays yield typed sub-objects (`data.invites.first.email`).
- [ ] `fail!("m")` raises `StepError` (base); `fail!(:f, "m")` raises `StepError` with `attribute: :f`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/base_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test — DSL + data typing + anchor**

```ruby
# test/plutonium/wizard/base_test.rb
require "test_helper"

class Plutonium::Wizard::BaseTest < Minitest::Test
  class CreateCo < Plutonium::Wizard::Base
    step :company do
      attribute :name, :string
      attribute :employees, :integer
      input :name
      validates :name, presence: true
    end
    step :plan, condition: -> { data.name.present? } do
      attribute :plan, :string
      input :plan
    end
    review label: "Review"
    def execute = succeed(true)
  end

  def test_steps_ordered_and_terminal_review
    keys = CreateCo.steps.map(&:key)
    assert_equal %i[company plan review], keys
    assert CreateCo.steps.last.review?
  end

  def test_union_attribute_schema_and_typed_data
    w = CreateCo.new
    w.data_attributes = {"name" => "Acme", "employees" => "12"}
    assert_equal "Acme", w.data.name
    assert_equal 12, w.data.employees     # cast to Integer
    assert_nil w.data.plan                # uncollected → nil
  end

  def test_review_must_be_last
    err = assert_raises(ArgumentError) do
      Class.new(Plutonium::Wizard::Base) do
        review label: "R"
        step(:after) { attribute :x, :string }
      end
    end
    assert_match(/review.*last/i, err.message)
  end

  def test_anchor_raises_when_not_anchored
    assert_raises(Plutonium::Wizard::NotAnchoredError) { CreateCo.new.anchor }
  end

  def test_fail_bang
    w = CreateCo.new
    e = assert_raises(Plutonium::Wizard::StepError) { w.send(:fail!, "nope") }
    assert_equal :base, e.attribute
    e2 = assert_raises(Plutonium::Wizard::StepError) { w.send(:fail!, :name, "bad") }
    assert_equal :name, e2.attribute
  end
end
```

- [ ] **Step 2: Run red** → FAIL.

- [ ] **Step 3: Step + ReviewStep value objects**

```ruby
# lib/plutonium/wizard/step.rb
module Plutonium
  module Wizard
    class Step
      attr_reader :key, :label, :condition, :fields, :on_submit, :on_rollback, :using_spec, :form_layout

      def initialize(key:, label: nil, condition: nil, fields:, on_submit: nil,
                     on_rollback: nil, using_spec: nil, form_layout: nil)
        @key = key
        @label = label || key.to_s.humanize
        @condition = condition
        @fields = fields            # FieldsDefinition-like: attributes/inputs/validations/structured
        @on_submit = on_submit
        @on_rollback = on_rollback
        @using_spec = using_spec    # FieldImporter::Spec or nil (Task 3)
        @form_layout = form_layout
      end

      def review? = false
      def attribute_schema = fields.attribute_schema   # { name => type }  (Task 2 fields capture)
    end
  end
end
```

```ruby
# lib/plutonium/wizard/review_step.rb
module Plutonium
  module Wizard
    class ReviewStep < Step
      attr_reader :block
      def initialize(key: :review, label: "Review", condition: nil, block: nil)
        super(key:, label:, condition:, fields: EmptyFields.new)
        @block = block
      end
      def review? = true

      class EmptyFields
        def attribute_schema = {}
      end
    end
  end
end
```

- [ ] **Step 4: Field capture + typed `data`**

The step block is evaluated against a capture object that records `attribute`/`input`/`validates`/`structured_input`. Reuse the existing `Plutonium::Definition::StructuredInputs::FieldsDefinition` shape (it already includes DefineableProps for `field`/`input`); extend a small capture that *also* records `attribute :name, :type` (for the schema) and `validates` (for inline validation). Build it as:

```ruby
# lib/plutonium/wizard/data.rb
module Plutonium
  module Wizard
    # Builds a typed, dot-accessible snapshot class from a union attribute schema
    # ({ name => type }). Backed by ActiveModel::Attributes so values are cast.
    module Data
      def self.class_for(schema)
        Class.new do
          include ActiveModel::Model
          include ActiveModel::Attributes
          schema.each { |name, type| attribute(name, type) }
        end
      end
    end
  end
end
```

In `Base`, the union schema = merge of every step's `attribute_schema` (inline + imported). `data` builds (memoized) an instance of `Data.class_for(union_schema)` from the staged `data_attributes` hash. Structured inputs declared with `repeat:` are typed as arrays of nested snapshot objects — back them with an ActiveModel attribute whose type casts an array of hashes into nested `Data` instances (use a small custom `ActiveModel::Type` or map in the reader). For v1, implement structured arrays as: store raw array-of-hashes, and expose `data.invites` as an array of `OpenStruct`-like typed wrappers built from the structured_input's sub-schema. Keep the wrapper minimal but typed per the sub-field declarations.

- [ ] **Step 5: DSL module + Base**

```ruby
# lib/plutonium/wizard/dsl.rb
module Plutonium
  module Wizard
    module DSL
      extend ActiveSupport::Concern

      class_methods do
        def steps = @steps ||= []

        def step(key, label: nil, condition: nil, using: nil, **using_opts, &block)
          assert_not_after_review!(key)
          fields = capture_fields(using:, using_opts:, &block)
          on_submit = fields.delete_hook(:on_submit)
          on_rollback = fields.delete_hook(:on_rollback)
          steps << Step.new(key:, label:, condition:, fields:,
            on_submit:, on_rollback:, using_spec: fields.using_spec, form_layout: fields.form_layout)
        end

        def review(label: "Review", condition: nil, &block)
          steps << ReviewStep.new(label:, condition:, block:)
        end

        def anchored(with: nil, &resolver)
          @anchored = true
          @anchor_types = Array(with).presence
          @anchor_resolver = resolver
        end
        def anchored? = !!@anchored
        def anchor_types = @anchor_types
        def anchor_resolver = @anchor_resolver

        def navigation(mode = nil) = mode ? (@navigation = mode) : (@navigation || :linear)
        def cleanup_after(ttl = :__read__)
          return (@cleanup_after.nil? ? Plutonium.configuration.wizards.cleanup_after : @cleanup_after) if ttl == :__read__
          @cleanup_after = (ttl == :never ? nil : ttl)
        end
        def one_time(once_per: :user) = @one_time = once_per
        def one_time? = !@one_time.nil?
        def one_time_scope = @one_time
        def encrypt_data(flag = true) = @encrypt_data = flag
        def encrypt_data? = !!@encrypt_data

        private

        def assert_not_after_review!(key)
          if steps.any?(&:review?)
            raise ArgumentError, "`review` must be the last step; cannot declare step :#{key} after it"
          end
        end

        # Returns a fields-capture object; see Task 2 Step 4 + Task 3 for using:.
        def capture_fields(using:, using_opts:, &block) = FieldCapture.build(using:, using_opts:, &block)
      end
    end
  end
end
```

```ruby
# lib/plutonium/wizard/base.rb
module Plutonium
  module Wizard
    class Base
      include ActiveModel::Model
      include Plutonium::Definition::Presentable   # presents label:/icon:/description:
      include DSL

      attr_accessor :data_attributes, :view_context
      attr_writer :anchor, :scope, :token

      def initialize(view_context: nil, **)
        @view_context = view_context
        @data_attributes = {}
        super()
      end

      # Union schema across all (non-review) steps.
      def self.union_attribute_schema
        steps.reject(&:review?).reduce({}) { |acc, s| acc.merge(s.attribute_schema) }
      end

      def data
        @data ||= Data.class_for(self.class.union_attribute_schema).new(data_attributes)
      end

      def anchor
        raise NotAnchoredError, "#{self.class} is not `anchored`" unless self.class.anchored?
        @anchor
      end

      def persisted = @persisted ||= {}    # populated by the runner from on_submit/persist

      def execute = raise NotImplementedError, "#{self.class} must implement #execute"

      private

      # Raise a StepError from on_submit/execute. fail!("msg") or fail!(:field, "msg").
      def fail!(attribute_or_message, message = nil)
        if message.nil?
          raise StepError.new(attribute_or_message, attribute: :base)
        else
          raise StepError.new(message, attribute: attribute_or_message)
        end
      end

      def succeed(value = nil) = Plutonium::Interaction::Outcome::Success.new(value:)
      def failed(errors = nil, attribute = :base)
        self.errors.add(attribute, errors.to_s) if errors.is_a?(String)
        Plutonium::Interaction::Outcome::Failure.new(errors: self.errors)
      end
    end
  end
end
```

> The `FieldCapture` object (referenced above) wraps a `FieldsDefinition`-style recorder that supports `attribute`, `input`, `validates`, `structured_input`, `on_submit`, `on_rollback`, `using`, `form_layout`, and exposes `attribute_schema`, `delete_hook`, `using_spec`, `form_layout`. Implement it in this task for inline fields; the `using:` resolution is filled in Task 3 (here it can accept a spec and merge later). Keep `succeed`/`failed` aligned with `Plutonium::Interaction::Outcome` (verify the exact constructor — `Outcome::Success.new(value:)` per Task-research; adjust if the real signature differs).

- [ ] **Step 6: Run green** → PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/plutonium/wizard/step.rb lib/plutonium/wizard/review_step.rb lib/plutonium/wizard/data.rb lib/plutonium/wizard/dsl.rb lib/plutonium/wizard/base.rb test/plutonium/wizard/base_test.rb test/plutonium/wizard/data_test.rb
git commit -m "feat(wizard): Base DSL — step/review/anchored/navigation/one_time, typed data, fail!"
```

```json:metadata
{"files": ["lib/plutonium/wizard/step.rb", "lib/plutonium/wizard/review_step.rb", "lib/plutonium/wizard/data.rb", "lib/plutonium/wizard/dsl.rb", "lib/plutonium/wizard/base.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/base_test.rb test/plutonium/wizard/data_test.rb", "acceptanceCriteria": ["step/review/anchored/navigation/cleanup_after/one_time/encrypt_data DSL", "review terminality raises", "typed union data snapshot, nil for uncollected", "anchor raises NotAnchoredError", "fail! raises StepError with attribute"], "requiresUserVerification": false}
```

---

### Task 3: FieldImporter — `using:` an interaction or resource definition

**Goal:** A step can `using:` an interaction or resource definition to import attributes (with types), inputs, validations (run-and-filter to imported fields + `:base`), and `form_layout` — with `fields:`/`only:`/`except:`, `validate: false`, `layout: false`, `validation_context:`. Definition targets read base from the record class and overlay the definition's customizations (spec §2.4).

**Files:**
- Create: `lib/plutonium/wizard/field_importer.rb`
- Modify: `lib/plutonium/wizard/dsl.rb` (wire `using:` into `capture_fields`/`FieldCapture`)
- Test: `test/plutonium/wizard/field_importer_test.rb`

**Acceptance Criteria:**
- [ ] `using: SomeInteraction, only: %i[a b]` imports those attributes (types from the interaction's `attribute` declarations), inputs, and validations.
- [ ] `using: SomeDefinition, fields: %i[a]` resolves the field's **type from the definition's record class** (`Model.attribute_types`), overlays the definition's input config, and validates via `Model.new(slice).valid?`.
- [ ] Imported validation keeps errors only on imported fields **+ `:base`**; errors on other attributes are dropped.
- [ ] `validate: false` skips validation reuse; `layout: false` skips form_layout inheritance; `validation_context:` is passed to `valid?`.
- [ ] Inline declarations in the same step compose with imported ones (inline wins on conflict).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/field_importer_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test** — define a tiny interaction + a dummy resource/definition in the test, import subsets, assert schema/validation/error-filtering. (Use the dummy app's existing models/definitions for the definition-target case.)

```ruby
# test/plutonium/wizard/field_importer_test.rb (sketch — fill concretely against dummy models)
require "test_helper"

class Plutonium::Wizard::FieldImporterTest < ActiveSupport::TestCase
  class ContactInteraction < Plutonium::Interaction::Base
    attribute :phone, :string
    attribute :email, :string
    validates :email, presence: true
    private def execute = succeed(true)
  end

  test "interaction import: types + filtered validation" do
    spec = Plutonium::Wizard::FieldImporter.resolve(using: ContactInteraction, opts: {only: %i[email]})
    assert_equal({email: :string}, spec.attribute_schema)
    errors = spec.validate({"email" => ""})       # runs ContactInteraction.new(email:"").valid?
    assert errors.key?(:email)
    refute errors.key?(:phone)                    # not imported → dropped
  end

  test "validate: false skips validation" do
    spec = Plutonium::Wizard::FieldImporter.resolve(using: ContactInteraction, opts: {only: %i[email], validate: false})
    assert_empty spec.validate({"email" => ""})
  end
end
```

- [ ] **Step 2: Run red** → FAIL.

- [ ] **Step 3: Implement FieldImporter**

```ruby
# lib/plutonium/wizard/field_importer.rb
module Plutonium
  module Wizard
    module FieldImporter
      Spec = Struct.new(:attribute_schema, :inputs, :form_layout, :validate_fn) do
        def validate(data_slice) = validate_fn ? validate_fn.call(data_slice) : {}
      end

      def self.resolve(using:, opts:)
        only = Array(opts[:fields] || opts[:only]).map(&:to_sym).presence
        except = Array(opts[:except]).map(&:to_sym)
        do_validate = opts.fetch(:validate, true)
        do_layout = opts.fetch(:layout, true)
        context = opts[:validation_context]

        if interaction?(using)
          from_interaction(using, only:, except:, do_validate:, do_layout:, context:)
        else
          from_definition(using, only:, except:, do_validate:, do_layout:, context:)
        end
      end

      def self.interaction?(klass) = klass < Plutonium::Interaction::Base

      def self.select(names, only:, except:)
        names = names & only if only
        names - except
      end

      def self.from_interaction(klass, only:, except:, do_validate:, do_layout:, context:)
        names = select(klass.attribute_names.map(&:to_sym), only:, except:)
        schema = names.index_with { |n| klass.attribute_types[n.to_s]&.type || :string }
        validate_fn = build_validate(do_validate) do |slice|
          obj = klass.new
          obj.attributes = slice.slice(*names.map(&:to_s))
          run_and_filter(obj, names, context)
        end
        Spec.new(attribute_schema: schema, inputs: klass.defined_inputs.slice(*names),
          form_layout: (do_layout ? layout_for(klass, names) : nil), validate_fn:)
      end

      def self.from_definition(defn, only:, except:, do_validate:, do_layout:, context:)
        model = defn.model_class      # resolve the backing record class (verify exact accessor on Definition)
        names = select(defn.defined_inputs.keys.map(&:to_sym), only:, except:)
        # Type from record (base), input config overlaid by definition (handled at render time).
        schema = names.index_with { |n| model.attribute_types[n.to_s]&.type || :string }
        validate_fn = build_validate(do_validate) do |slice|
          rec = model.new(slice.slice(*names.map(&:to_s)))
          run_and_filter(rec, names, context)
        end
        Spec.new(attribute_schema: schema, inputs: defn.defined_inputs.slice(*names),
          form_layout: (do_layout ? layout_for(defn, names) : nil), validate_fn:)
      end

      def self.build_validate(do_validate)
        return nil unless do_validate
        ->(slice) { yield(slice) }
      end

      # Run valid? and keep errors only on imported fields + :base.
      def self.run_and_filter(obj, names, context)
        context ? obj.valid?(context) : obj.valid?
        keep = names.map(&:to_s) << "base"
        obj.errors.group_by_attribute.slice(*keep.map(&:to_sym))
      end

      def self.layout_for(source, names)
        layout = source.respond_to?(:defined_form_layout) ? source.defined_form_layout : nil
        return nil unless layout
        # Filter sections to imported fields (reuse Section resolution semantics).
        layout.map { |sec| Plutonium::Definition::FormLayout::ResolvedSection.new(sec, sec.fields & names) }
              .reject { |rs| rs.fields.empty? && !rs.section.ungrouped? }
      end
    end
  end
end
```

> Verify exact accessors against the real codebase: `Interaction.attribute_types`/`attribute_names`/`defined_inputs`, definition's record-class accessor (likely `model_class` or similar — confirm), and `errors.group_by_attribute` availability (Rails 6.1+). Adjust names to match.

- [ ] **Step 4: Wire into the DSL** — in `FieldCapture`, when `using:` is given, call `FieldImporter.resolve` and merge its `attribute_schema`/`inputs`/`form_layout`/`validate_fn` with inline declarations (inline overrides imported). Expose `using_spec` on the Step so the runner (Task 4) and form (Task 6) can use it.

- [ ] **Step 5: Run green** → PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/wizard/field_importer.rb lib/plutonium/wizard/dsl.rb test/plutonium/wizard/field_importer_test.rb
git commit -m "feat(wizard): using: import of fields/validations/form_layout from interaction or definition"
```

```json:metadata
{"files": ["lib/plutonium/wizard/field_importer.rb", "lib/plutonium/wizard/dsl.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/field_importer_test.rb", "acceptanceCriteria": ["interaction import: types+inputs+validations", "definition import: type from record class + overlay", "validation run-and-filter to imported fields + :base", "validate:false / layout:false / validation_context:", "inline composes with imported"], "requiresUserVerification": false}
```

---

### Task 4: Runner — navigation, validation, on_submit/persist/on_rollback, execute, completeness/prune, lock, cleanup, resume

**Goal:** The pure engine that, given a wizard + State + Store, computes the visible path, validates a step, advances/back/cancel, runs `on_submit` (tracking persisted GIDs) and `on_rollback`, finalizes via `execute` with completeness assertion + branch-hidden pruning + the locked `completing` transition, performs cleanup, and rehydrates `persisted` on resume. No HTTP yet — drive it directly in unit tests with the Memory store.

**Files:**
- Create: `lib/plutonium/wizard/runner.rb`
- Test: `test/plutonium/wizard/runner_test.rb`

**Acceptance Criteria:**
- [ ] `visible_path` evaluates each step's `condition:` against `data` (subtractive); branch-hidden steps excluded; `review` always last.
- [ ] `advance(step, params)` validates the step (inline + imported), stages `data`, runs `on_submit` (in a transaction), tracks records passed to `persist` as GIDs in `state.persisted[step_key]`, moves cursor to the next visible step; on validation/`on_submit` failure returns errors and does not advance.
- [ ] `back` moves cursor without validating; never discards `data`.
- [ ] `cancel` runs `on_rollback`/destroy of tracked records (reverse order) then clears the row.
- [ ] `finalize` asserts every visible non-review step is visited+valid (else returns the first offending step), prunes `data` for branch-hidden steps, performs the locked `in_progress → completing` transition (bails if already moved), runs `execute`; on success `complete`s the row, on failure reverts to `in_progress`.
- [ ] On load, `persisted` is rehydrated from stored GIDs (GlobalID.locate).
- [ ] `on_submit` failure: `RecordInvalid` → field errors; `StepError` → `attribute` error; other `StandardError` re-raised.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/runner_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing tests** — branching path, advance happy/invalid, back-no-validate, on_submit persist+track, on_rollback on cancel, finalize completeness+prune, double-submit lock (simulate concurrent by calling finalize twice). Use a wizard with `condition:` and an `on_submit` that `persist`s a dummy AR record.

```ruby
# test/plutonium/wizard/runner_test.rb (key cases — expand)
require "test_helper"

class Plutonium::Wizard::RunnerTest < ActiveSupport::TestCase
  class W < Plutonium::Wizard::Base
    step(:a) { attribute :go, :string; validates :go, presence: true }
    step(:b, condition: -> { data.go == "yes" }) { attribute :note, :string }
    review label: "R"
    def execute = succeed(:done)
  end

  setup do
    @store = Plutonium::Wizard::Store::Memory.new
    @runner = Plutonium::Wizard::Runner.new(wizard_class: W, store: @store, instance_key: "k")
  end

  test "branching hides b until go=yes" do
    assert_equal %i[a review], @runner.visible_path.map(&:key)
    @runner.advance(:a, {"go" => "yes"})
    assert_equal %i[a b review], @runner.visible_path.map(&:key)
  end

  test "advance invalid does not move" do
    res = @runner.advance(:a, {"go" => ""})
    refute res.ok?
    assert res.errors.key?(:go)
    assert_equal :a, @runner.current_step.key
  end

  test "finalize completeness redirects to first gap" do
    res = @runner.finalize
    refute res.completed?
    assert_equal :a, res.redirect_step
  end

  test "concurrent finalize: loser bails" do
    @runner.advance(:a, {"go" => "no"})   # b hidden; only a + review
    first = @runner.finalize
    assert first.completed?
    second = Plutonium::Wizard::Runner.new(wizard_class: W, store: @store, instance_key: "k").finalize
    refute second.completed?              # already completed/cleared
  end
end
```

- [ ] **Step 2: Run red** → FAIL.

- [ ] **Step 3: Implement Runner** — core methods (concrete):

```ruby
# lib/plutonium/wizard/runner.rb
module Plutonium
  module Wizard
    class Runner
      Result = Struct.new(:ok, :errors, :completed, :redirect_step, :value) do
        def ok? = !!ok
        def completed? = !!completed
      end

      def initialize(wizard_class:, store:, instance_key:, view_context: nil, owner: nil, anchor: nil, scope: nil, token: nil)
        @wizard_class = wizard_class
        @store = store
        @instance_key = instance_key
        @state = store.read(instance_key) || new_state(owner:, anchor:, scope:, token:)
        @wizard = wizard_class.new(view_context:)
        @wizard.data_attributes = @state.data
        @wizard.anchor = (@state.anchor || anchor) if wizard_class.anchored?
        rehydrate_persisted
      end

      def visible_path
        @wizard.data_attributes = @state.data
        @wizard_class.steps.select { |s| s.condition.nil? || @wizard.instance_exec(&s.condition) }
      end

      def current_step = visible_path.find { _1.key.to_s == @state.current_step } || visible_path.first

      def advance(step_key, params)
        step = step_for(step_key)
        errors = validate(step, params)
        return Result.new(ok: false, errors:) if errors.any?
        merge_data(params)
        run_on_submit(step) if step.on_submit
        @state.current_step = next_visible_after(step)&.key.to_s
        persist_state
        Result.new(ok: true)
      rescue ActiveRecord::RecordInvalid => e
        Result.new(ok: false, errors: e.record.errors.group_by_attribute)
      rescue StepError => e
        Result.new(ok: false, errors: {e.attribute => [e.message]})
      end

      def back
        prev = previous_visible
        @state.current_step = prev&.key.to_s
        persist_state
        Result.new(ok: true)
      end

      def cancel
        run_cleanup
        @store.clear(@instance_key)
        Result.new(ok: true)
      end

      def finalize
        gap = first_incomplete_visible
        return Result.new(ok: false, redirect_step: gap.key) if gap

        prune_hidden!
        return Result.new(ok: false, completed: false) unless lock_for_completion!

        outcome = ActiveRecord::Base.transaction do
          run_deferred_nothing  # (all on_submit already ran per-step; execute does at-end writes)
          @wizard.data_attributes = @state.data
          @wizard.execute
        end

        if outcome.success?
          @store.complete(@instance_key)
          Result.new(ok: true, completed: true, value: outcome.value)
        else
          revert_completing!
          Result.new(ok: false, completed: false, errors: outcome_errors(outcome))
        end
      rescue ActiveRecord::RecordInvalid => e
        revert_completing!
        Result.new(ok: false, errors: e.record.errors.group_by_attribute)
      rescue StepError => e
        revert_completing!
        Result.new(ok: false, errors: {e.attribute => [e.message]})
      end

      private

      def lock_for_completion!
        row = Session.find_by(instance_key: @instance_key) or return true # memory store: no row
        row.with_lock do
          return false unless row.status_in_progress?
          row.update!(status: "completing")
        end
        true
      end

      def revert_completing!
        Session.where(instance_key: @instance_key, status: "completing").update_all(status: "in_progress")
      end

      def run_on_submit(step)
        ActiveRecord::Base.transaction do
          tracker = PersistTracker.new
          @wizard.data_attributes = @state.data
          @wizard.define_singleton_method(:persist) { |*recs| tracker.add(recs.flatten) }
          @wizard.instance_exec(&step.on_submit)
          @state.persisted[step.key.to_s] = tracker.gids
          @wizard.instance_variable_get(:@persisted)&.merge!(step.key => tracker.records)
        end
      end

      def run_cleanup
        @wizard_class.steps.reverse_each do |step|
          recs = (@state.persisted[step.key.to_s] || []).filter_map { GlobalID.locate(_1) }
          next if recs.empty?
          if step.on_rollback
            @wizard.instance_variable_set(:@persisted, {step.key => recs})
            @wizard.instance_exec(&step.on_rollback)
          else
            recs.reverse_each(&:destroy!)
          end
        end
      end

      def validate(step, params)
        merged = @state.data.merge(params)
        errors = {}
        # imported validation (run-and-filter)
        errors.merge!(step.using_spec.validate(merged)) if step.using_spec
        # inline validation: build a small ActiveModel from the step's inline attrs + validators
        errors.merge!(step.fields.validate_inline(merged)) if step.fields.respond_to?(:validate_inline)
        errors.reject { |_, msgs| msgs.blank? }
      end

      def merge_data(params) = @state.data = @state.data.merge(params)
      def persist_state = @store.write(@instance_key, @state, cleanup_after: @wizard_class.cleanup_after)
      def step_for(key) = @wizard_class.steps.find { _1.key.to_s == key.to_s }
      def next_visible_after(step) = (vp = visible_path; vp[vp.index { _1.key == step.key }.to_i + 1])
      def previous_visible = (vp = visible_path; i = vp.index { _1.key.to_s == @state.current_step }.to_i; vp[[i - 1, 0].max])
      def first_incomplete_visible = visible_path.reject(&:review?).find { |s| !step_visited_and_valid?(s) }
      def step_visited_and_valid?(s) = validate(s, {}).empty? # visited rows have data staged; empty errors == valid
      def prune_hidden!
        visible = visible_path.flat_map { _1.attribute_schema.keys.map(&:to_s) }
        @state.data = @state.data.slice(*visible)
      end
      def rehydrate_persisted
        return unless @state.persisted.present?
        recs = @state.persisted.transform_values { |gids| Array(gids).filter_map { GlobalID.locate(_1) } }
        @wizard.instance_variable_set(:@persisted, recs.transform_keys(&:to_sym))
      end
      def new_state(owner:, anchor:, scope:, token:)
        State.new(wizard: @wizard_class.name, instance_key: @instance_key,
          current_step: @wizard_class.steps.first&.key.to_s, status: "in_progress",
          data: {}, persisted: {}, owner:, anchor:, scope:, token:)
      end
      def outcome_errors(o) = o.respond_to?(:errors) ? o.errors.group_by_attribute : {}
      def run_deferred_nothing = nil

      class PersistTracker
        def initialize = (@records = [])
        def add(recs) = @records.concat(Array(recs))
        def records = @records
        def gids = @records.map { _1.to_global_id.to_s }
      end
    end
  end
end
```

> This is the most intricate task — verify the `persist` macro binding (it must be available only inside `on_submit`/`execute`; the singleton-method approach above is one way; an alternative is a `PersistContext` the block is `instance_exec`'d against). Confirm `errors.group_by_attribute` shape and `Outcome` error access. Keep each behavior under its own test.

- [ ] **Step 4: Run green** → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/wizard/runner.rb test/plutonium/wizard/runner_test.rb
git commit -m "feat(wizard): runner — navigation, on_submit/persist/rollback, finalize lock + completeness/prune"
```

```json:metadata
{"files": ["lib/plutonium/wizard/runner.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/runner_test.rb", "acceptanceCriteria": ["visible_path subtractive branching", "advance validates+stages+on_submit+tracks GIDs", "back no-validate", "cancel runs rollback+clears", "finalize completeness+prune+lock+execute", "persisted rehydrated on resume", "failure mapping RecordInvalid/StepError"], "requiresUserVerification": false}
```

---

### Task 5: Controller, routing, and registration (`register_wizard` + `wizard` definition DSL) + `authorize?`

**Goal:** HTTP surface. One controller drives GET (render step), POST (`_direction` next/back/cancel, `pre_submit`), resolving the instance (scope/anchor/token/owner) and delegating to the Runner. Routes are synthesized two ways: standalone `register_wizard ... at:` and the in-definition `wizard` macro (which mirrors the action system). Entry checks `authorize?` (standalone) / the action policy (resource).

**Files:**
- Create: `app/controllers/plutonium/wizard/controller.rb`, `lib/plutonium/routing/wizard_registration.rb`, `lib/plutonium/definition/wizards.rb`
- Modify: `lib/plutonium/routing/mapper_extensions.rb` (draw per-resource wizard routes + `register_wizard`), `lib/plutonium/definition/base.rb` (include `Definition::Wizards`)
- Test: `test/integration/.../wizard_flow_test.rb` (dummy app, all surfaces)

**Acceptance Criteria:**
- [ ] `register_wizard OnboardingWizard, at: "/welcome"` draws `GET/POST /welcome/:step` (+ token variant) → the wizard controller; provides `welcome_wizard_path`.
- [ ] `wizard :configure, ConfigureCompanyWizard` in a definition synthesizes a record action (anchored) / resource action (no anchor) that links to the wizard's GET route; placement mirrors interactions (record vs resource; **no bulk**).
- [ ] GET renders the current step's form; POST `_direction=next` advances (or re-renders with errors `:unprocessable_content`), `back` goes back, `cancel` runs cleanup; `pre_submit` re-renders the form via turbo_stream (mirror interactive_actions.rb).
- [ ] On finalize success → PRG redirect to the outcome target; one-time completion recorded.
- [ ] Standalone entry calls `wizard.authorize?` (403 on false); resource entry uses the action's policy predicate.
- [ ] Anchor injected from `:id` (record action); scope from the portal scoped entity; pre-auth token minted in a signed cookie.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/<portal>/wizard_flow_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing integration test** — in the dummy app, hand-write a small wizard (per project convention, dummy wizards are authored by hand like interactions), register it both standalone and on a resource definition, then drive: GET step 1 → POST next → GET step 2 → POST finish → assert redirect + records created; POST back; POST cancel → assert cleanup. Mirror `test/integration/org_portal/structured_input_interaction_test.rb` for request shape, `login_as`, and Turbo-Frame headers.

- [ ] **Step 2: Run red** → FAIL.

- [ ] **Step 3: Controller** — concrete skeleton (mirrors `interactive_actions.rb` flow §6):

```ruby
# app/controllers/plutonium/wizard/controller.rb
module Plutonium
  module Wizard
    module Controller
      extend ActiveSupport::Concern

      def show           # GET .../:step
        runner = build_runner
        authorize_wizard!(runner)
        @wizard_view = runner   # expose to the page
        render Plutonium::UI::Page::Wizard.new(runner:), **modal_render_options
      end

      def update         # POST .../:step
        runner = build_runner
        authorize_wizard!(runner)
        step_key = params[:step]

        if params[:pre_submit]
          return render_pre_submit(runner, step_key)
        end

        result =
          case params[:_direction]
          when "back"   then runner.back
          when "cancel" then runner.cancel
          else
            adv = runner.advance(step_key, wizard_params)
            adv.ok? && runner.current_step&.review? == false && last_step?(runner) ? runner.finalize : adv
          end

        respond_to_result(runner, result)
      end

      private

      def build_runner
        Plutonium::Wizard::Runner.new(
          wizard_class: current_wizard_class, store: wizard_store, instance_key: resolved_instance_key,
          view_context:, owner: current_user, anchor: resolved_anchor, scope: resolved_scope, token: resolved_token
        )
      end

      def authorize_wizard!(runner)
        wiz = runner.wizard  # expose reader on Runner
        if wiz.respond_to?(:authorize?) && !wiz.authorize?
          raise ActionPolicy::Unauthorized.new(nil, nil)
        end
        # resource-attached wizards additionally go through the action policy (mirror interactive actions)
      end

      def wizard_store = Plutonium::Wizard::Store::ActiveRecord.new
      # resolved_instance_key/anchor/scope/token: from params + current scope + signed cookie (see spec §4)
    end
  end
end
```

Implement: `respond_to_result` (success → `turbo_stream_redirect` / `redirect_to ..., status: :see_other`; failure → re-render step `:unprocessable_content`), `render_pre_submit` (turbo_stream replace of the form, mirroring interactive_actions.rb lines 37-60), `resolved_instance_key` (via `InstanceKey.for`), `resolved_scope` (portal `scoped_entity` if `scoped_to_entity?`), `resolved_token` (signed cookie, mint if absent for non-anchored), `last_step?`.

- [ ] **Step 4: Routing** — `register_wizard` + per-resource routes:

```ruby
# lib/plutonium/routing/wizard_registration.rb
module Plutonium
  module Routing
    module WizardRegistration
      def register_wizard(wizard_class, at:)
        slug = wizard_class.name.demodulize.underscore.sub(/_wizard$/, "")
        scope path: at do
          get  "(/:token)/:step", to: "plutonium/wizard#show",   as: :"#{slug}_wizard", defaults: {wizard: wizard_class.name}
          post "(/:token)/:step", to: "plutonium/wizard#update", defaults: {wizard: wizard_class.name}
        end
      end
    end
  end
end
```

Per-resource wizard routes mirror the interactive `record_actions`/`resource_actions` block in `mapper_extensions.rb` (lines 146-169): add `wizards/:wizard_slug(/:step)` GET/POST under member (anchored) and collection (non-anchored). Prepend `WizardRegistration` to `ActionDispatch::Routing::Mapper` in the Railtie alongside the existing `MapperExtensions`.

- [ ] **Step 5: `wizard` definition DSL** — synthesize actions:

```ruby
# lib/plutonium/definition/wizards.rb
module Plutonium
  module Definition
    module Wizards
      extend ActiveSupport::Concern
      class_methods do
        def wizard(name, wizard_class, record_action: nil, collection: nil, **opts)
          anchored = wizard_class.anchored?
          is_record = record_action.nil? ? anchored : record_action
          action(name,
            route_options: Plutonium::Action::RouteOptions.new(method: :get, action: :show,
              url_resolver: wizard_url_resolver(wizard_class, is_record)),
            record_action: is_record, resource_action: !is_record,
            category: opts.fetch(:category, :primary),
            icon: opts[:icon], position: opts[:position],
            label: wizard_class.respond_to?(:presents) ? wizard_class.label : name.to_s.humanize)
        end
      end
    end
  end
end
```

Include `Plutonium::Definition::Wizards` in `Definition::Base` (next to `Actions`). Implement `wizard_url_resolver` to build the wizard GET path for the subject. Confirm `Action::RouteOptions` constructor + `url_resolver` against `action/interactive.rb`.

- [ ] **Step 6: Run green** → PASS (iterate on routing/url helpers against the dummy app).

- [ ] **Step 7: Commit**

```bash
git add app/controllers/plutonium/wizard/controller.rb lib/plutonium/routing/wizard_registration.rb lib/plutonium/definition/wizards.rb lib/plutonium/routing/mapper_extensions.rb lib/plutonium/definition/base.rb lib/plutonium/railtie.rb test/integration
git commit -m "feat(wizard): controller, register_wizard routing, wizard definition DSL, authorize?"
```

```json:metadata
{"files": ["app/controllers/plutonium/wizard/controller.rb", "lib/plutonium/routing/wizard_registration.rb", "lib/plutonium/definition/wizards.rb", "lib/plutonium/routing/mapper_extensions.rb", "lib/plutonium/definition/base.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration", "acceptanceCriteria": ["register_wizard draws routes + helper", "wizard DSL synthesizes record/resource action (no bulk)", "GET renders step; POST next/back/cancel; pre_submit", "PRG on finalize success", "authorize? gate (standalone) / policy (resource)", "anchor/scope/token resolution"], "requiresUserVerification": false}
```

---

### Task 6: UI — Page::Wizard, Stepper, nav buttons, review auto-summary, form rendering + repeater rehydration

**Goal:** Render a step (reusing the interaction form pipeline), the stepper (with disabled/branch-hidden behavior), Back/Next/Finish/Cancel buttons carrying `_direction`, and the review step's auto-summary (display components + outstanding-item jump links). Repeater rows rehydrate from staged `data` on GET.

**Files:**
- Create: `lib/plutonium/ui/page/wizard.rb`, `lib/plutonium/ui/wizard/stepper.rb`, `lib/plutonium/ui/wizard/review.rb`, `lib/plutonium/ui/form/wizard_step.rb` (subclass of `UI::Form::Interaction`)
- Test: `test/integration/.../wizard_rendering_test.rb`
- Possibly: a small Stimulus controller for nav (mirror keystone's `wizard_nav_controller.js` intent — submit with `_direction`), registered per project convention.

**Acceptance Criteria:**
- [ ] The current step renders its fields (inline + `using:`-imported, honoring inherited/inline `form_layout`) via a `UI::Form::Wizard` form posting to the step's POST route with `_direction`.
- [ ] Stepper shows visible steps with completed/current/upcoming state; `:linear` allows clicking visited steps, disables upcoming; branch-hidden steps absent. `:free` allows any visited step.
- [ ] Repeatable `structured_input` rows rehydrate from staged `data` on GET (not only on failed submit).
- [ ] The `review` step renders an auto-summary of visible steps' `data` via display components + lists invalid/unvisited steps as jump links; Finish disabled until valid.
- [ ] Resource-action wizards render in the modal/turbo-frame; standalone render full-page.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/<portal>/wizard_rendering_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing rendering test** — GET a step, assert the form fields + stepper markup; GET a wizard mid-flow with staged repeater data, assert N rows rendered; GET the review step, assert summary + outstanding links.
- [ ] **Step 2: Run red** → FAIL.
- [ ] **Step 3: Implement `UI::Form::Wizard`** subclassing `Plutonium::UI::Form::Interaction` — set `resource_fields` to the current step's field names, `resource_definition` to a per-step adapter exposing `defined_inputs`/`resolve_form_sections` from the step (inline + imported), `form_action` to the step's POST URL, and render a hidden `_direction` defaulting to `next`. Seed repeater values from `runner` staged data (override the value source so rows rehydrate on GET).
- [ ] **Step 4: Implement `Page::Wizard`** — composes the stepper + the step form (or the review component for a review step) + nav buttons; chooses modal vs full-page from the surface (mirror `UI::Page::InteractiveAction` for modal).
- [ ] **Step 5: Implement `Wizard::Stepper`** (Phlex) — renders visible path with state; clickable rules per `navigation`.
- [ ] **Step 6: Implement `Wizard::Review`** (Phlex) — iterate visible non-review steps, render each field via the display pipeline (reuse `UI::Display`), and list `runner.first_incomplete_visible`-style gaps as links to each step's GET route; render Finish (disabled unless complete).
- [ ] **Step 7: Stimulus nav** (if needed) — a controller that sets `_direction` and submits; register it.
- [ ] **Step 8: Run green** → PASS.
- [ ] **Step 9: Commit**

```bash
git add lib/plutonium/ui/page/wizard.rb lib/plutonium/ui/wizard lib/plutonium/ui/form/wizard_step.rb app/assets test/integration
git commit -m "feat(wizard): UI — page, stepper, review auto-summary, step form + repeater rehydration"
```

```json:metadata
{"files": ["lib/plutonium/ui/page/wizard.rb", "lib/plutonium/ui/wizard/stepper.rb", "lib/plutonium/ui/wizard/review.rb", "lib/plutonium/ui/form/wizard_step.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration", "acceptanceCriteria": ["step renders fields + form_layout via wizard form", "stepper states + linear/free click rules", "repeater rows rehydrate on GET", "review auto-summary + outstanding jump links + gated finish", "modal vs full-page by surface"], "requiresUserVerification": false}
```

---

### Task 7: One-time wizards (gate + completion) and SweepJob

**Goal:** `one_time once_per: :user/:anchor` records a durable completion and an `ensure_wizard_completed` controller concern redirects un-completed users into the wizard and bounces completed ones. `SweepJob` reaps idle `in_progress`/`completing` rows (running cleanup) past `expires_at`.

**Files:**
- Create: `lib/plutonium/wizard/gate.rb`, `lib/plutonium/wizard/sweep_job.rb`
- Modify: controller finalize path to record one-time completion (already `complete`s the row; add the once-per assertion so a second run short-circuits).
- Test: `test/plutonium/wizard/sweep_job_test.rb`, `test/integration/.../wizard_one_time_test.rb`

**Acceptance Criteria:**
- [ ] A `one_time once_per: :user` wizard, once completed, is detected by `store.completed?(wizard:, owner:)`; `ensure_wizard_completed WizardClass` redirects to the wizard until done, then bounces to the original destination (PRG); completed users pass through.
- [ ] `once_per: :anchor` keys completion on the anchor.
- [ ] `SweepJob.perform_now` deletes idle `in_progress`/`completing` rows past `expires_at`, running each wizard's cleanup (`on_rollback`/destroy tracked records); never touches `completed`; skips null `expires_at`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/sweep_job_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing tests** — sweep deletes expired in_progress + runs rollback on tracked records; leaves completed + null-expiry; gate concern redirects/bounces.
- [ ] **Step 2: Run red** → FAIL.
- [ ] **Step 3: SweepJob**

```ruby
# lib/plutonium/wizard/sweep_job.rb
module Plutonium
  module Wizard
    class SweepJob < ActiveJob::Base
      def perform(now: Time.current)
        Session.sweepable(now).find_each do |row|
          wizard_class = row.wizard.safe_constantize
          Runner.new(wizard_class:, store: Store::ActiveRecord.new, instance_key: row.instance_key)
                .cancel if wizard_class    # cancel runs cleanup + clears the row
          row.destroy! if Session.exists?(id: row.id)
        end
      end
    end
  end
end
```

- [ ] **Step 4: Gate concern**

```ruby
# lib/plutonium/wizard/gate.rb
module Plutonium
  module Wizard
    module Gate
      extend ActiveSupport::Concern
      class_methods do
        def ensure_wizard_completed(wizard_class, **opts)
          before_action(**opts) do
            store = Plutonium::Wizard::Store::ActiveRecord.new
            key = wizard_completion_key(wizard_class)   # owner or anchor per once_per
            unless store.completed?(**key)
              session[:return_to] ||= request.fullpath
              redirect_to wizard_entry_path(wizard_class) and return
            end
          end
        end
      end
    end
  end
end
```

Implement `wizard_completion_key` (owner: current_user for `:user`; anchor for `:anchor`) and `wizard_entry_path`. On finalize, after `complete`, redirect to `session.delete(:return_to)` if present.

- [ ] **Step 5: Run green** → PASS.
- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/wizard/gate.rb lib/plutonium/wizard/sweep_job.rb test/plutonium/wizard/sweep_job_test.rb test/integration
git commit -m "feat(wizard): one-time gate + completion, SweepJob for abandoned cleanup"
```

```json:metadata
{"files": ["lib/plutonium/wizard/gate.rb", "lib/plutonium/wizard/sweep_job.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/wizard/sweep_job_test.rb", "acceptanceCriteria": ["one_time completion detected (user/anchor)", "ensure_wizard_completed redirect+bounce", "SweepJob reaps expired in_progress/completing with cleanup, keeps completed/null-expiry"], "requiresUserVerification": false}
```

---

### Task 8: Documentation and skill

**Goal:** A user guide, reference pages, and the `plutonium-wizard` AI skill, wired into nav and the umbrella skill map.

**Files:**
- Create: `.claude/skills/plutonium-wizard/SKILL.md`, `docs/guides/wizards.md`, `docs/reference/wizard/{dsl,anchoring-resume,storage-config,registration-launch,one-time}.md`
- Modify: VitePress nav config (`docs/.vitepress/config.*`), umbrella skill `.claude/skills/plutonium/SKILL.md` skill-map
- Test: `yarn docs:build` (no broken links)

**Acceptance Criteria:**
- [ ] Guide covers: a minimal `execute`-only wizard; branching with `condition:`; `using:` reuse; per-step `on_submit`/`persist`/`on_rollback`; one-time onboarding; registration (resource + standalone); config (`config.wizards.*`).
- [ ] Skill mirrors other `plutonium-*` skills' frontmatter/structure and is added to the umbrella skill map.
- [ ] `yarn docs:build` passes (no broken links).

**Verify:** `yarn docs:build` → success

**Steps:**

- [ ] **Step 1:** Write `docs/guides/wizards.md` (task-oriented, from spec §2–§9 examples).
- [ ] **Step 2:** Write the `docs/reference/wizard/*.md` pages; add all to VitePress nav.
- [ ] **Step 3:** Write `.claude/skills/plutonium-wizard/SKILL.md`; add to umbrella skill map.
- [ ] **Step 4:** `yarn docs:build` → fix any broken links.
- [ ] **Step 5: Commit**

```bash
git add .claude/skills/plutonium-wizard docs/guides/wizards.md docs/reference/wizard .claude/skills/plutonium/SKILL.md docs/.vitepress
git commit -m "docs(wizard): guide, reference pages, plutonium-wizard skill"
```

```json:metadata
{"files": [".claude/skills/plutonium-wizard/SKILL.md", "docs/guides/wizards.md", "docs/reference/wizard/dsl.md"], "verifyCommand": "yarn docs:build", "acceptanceCriteria": ["guide covers core flows", "skill mirrors plutonium-* + added to umbrella map", "docs:build passes"], "requiresUserVerification": false}
```

---

## Self-Review notes

- **Spec coverage:** §2 (DSL) → Tasks 2–3, 6; §3 (anchoring) → Task 2,5; §4 (identity/resume) → Tasks 1,4,5; §5 (registration) → Task 5; §6 (runtime) → Task 4–5; §7 (UI) → Task 6; §8 (storage) → Task 1; §9 (one-time) → Task 7; §10 (migrations/config) → Task 0; §14 (testing) → every task; §15 (docs) → Task 8.
- **Verification requirement scan:** the originating request requires no human-in-the-loop verification → **NO**; no `requiresUserVerification: true` tasks. (Confirmed in header.)
- **Learnings from executed tasks (carry forward):**
  - **Plutonium is a Railtie, not an Engine** — the gem's Zeitwerk loader is rooted at `lib/`, so wizard classes live under `lib/plutonium/wizard/` (the `Session` AR model went to `lib/plutonium/wizard/session.rb`, NOT `app/models`). **Task 5 (controller) and Task 6 (UI components):** before placing files under `app/`, verify how existing Plutonium controllers/Phlex components are exposed to host apps (they may be base classes mixed into host controllers, or `app/` may be added to paths by the Railtie). Place wizard controller/components consistently with existing Plutonium controllers/UI — do not assume `app/` autoloads.
  - **Task 4 (runner):** the AR store's `find_or_initialize_by + save!` upsert has a TOCTOU window; the unique `instance_key` index is the backstop. The runner must **rescue `ActiveRecord::RecordNotUnique` on concurrent session creation** (re-read and proceed). Also: on cancel/sweep, run `on_rollback`/destroy of tracked records **before** `store.clear` (which is `delete_all`, no callbacks) — never rely on `dependent:`. Step validation must call `step.imported_validate_fn` (model-only now — `Model.new(slice).valid?`, returns `{attr => [msgs]}` filtered to imported + `:base`; **may be nil** when `validate: false` → nil-guard) and **merge** with inline `validates` errors. The earlier interaction/`view_context` validation concern is moot (interaction targets were dropped — `using:` is model-only). The corrected Outcome API: `succeed`→`Success.new(value)`, `failed`→`Failure.new` + ActiveModel errors. The `data` memo is invalidated on `data_attributes=` (fixed in Task 2).
  - Optional polish (non-blocking): make `Store#complete` return type consistent across adapters (document as void in `Base`).
  - **Open follow-up after Task 5:** per-resource **anchored member routes** (`/<resource>/:id/wizards/<name>/:step`) are NOT yet drawn in `register_resource` — only portal-level `register_wizard` routes exist. The `wizard` definition macro + controller support anchors, but the anchored-resource launch needs member-route nesting in `mapper_extensions.rb` + an anchored integration test. Fold into Task 6 or a small routing task. Also: Task 6 should route param extraction through the form's `extract_input` (Task 5 uses `params[:wizard].to_unsafe_h`, safe only because the typed `data` snapshot ignores undeclared keys) and flag for the final review: signed-cookie token handling, `authorize?` default-allow, and pre_submit turbo_stream.
- **Known risk points flagged for the implementer (verify against real APIs before/while coding):** the `persist` macro binding inside `on_submit` (Task 4); `Outcome::Success.new`/`Failure.new` exact constructor + error access (Tasks 2,4); definition record-class accessor + `defined_inputs` (Task 3); `errors.group_by_attribute` (Tasks 3,4); `Action::RouteOptions`/`url_resolver` shape (Task 5); reusing `UI::Form::Interaction` internals for per-step forms (Task 6). These are integration seams — each has a test that will surface a mismatch immediately.
