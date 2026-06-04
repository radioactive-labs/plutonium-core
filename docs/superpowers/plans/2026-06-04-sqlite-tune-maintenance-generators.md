# SQLite Tuning & Maintenance Generators Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two `pu:lite` generators — `pu:lite:tune` (SQLite performance pragmas) and `pu:lite:maintenance` (a scheduled `SqliteMaintenanceJob`) — and wire them into the lite app template and docs.

**Architecture:** Two new `Rails::Generators::Base` generators under `lib/generators/pu/lite/`. The `recurring.yml` injection logic currently private to the rails_pulse generator is extracted into a shared, unit-testable `ConfiguresRecurring` concern (with a pure nested `RecurringYAML` class, mirroring the existing `ConfiguresSqlite::DatabaseYAML`). `pu:lite:tune` edits `config/database.yml`'s `default: &default` block; `pu:lite:maintenance` templates a job and schedules it via the new concern.

**Tech Stack:** Ruby, Rails generators (Thor), Zeitwerk autoloading, Minitest, VitePress docs.

**User Verification:** NO — no user verification required. (The original request is "add support for SQLite config + maintenance to the template"; success is verifiable by automated generator tests, not human sign-off.)

**Commit policy:** Per the user's explicit instruction ("commit at the end"), individual tasks do **NOT** commit. Each task ends by running its tests green. A single final commit happens in the last task. This overrides the skill's default frequent-commit guidance.

---

## File Structure

| Action | Path | Responsibility |
|---|---|---|
| Create | `lib/generators/pu/lib/plutonium_generators/concerns/configures_recurring.rb` | Shared `recurring.yml` injection (concern + pure `RecurringYAML`) |
| Modify | `lib/generators/pu/lite/rails_pulse/rails_pulse_generator.rb` | Use the shared concern instead of private methods |
| Create | `lib/generators/pu/lite/tune/tune_generator.rb` | `pu:lite:tune` — insert tuned pragmas into `database.yml` |
| Create | `lib/generators/pu/lite/maintenance/maintenance_generator.rb` | `pu:lite:maintenance` — install + schedule the job |
| Create | `lib/generators/pu/lite/maintenance/templates/app/jobs/sqlite_maintenance_job.rb.tt` | The ported maintenance job |
| Modify | `docs/public/templates/lite.rb` | Chain the two new generators after bundle |
| Create | `docs/reference/generators/lite.md` | Reference page for `pu:lite:*` |
| Modify | `docs/.vitepress/config.ts` | Sidebar entry for the new page |
| Create | `test/generators/configures_recurring_test.rb` | Unit tests for `RecurringYAML` |
| Modify | `test/generators/lite_generators_test.rb` | Shape tests for tune + maintenance generators |

---

### Task 1: Extract `ConfiguresRecurring` concern and refactor rails_pulse

**Goal:** Move the env-aware `recurring.yml` injection out of the rails_pulse generator into a reusable, unit-testable concern; rails_pulse keeps identical behavior.

**Files:**
- Create: `lib/generators/pu/lib/plutonium_generators/concerns/configures_recurring.rb`
- Modify: `lib/generators/pu/lite/rails_pulse/rails_pulse_generator.rb`
- Create: `test/generators/configures_recurring_test.rb`

**Acceptance Criteria:**
- [ ] `PlutoniumGenerators::Concerns::ConfiguresRecurring` autoloads (Zeitwerk) and exposes `add_recurring_tasks(tasks_yaml, marker:)`.
- [ ] Nested `RecurringYAML` performs the pure content transform and is tested for env-scoped and flat layouts.
- [ ] rails_pulse generator includes the concern and no longer defines `inject_rails_pulse_under_envs`; its existing tests still pass.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/configures_recurring_test.rb test/generators/lite_generators_test.rb` → all PASS

**Steps:**

- [ ] **Step 1: Write the failing test**

Create `test/generators/configures_recurring_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"
require "generators/pu/lib/plutonium_generators"

class ConfiguresRecurringTest < ActiveSupport::TestCase
  RecurringYAML = PlutoniumGenerators::Concerns::ConfiguresRecurring::RecurringYAML

  ENV_SCOPED = <<~YAML
    production:
      existing_task:
        class: ExistingJob
        schedule: every hour

    development:
      existing_task:
        class: ExistingJob
        schedule: every hour
  YAML

  FLAT = <<~YAML
    existing_task:
      class: ExistingJob
      schedule: every hour
  YAML

  TASKS = <<~YAML
    sqlite_maintenance:
      class: SqliteMaintenanceJob
      schedule: every day at 3:30am
  YAML

  test "injects tasks under every environment in an env-scoped file" do
    result = RecurringYAML.new.inject(ENV_SCOPED, TASKS)

    # one occurrence per environment (production + development)
    assert_equal 2, result.scan(/sqlite_maintenance:/).length
    # nested two spaces under the environment, matching siblings
    assert_match(/^  sqlite_maintenance:$/, result)
    # original tasks preserved
    assert_includes result, "existing_task:"
  end

  test "appends tasks to a flat (non-env-scoped) file" do
    result = RecurringYAML.new.inject(FLAT, TASKS)

    assert_equal 1, result.scan(/sqlite_maintenance:/).length
    # flat layout keeps tasks at column 0
    assert_match(/^sqlite_maintenance:$/, result)
    assert_includes result, "existing_task:"
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/configures_recurring_test.rb`
Expected: FAIL — `uninitialized constant PlutoniumGenerators::Concerns::ConfiguresRecurring`

- [ ] **Step 3: Create the concern**

Create `lib/generators/pu/lib/plutonium_generators/concerns/configures_recurring.rb`:

```ruby
# frozen_string_literal: true

module PlutoniumGenerators
  module Concerns
    module ConfiguresRecurring
      ENV_KEYS = %w[production development staging test].freeze

      # Pure transform of a config/recurring.yml string. No file IO — testable
      # in isolation, mirroring ConfiguresSqlite::DatabaseYAML.
      class RecurringYAML
        # Returns new content with `tasks_yaml` injected. If the file is
        # env-scoped (has top-level production:/development:/... keys), the
        # tasks are inserted under each environment at the siblings' indent.
        # Otherwise they are appended at column 0.
        def inject(content, tasks_yaml)
          if env_scoped?(content)
            inject_under_envs(content, tasks_yaml)
          else
            content.rstrip + "\n\n" + indent(tasks_yaml, 0)
          end
        end

        private

        def env_scoped?(content)
          content.lines.any? { |l| l.match?(env_re) }
        end

        def env_re
          /^(#{ENV_KEYS.join("|")}):\s*$/
        end

        def indent(yaml, n)
          pad = " " * n
          yaml.gsub(/^(?=.)/, pad)
        end

        def inject_under_envs(content, tasks_yaml)
          lines = content.lines
          env_starts = lines.each_with_index.select { |l, _| env_re.match?(l) }.map(&:last)

          env_starts.reverse_each do |start|
            end_idx = lines.length
            ((start + 1)...lines.length).each do |i|
              if lines[i].match?(/^[^\s#]/)
                end_idx = i
                break
              end
            end

            child_indent = 2
            ((start + 1)...end_idx).each do |i|
              if (m = lines[i].match(/^(\s+)\S/))
                child_indent = m[1].length
                break
              end
            end

            insert_at = end_idx
            while insert_at > start + 1 && lines[insert_at - 1].strip.empty?
              insert_at -= 1
            end

            lines.insert(insert_at, "\n", indent(tasks_yaml, child_indent))
          end

          lines.join
        end
      end

      private

      # Inject recurring task YAML into config/recurring.yml. Returns true when
      # written, false when the file is missing or the marker already present
      # (idempotent). `marker` is matched with file_includes? to avoid dupes.
      def add_recurring_tasks(tasks_yaml, marker:)
        recurring_file = "config/recurring.yml"
        full_path = File.expand_path(recurring_file, destination_root)
        return false unless File.exist?(full_path)
        return false if file_includes?(recurring_file, marker)

        new_content = RecurringYAML.new.inject(File.read(full_path), tasks_yaml)
        create_file recurring_file, new_content, force: true
        say_status :recurring, "#{marker} (config/recurring.yml)"
        true
      end
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/configures_recurring_test.rb`
Expected: PASS (2 runs, 0 failures)

- [ ] **Step 5: Refactor rails_pulse to use the concern**

In `lib/generators/pu/lite/rails_pulse/rails_pulse_generator.rb`:

Add the include near the other includes:

```ruby
      include PlutoniumGenerators::Concerns::ConfiguresSqlite
      include PlutoniumGenerators::Concerns::ConfiguresRecurring
      include PlutoniumGenerators::Concerns::MountsEngines
```

Replace the entire `setup_recurring_tasks` method AND the `inject_rails_pulse_under_envs` method with:

```ruby
      def setup_recurring_tasks
        add_recurring_tasks(rails_pulse_tasks_yaml, marker: "rails_pulse")
      end
```

Replace `rails_pulse_tasks_yaml(indent)` (which took an indent arg) with the no-arg version:

```ruby
      def rails_pulse_tasks_yaml
        <<~YAML
          rails_pulse_summary:
            class: RailsPulse::SummaryJob
            queue: default
            schedule: every hour at minute 5
            description: "Roll up Rails Pulse raw records into summary tables"

          rails_pulse_cleanup:
            class: RailsPulse::CleanupJob
            queue: default
            schedule: every day at 1am
            description: "Archive/purge old Rails Pulse data"
        YAML
      end
```

Delete the now-unused private helpers from the file: the old `setup_recurring_tasks` body that read the file / branched on `env_scoped` and called `inject_rails_pulse_under_envs`, and the entire `inject_rails_pulse_under_envs` method. (The `solid_queue_installed?` gate in `start` stays.)

- [ ] **Step 6: Require the concern in the lite generators test loader**

In `test/generators/lite_generators_test.rb`, add to `self.load_generators` (so the rails_pulse require resolves the new concern via Zeitwerk it already does, but add the rails_pulse generator to the loader to cover the refactor):

```ruby
    require "generators/pu/lite/rails_pulse/rails_pulse_generator"
```

- [ ] **Step 7: Run tests to confirm no regression**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/configures_recurring_test.rb test/generators/lite_generators_test.rb`
Expected: PASS

---

### Task 2: `pu:lite:tune` generator (SQLite pragmas)

**Goal:** Add a generator that inserts tuned, version-aware performance pragmas into `config/database.yml`'s `default: &default` block, idempotently.

**Files:**
- Create: `lib/generators/pu/lite/tune/tune_generator.rb`
- Modify: `test/generators/lite_generators_test.rb`

**Acceptance Criteria:**
- [ ] `Pu::Lite::TuneGenerator < Rails::Generators::Base`, includes `PlutoniumGenerators::Generator`.
- [ ] On Rails 8.1+, the inserted pragma block contains exactly the four deltas (`cache_size`, `temp_store`, `mmap_size`, `wal_autocheckpoint`) and no baseline keys.
- [ ] On Rails < 8.1, the block additionally contains the baseline set (`journal_mode`, `synchronous`, `foreign_keys`, `journal_size_limit`).
- [ ] Includes the `busy_timeout` rationale comment and never emits a `busy_timeout` key.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/lite_generators_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Write the failing test**

Add to `test/generators/lite_generators_test.rb` — first add the require in `self.load_generators`:

```ruby
    require "generators/pu/lite/tune/tune_generator"
```

Then add these tests inside the class:

```ruby
  # Test Tune Generator
  test "tune generator exists and has correct namespace" do
    assert defined?(Pu::Lite::TuneGenerator)
    assert Pu::Lite::TuneGenerator < Rails::Generators::Base
  end

  test "tune generator includes PlutoniumGenerators::Generator" do
    assert Pu::Lite::TuneGenerator.include?(PlutoniumGenerators::Generator)
  end

  test "tune pragma block on rails 8.1 contains the four deltas and no baseline" do
    gen = Pu::Lite::TuneGenerator.new([], {}, {})
    block = gen.send(:pragma_block, ::Gem::Version.new("8.1.0"))

    %w[cache_size temp_store mmap_size wal_autocheckpoint].each do |key|
      assert_match(/#{key}:/, block)
    end
    refute_match(/journal_mode:/, block)
    refute_match(/busy_timeout/, block)
    assert_match(/pragmas:/, block)
  end

  test "tune pragma block on rails < 8.1 also contains baseline pragmas" do
    gen = Pu::Lite::TuneGenerator.new([], {}, {})
    block = gen.send(:pragma_block, ::Gem::Version.new("8.0.0"))

    %w[journal_mode synchronous foreign_keys journal_size_limit].each do |key|
      assert_match(/#{key}:/, block)
    end
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/lite_generators_test.rb`
Expected: FAIL — `uninitialized constant Pu::Lite::TuneGenerator`

- [ ] **Step 3: Create the generator**

Create `lib/generators/pu/lite/tune/tune_generator.rb`:

```ruby
# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class TuneGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      desc "Tune config/database.yml with performance pragmas for SQLite"

      RAILS_8_1 = ::Gem::Version.new("8.1.0")
      DATABASE_YML = "config/database.yml"

      def start
        unless File.exist?(File.expand_path(DATABASE_YML, destination_root))
          log :skip, "#{DATABASE_YML} not found"
          return
        end

        if file_includes?(DATABASE_YML, "wal_autocheckpoint")
          log :skip, "pragmas already tuned in #{DATABASE_YML}"
          return
        end

        if file_includes?(DATABASE_YML, /^\s+pragmas:\s*$/)
          # default block already has a pragmas: mapping — add our keys under it
          insert_into_file DATABASE_YML, pragma_keys(rails_version),
            after: /^\s+pragmas:\s*\n/, verbose: false
        else
          insert_into_file DATABASE_YML, pragma_block(rails_version),
            after: /^default: &default\n/, verbose: false
        end
        say_status :tune, "added SQLite pragmas to #{DATABASE_YML}"
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      # Full insertion: comment header + `  pragmas:` line + indented keys.
      def pragma_block(version)
        <<~YAML
          \s\s# Plutonium-tuned SQLite pragmas (pu:lite:tune).
          \s\s# Rails 8.1+ already sets WAL, synchronous=NORMAL, foreign_keys,
          \s\s# mmap=128MB and journal_size_limit by default; only deltas are added
          \s\s# there. We intentionally do NOT set busy_timeout — Rails routes the
          \s\s# `timeout:` key to the sqlite3 gem's constant-poll busy_handler_timeout,
          \s\s# which has better tail-latency than SQLite's internal backoff.
          \s\spragmas:
        YAML
          .gsub(/\\s/, " ") + pragma_keys(version)
      end

      # Just the indented key lines (4-space indent, under pragmas:).
      def pragma_keys(version)
        keys = +""
        if version < RAILS_8_1
          keys << <<~YAML.gsub(/^/, "    ")
            journal_mode: WAL
            synchronous: NORMAL
            foreign_keys: true
            journal_size_limit: 67108864 # 64 MB
          YAML
        end
        keys << <<~YAML.gsub(/^/, "    ")
          cache_size: -64000           # 64 MB page cache (default ~2 MB is too small)
          temp_store: 2                # MEMORY — sorts/temp indexes stay off disk
          mmap_size: 536870912         # 512 MB (override the 128 MB default)
          wal_autocheckpoint: 10000    # checkpoint every ~40 MB of WAL, fewer pauses
        YAML
        keys
      end

      def rails_version
        @rails_version ||= ::Gem::Version.new(Rails::VERSION::STRING).release
      end
    end
  end
end
```

> Implementation note for the executor: the `\s` escapes above are a readable way to keep the 2-space indent visible in the heredoc; if you prefer, write the literal spaces directly and drop the `.gsub(/\\s/, " ")`. What matters is that `pragma_block` returns the comment lines + `  pragmas:` (2-space indent) followed by `pragma_keys` (4-space indent). Verify by eye that the emitted YAML nests `pragmas:` under `default:` and the keys under `pragmas:`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/lite_generators_test.rb`
Expected: PASS

- [ ] **Step 5: Manual sanity check in the dummy app (no commit)**

Run:
```bash
cd test/dummy && cp config/database.yml /tmp/database.yml.bak && \
  bundle exec rails g pu:lite:tune && sed -n '1,20p' config/database.yml; \
  cp /tmp/database.yml.bak config/database.yml
```
Expected: a `pragmas:` block appears nested under `default: &default`; restore leaves the dummy app unchanged. Confirm the YAML still parses: `ruby -ryaml -e 'YAML.load(ERB.new(File.read("config/database.yml")).result)' ` (run from the dummy dir before restoring, if desired).

---

### Task 3: `pu:lite:maintenance` generator (job + schedule)

**Goal:** Add a generator that installs `app/jobs/sqlite_maintenance_job.rb` and schedules it in `config/recurring.yml` via the shared concern.

**Files:**
- Create: `lib/generators/pu/lite/maintenance/maintenance_generator.rb`
- Create: `lib/generators/pu/lite/maintenance/templates/app/jobs/sqlite_maintenance_job.rb.tt`
- Modify: `test/generators/lite_generators_test.rb`

**Acceptance Criteria:**
- [ ] `Pu::Lite::MaintenanceGenerator < Rails::Generators::Base`, includes `PlutoniumGenerators::Generator` and `PlutoniumGenerators::Concerns::ConfiguresRecurring`.
- [ ] Has a `--schedule` option defaulting to `"every day at 3:30am"`.
- [ ] The job template defines `MaintenanceConnection`, `OPTIMIZE_DBS`, and `VACUUM_DBS = %w[primary errors rails_pulse]`, runs `PRAGMA optimize` everywhere and `VACUUM` only on `VACUUM_DBS`, skips missing DBs, and reports errors via `Rails.error.report`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/lite_generators_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Write the failing test**

Add the require to `self.load_generators` in `test/generators/lite_generators_test.rb`:

```ruby
    require "generators/pu/lite/maintenance/maintenance_generator"
```

Add these tests:

```ruby
  # Test Maintenance Generator
  test "maintenance generator exists and has correct namespace" do
    assert defined?(Pu::Lite::MaintenanceGenerator)
    assert Pu::Lite::MaintenanceGenerator < Rails::Generators::Base
  end

  test "maintenance generator includes ConfiguresRecurring concern" do
    assert Pu::Lite::MaintenanceGenerator.include?(PlutoniumGenerators::Concerns::ConfiguresRecurring)
  end

  test "maintenance generator has schedule option defaulting to daily 3:30am" do
    options = Pu::Lite::MaintenanceGenerator.class_options
    assert options.key?(:schedule)
    assert_equal "every day at 3:30am", options[:schedule].default
  end

  test "maintenance job template defines the expected constants and behavior" do
    path = File.expand_path(
      "../../lib/generators/pu/lite/maintenance/templates/app/jobs/sqlite_maintenance_job.rb.tt",
      __dir__
    )
    job = File.read(path)

    assert_includes job, "class MaintenanceConnection < ActiveRecord::Base"
    assert_includes job, "OPTIMIZE_DBS"
    assert_includes job, "VACUUM_DBS = %w[primary errors rails_pulse]"
    assert_includes job, "PRAGMA optimize"
    assert_includes job, "VACUUM"
    assert_includes job, "Rails.error.report"
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/lite_generators_test.rb`
Expected: FAIL — `uninitialized constant Pu::Lite::MaintenanceGenerator`

- [ ] **Step 3: Create the job template**

Create `lib/generators/pu/lite/maintenance/templates/app/jobs/sqlite_maintenance_job.rb.tt`:

```ruby
class SqliteMaintenanceJob < ApplicationJob
  queue_as :default

  # Isolated connection for maintenance. Establishing on this dedicated
  # abstract class (instead of ActiveRecord::Base) means we never mutate
  # the global primary connection — a sibling job on the other worker
  # thread keeps talking to the right database.
  class MaintenanceConnection < ActiveRecord::Base
    self.abstract_class = true
  end

  # Names match the keys in config/database.yml. Add your own database
  # names here if you run extra SQLite databases.
  #
  # PRAGMA optimize is cheap (just refreshes query-planner stats, brief
  # shared lock) so it runs everywhere. Full VACUUM rewrites the file
  # under a global *exclusive* lock for its whole duration, so it only
  # runs on databases without live 24/7 writers.
  OPTIMIZE_DBS = %w[primary queue cache cable errors rails_pulse].freeze

  # queue/cable/cache are deliberately excluded: SolidQueue, Solid Cable
  # and Solid Cache write to them constantly, and a VACUUM lock there
  # stalls (and errors out) those processes — e.g. SolidQueue's process
  # deregistration hitting "database is locked". They also barely benefit:
  # in WAL mode deleted pages land on the freelist and get reused, so a
  # churning DB sits at a steady-state size without nightly reclamation.
  VACUUM_DBS = %w[primary errors rails_pulse].freeze

  def perform
    OPTIMIZE_DBS.each { |db_name| run_maintenance(db_name) }
  end

  private

  def run_maintenance(db_name)
    config = ActiveRecord::Base.configurations.configs_for(
      env_name: Rails.env,
      name: db_name,
      include_hidden: true
    )
    return unless config

    MaintenanceConnection.establish_connection(config)
    MaintenanceConnection.connection_pool.with_connection do |conn|
      Rails.logger.info { "[SqliteMaintenance] PRAGMA optimize on #{db_name}" }
      conn.execute("PRAGMA optimize")

      next unless VACUUM_DBS.include?(db_name)

      Rails.logger.info { "[SqliteMaintenance] VACUUM on #{db_name}" }
      started = Time.current
      conn.execute("VACUUM")
      Rails.logger.info { "[SqliteMaintenance] VACUUM on #{db_name} done in #{(Time.current - started).round(2)}s" }
    end
  rescue => e
    Rails.error.report(e, context: {db: db_name, action: "sqlite_maintenance"})
  ensure
    MaintenanceConnection.remove_connection
  end
end
```

- [ ] **Step 4: Create the generator**

Create `lib/generators/pu/lite/maintenance/maintenance_generator.rb`:

```ruby
# frozen_string_literal: true

require_relative "../../lib/plutonium_generators"

module Pu
  module Lite
    class MaintenanceGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator
      include PlutoniumGenerators::Concerns::ConfiguresRecurring

      source_root File.expand_path("templates", __dir__)

      desc "Install a nightly SqliteMaintenanceJob (PRAGMA optimize + VACUUM)"

      class_option :schedule, type: :string, default: "every day at 3:30am",
        desc: "Cron-style schedule for the maintenance job"

      def start
        template "app/jobs/sqlite_maintenance_job.rb"

        if gem_in_bundle?("solid_queue")
          unless add_recurring_tasks(maintenance_task_yaml, marker: "sqlite_maintenance")
            log :skip, "could not schedule (config/recurring.yml missing or already scheduled)"
          end
        else
          log :info, "solid_queue not found — job installed but not scheduled. Add a 'sqlite_maintenance' entry to your scheduler."
        end
      rescue => e
        exception "#{self.class} failed:", e
      end

      private

      def maintenance_task_yaml
        <<~YAML
          sqlite_maintenance:
            class: SqliteMaintenanceJob
            queue: default
            schedule: #{options[:schedule]}
            description: "VACUUM + PRAGMA optimize across SQLite databases"
        YAML
      end
    end
  end
end
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/lite_generators_test.rb`
Expected: PASS

- [ ] **Step 6: Manual sanity check in the dummy app (no commit)**

Run:
```bash
cd test/dummy && bundle exec rails g pu:lite:maintenance && \
  test -f app/jobs/sqlite_maintenance_job.rb && echo "JOB OK" && \
  grep -q sqlite_maintenance config/recurring.yml && echo "SCHEDULE OK"; \
  git checkout -- app config 2>/dev/null; rm -f app/jobs/sqlite_maintenance_job.rb
```
Expected: `JOB OK` and (if recurring.yml + solid_queue present) `SCHEDULE OK`; dummy app restored afterward.

---

### Task 4: Wire both generators into the `lite.rb` app template

**Goal:** The lite app template runs `pu:lite:tune` right after setup and `pu:lite:maintenance` after the solid/rails_pulse stack.

**Files:**
- Modify: `docs/public/templates/lite.rb`

**Acceptance Criteria:**
- [ ] `pu:lite:tune` is generated immediately after `pu:lite:setup`, with its own commit guard.
- [ ] `pu:lite:maintenance` is generated after the rails_pulse block, with its own commit guard.
- [ ] Only `docs/public/templates/lite.rb` is edited (not the `dist` copies).

**Verify:** `ruby -c docs/public/templates/lite.rb` → `Syntax OK`

**Steps:**

- [ ] **Step 1: Add the tune step after setup**

In `docs/public/templates/lite.rb`, immediately after the `pu:lite:setup` block:

```ruby
  generate "pu:lite:setup"
  git add: "."
  git commit: %( -m 'setup sqlite') if `git status --porcelain`.present?

  generate "pu:lite:tune"
  git add: "."
  git commit: %( -m 'tune sqlite pragmas') if `git status --porcelain`.present?
```

- [ ] **Step 2: Add the maintenance step after the rails_pulse block**

Inside `after_bundle`, after the closing `end` of the `unless ENV["SKIP_RAILS_PULSE"]` block and before the final `end`:

```ruby
  unless ENV["SKIP_SQLITE_MAINTENANCE"]
    generate "pu:lite:maintenance"
    git add: "."
    git commit: %( -m 'add sqlite maintenance job') if `git status --porcelain`.present?
  end
```

- [ ] **Step 3: Verify syntax**

Run: `ruby -c docs/public/templates/lite.rb`
Expected: `Syntax OK`

---

### Task 5: Documentation page + sidebar entry

**Goal:** Add a reference page documenting `pu:lite:tune` and `pu:lite:maintenance` and link it in the VitePress sidebar.

**Files:**
- Create: `docs/reference/generators/lite.md`
- Modify: `docs/.vitepress/config.ts`

**Acceptance Criteria:**
- [ ] `docs/reference/generators/lite.md` documents both generators (purpose, options, idempotency, busy_timeout rationale, VACUUM live-writer exclusion rationale).
- [ ] A sidebar item links to `/reference/generators/lite` near the existing `/reference/app/generators` entry.
- [ ] `yarn docs:build` completes without broken-link errors.

**Verify:** `yarn docs:build` → completes successfully

**Steps:**

- [ ] **Step 1: Create the docs page**

Create `docs/reference/generators/lite.md`:

```markdown
# Lite (SQLite) Generators

The `pu:lite:*` generators configure a SQLite-first production stack. This page
covers the two tuning/maintenance generators; the solid_queue / solid_cache /
solid_cable / solid_errors / litestream / rails_pulse generators are run the
same way (`rails g pu:lite:<name>`).

## `pu:lite:tune`

Adds tuned performance pragmas to the `default: &default` block of
`config/database.yml`.

```bash
rails g pu:lite:tune
```

It writes a `pragmas:` mapping:

- `cache_size: -64000` — 64 MB page cache (the ~2 MB default is too small).
- `temp_store: 2` — MEMORY; sorts and temp indexes stay off disk.
- `mmap_size: 536870912` — 512 MB memory-mapped I/O.
- `wal_autocheckpoint: 10000` — checkpoint roughly every 40 MB of WAL.

On Rails &lt; 8.1 it also writes the baseline pragmas (`journal_mode: WAL`,
`synchronous: NORMAL`, `foreign_keys: true`, `journal_size_limit`) that Rails 8.1+
already sets by default.

**Why no `busy_timeout`?** Rails routes the `timeout:` key to the sqlite3 gem's
constant-poll `busy_handler_timeout`, which has better tail-latency than SQLite's
internal exponential backoff. Setting `busy_timeout` in pragmas would replace the
better handler with the worse one, so this generator never emits it.

The generator is idempotent — re-running it detects the existing pragmas and skips.

## `pu:lite:maintenance`

Installs `app/jobs/sqlite_maintenance_job.rb` and (when `solid_queue` is present)
schedules it in `config/recurring.yml`.

```bash
rails g pu:lite:maintenance
# custom schedule:
rails g pu:lite:maintenance --schedule="every day at 4am"
```

The job runs `PRAGMA optimize` on every configured SQLite database and `VACUUM`
only on databases without live 24/7 writers (`primary`, `errors`, `rails_pulse`
by default — edit `VACUUM_DBS` in the generated job to suit your app).

**Why VACUUM only some databases?** SolidQueue, Solid Cache and Solid Cable write
to their databases constantly. `VACUUM` takes a global *exclusive* lock for its
whole duration, which stalls and errors those processes (e.g. SolidQueue process
deregistration failing with "database is locked"). They also barely benefit: in
WAL mode, freed pages land on the freelist and are reused, so a churning database
stays at a steady-state size without nightly reclamation. `PRAGMA optimize`, which
only takes a brief shared lock, still runs everywhere.

Databases listed in the job that don't exist in `config/database.yml` are skipped
at runtime, so the same job is safe regardless of which `pu:lite:*` generators you
have run.
```

- [ ] **Step 2: Add the sidebar entry**

In `docs/.vitepress/config.ts`, find the line:

```ts
            { text: "Generators", link: "/reference/app/generators" },
```

Add directly after it:

```ts
            { text: "Lite (SQLite) Generators", link: "/reference/generators/lite" },
```

- [ ] **Step 3: Build the docs**

Run: `yarn docs:build`
Expected: build completes; no dead-link errors referencing `/reference/generators/lite`.

---

### Task 6: Full suite + single final commit

**Goal:** Run the full generator test suite, then make one commit containing all changes (per the user's "commit at the end" instruction).

**Files:** none (commit only)

**Acceptance Criteria:**
- [ ] Generator tests pass on Rails 8.1.
- [ ] A single commit contains the two generators, the concern, the rails_pulse refactor, the template change, and the docs.

**Verify:** `git log -1 --stat` shows all the new/modified files in one commit.

**Steps:**

- [ ] **Step 1: Run the generator test suite**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/lite_generators_test.rb test/generators/configures_recurring_test.rb`
Expected: PASS (0 failures, 0 errors)

- [ ] **Step 2: Review the working tree**

Run: `git status` and `git diff --stat`
Expected: only the files listed in this plan's File Structure table appear (plus the spec/plan docs). Confirm no `docs/dist` or `docs/.vitepress/dist` lite.rb copies were hand-edited.

- [ ] **Step 3: Commit everything**

```bash
git add lib/generators/pu/lite/tune \
        lib/generators/pu/lite/maintenance \
        lib/generators/pu/lib/plutonium_generators/concerns/configures_recurring.rb \
        lib/generators/pu/lite/rails_pulse/rails_pulse_generator.rb \
        docs/public/templates/lite.rb \
        docs/reference/generators/lite.md \
        docs/.vitepress/config.ts \
        test/generators/lite_generators_test.rb \
        test/generators/configures_recurring_test.rb \
        docs/superpowers/specs/2026-06-04-sqlite-tune-maintenance-generators-design.md \
        docs/superpowers/plans/2026-06-04-sqlite-tune-maintenance-generators.md
git commit -m "feat(generators/lite): add pu:lite:tune and pu:lite:maintenance for SQLite tuning + maintenance"
```

- [ ] **Step 4: Confirm the commit**

Run: `git log -1 --stat`
Expected: one commit with all the above files.

---

## Self-Review notes

- **Spec coverage:** tune (Task 2), maintenance job + schedule (Task 3), VACUUM list confirm-exists behavior (job template `return unless config` + editable `VACUUM_DBS`), `ConfiguresRecurring` extraction + rails_pulse refactor (Task 1), lite.rb wiring (Task 4), docs page + sidebar (Task 5), version-aware pragmas (Task 2), single commit (Task 6). All spec sections map to a task.
- **Placeholder scan:** none — all code is concrete.
- **Type/name consistency:** `add_recurring_tasks(tasks_yaml, marker:)` and `RecurringYAML#inject(content, tasks_yaml)` used consistently across Tasks 1/3; `pragma_block`/`pragma_keys` consistent in Task 2; `VACUUM_DBS`/`OPTIMIZE_DBS` consistent across Task 3 and the docs.
- **Verification requirement scan:** NO user verification required (automated tests). No verification task needed.
```
