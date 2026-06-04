# SQLite Tuning & Maintenance Generators — Design

**Date:** 2026-06-04
**Status:** Approved (design); pending implementation plan

## Summary

Port two production-proven SQLite improvements from `radioactive_labs/universal_chatbot`
into the Plutonium generator template:

1. **Config tuning** — performance pragmas in `config/database.yml`.
2. **Maintenance** — a scheduled `SqliteMaintenanceJob` (`PRAGMA optimize` everywhere,
   `VACUUM` on safe databases only).

Both ship as **two new generators** under the existing `pu:lite` namespace:
`pu:lite:tune` and `pu:lite:maintenance`. The existing `pu:lite:setup` generator is
left untouched.

## Background

### What the reference project does

`config/database.yml` `default: &default` block carries tuned pragmas:

```yaml
pragmas:
  cache_size: -64000           # 64 MB page cache (default ~2 MB is too small)
  temp_store: 2                # MEMORY — sorts/temp indexes stay off disk
  mmap_size: 536870912         # 512 MB (override the 128 MB default)
  wal_autocheckpoint: 10000    # checkpoint every ~40 MB of WAL, fewer pauses
```

It deliberately does **not** set `busy_timeout` — Rails routes the `timeout:` key to
the sqlite3 gem's constant-poll `busy_handler_timeout`, which has better tail-latency
than SQLite's internal backoff. Adding `busy_timeout` to pragmas would replace that with
the worse handler.

`app/jobs/sqlite_maintenance_job.rb` runs nightly via `config/recurring.yml`:

- Uses an isolated abstract connection class (`MaintenanceConnection`) so it never
  mutates the global primary connection that sibling jobs rely on.
- `PRAGMA optimize` on all databases (cheap, brief shared lock).
- `VACUUM` only on databases without live 24/7 writers. Excludes `queue`/`cache`/`cable`
  because SolidQueue / Solid Cache / Solid Cable write to them constantly, and VACUUM's
  global exclusive lock stalls and errors those processes (e.g. SolidQueue process
  deregistration hitting "database is locked"). This is the `2b813bdd` fix
  ("stop nightly VACUUM from locking the live queue DB").
- Errors are reported via `Rails.error.report` and the connection is always removed in
  an `ensure` block.

### Current Plutonium state

- `pu:lite:setup` only ensures the `sqlite3` gem version and adds the Rails 7 enhanced
  adapter. **No pragma tuning.**
- `pu:lite:*` generators (solid_queue, solid_cache, solid_cable, solid_errors,
  rails_pulse, litestream) wire up extra databases via the `ConfiguresSqlite` concern.
- `rails_pulse_generator.rb` already contains working, env-aware `config/recurring.yml`
  injection logic (handles both env-scoped and flat recurring files).
- **No pragma tuning and no maintenance job exist in the template today.**

## Design Decisions (confirmed)

| Decision | Choice |
|---|---|
| Packaging | Two new generators: `pu:lite:tune`, `pu:lite:maintenance`. `pu:lite:setup` untouched. |
| Pragma values | Port reference values **verbatim**. |
| VACUUM target selection | Editable list in the generated job; runtime confirms each DB exists (`configs_for ... return unless config`); user can extend the list. |
| `recurring.yml` editing | Extract the rails_pulse injection logic into a shared `ConfiguresRecurring` concern; rails_pulse refactored to use it. |
| Generator names | `pu:lite:tune` and `pu:lite:maintenance` (confirmed). |

## Component 1: `pu:lite:tune`

**File:** `lib/generators/pu/lite/tune/tune_generator.rb`

**Purpose:** Insert tuned performance pragmas into `config/database.yml`'s
`default: &default` block.

**Behavior:**

- Locate the `default: &default` mapping in `config/database.yml`.
- If a `pragmas:` key already exists under `default`, merge our keys, skipping any key
  already present (no clobbering user values).
- If no `pragmas:` key exists, insert a new `pragmas:` block containing the four reference
  deltas plus the reference's explanatory comments, including the `busy_timeout` note.
- **Version-aware pragma set:**
  - Rails **8.1+**: write only the four deltas (`cache_size`, `temp_store`, `mmap_size`,
    `wal_autocheckpoint`) — Rails already sets WAL / synchronous=NORMAL / foreign_keys /
    mmap=128MB / journal_size_limit by default.
  - Rails **< 8.1**: also emit the baseline set (`journal_mode: WAL`,
    `synchronous: NORMAL`, `foreign_keys: true`, `journal_size_limit`) since these are not
    guaranteed there. The Rails 7 path already pulls in
    `activerecord-enhancedsqlite3-adapter` via `pu:lite:setup`, which supports pragmas.
- **Idempotent:** re-running skips keys already present; a marker (the comment header or
  the presence of our keys) prevents duplicate insertion.
- Emits `say_status` lines for each key added.

**Reuse:** YAML location/insertion can lean on the existing `ConfiguresSqlite` concern's
file-manipulation helpers (`insert_into_file`, regex anchors) and `file_includes?`. The
default-block anchor is matched the same way the concern matches `default: &default`.

## Component 2: `pu:lite:maintenance`

**File:** `lib/generators/pu/lite/maintenance/maintenance_generator.rb`
**Template:** `lib/generators/pu/lite/maintenance/templates/app/jobs/sqlite_maintenance_job.rb.tt`

**Purpose:** Install `SqliteMaintenanceJob` and schedule it in `config/recurring.yml`.

**Behavior:**

- `template` the job to `app/jobs/sqlite_maintenance_job.rb`, ported from the reference:
  - Isolated `MaintenanceConnection < ActiveRecord::Base` (`abstract_class = true`).
  - `OPTIMIZE_DBS` and `VACUUM_DBS = %w[primary errors rails_pulse]` as **editable
    constants**, with comments instructing the user to add their own DB names.
  - At runtime, `configs_for(env_name:, name:, include_hidden: true)` returns the config
    or nil; `return unless config` silently skips DBs that don't exist — this is the
    "keep a list, confirm they exist" behavior.
  - `PRAGMA optimize` on every `OPTIMIZE_DBS` entry; `VACUUM` only on `VACUUM_DBS`.
  - Preserve the live-writer exclusion rationale (queue/cache/cable) as comments.
  - `rescue => e` → `Rails.error.report(e, context: {...})`; `ensure` removes the
    connection.
- Add the recurring entry to `config/recurring.yml` using the shared
  `ConfiguresRecurring` concern (see below):
  ```yaml
  sqlite_maintenance:
    class: SqliteMaintenanceJob
    queue: default
    schedule: every day at 3:30am
    description: "VACUUM + PRAGMA optimize across SQLite databases"
  ```
- **Gating:** if solid_queue is not installed or `config/recurring.yml` is absent, still
  write the job file but log that no scheduler was found (mirrors rails_pulse's
  `solid_queue_installed?` gate).
- **Idempotent:** skip the recurring injection if `sqlite_maintenance` is already present;
  `template` with conflict handling for the job file.

## Component 3: `ConfiguresRecurring` concern (refactor)

**File:** `lib/generators/pu/lib/plutonium_generators/concerns/configures_recurring.rb`

Extract the env-aware `recurring.yml` injection currently private to
`rails_pulse_generator.rb` into a reusable concern. Concerns are autoloaded by Zeitwerk
(`Zeitwerk::Loader.for_gem` in `lib/generators/pu/lib/plutonium_generators.rb`), so a new
file at the conventional path with module nesting
`PlutoniumGenerators::Concerns::ConfiguresRecurring` is picked up automatically — no
manual `require` needed. Public surface:

```ruby
# Inject one or more recurring task blocks into config/recurring.yml,
# handling both env-scoped (production:/development:) and flat layouts.
add_recurring_tasks(tasks_yaml, marker:)
```

- `tasks_yaml`: the YAML body for the task(s), without leading indentation (the concern
  re-indents per environment, as the existing code does).
- `marker`: a string used for the `file_includes?` idempotency guard (e.g.
  `"rails_pulse"`, `"sqlite_maintenance"`).
- Internals are the existing `inject_*_under_envs` / indent-detection logic, generalized
  to accept arbitrary task YAML instead of hardcoded rails_pulse tasks.

`rails_pulse_generator.rb` is refactored to call `add_recurring_tasks` with its existing
task YAML and `marker: "rails_pulse"`. No behavior change.

## Testing

Add to `test/generators/` (alongside `lite_generators_test.rb`,
`configures_sqlite_test.rb`):

- **`pu:lite:tune`:**
  - Inserts the `pragmas:` block with the four delta keys into the `default` anchor.
  - Re-running is idempotent (no duplicate keys).
  - Merges into an existing `pragmas:` block without clobbering user-set keys.
  - (If feasible in the harness) version-aware: Rails < 8.1 emits the baseline set.
- **`pu:lite:maintenance`:**
  - Creates `app/jobs/sqlite_maintenance_job.rb` with the expected constants.
  - Injects the `sqlite_maintenance` entry under each environment in an env-scoped
    `recurring.yml`; idempotent on re-run.
  - When `recurring.yml` is absent, writes the job and logs the missing-scheduler notice.
- **`ConfiguresRecurring`:** the extracted concern behaves identically to the old
  rails_pulse path (regression guard) — verify via the existing rails_pulse test still
  passing plus a focused concern test.

## App template integration (`lite.rb`)

`docs/public/templates/lite.rb` is the SQLite-stack app template that chains the
`pu:lite:*` generators `after_bundle` (setup → solid_queue/cache/cable/errors →
litestream → rails_pulse), each followed by a conditional git commit.

Wire **both** new generators into this template, matching the existing pattern (each with
its own `git add` / `git commit` guard):

- `pu:lite:tune` — immediately after `pu:lite:setup` (pragmas belong with the base SQLite
  config, before the extra DBs are added).
- `pu:lite:maintenance` — after the solid stack and rails_pulse, so the extra databases
  exist and `solid_queue` is present for scheduling.

Only edit the source template at `docs/public/templates/lite.rb`; the copies under
`docs/dist/` and `docs/.vitepress/dist/` are build artifacts regenerated by
`yarn docs:build`.

## Documentation

- New standalone page **`docs/reference/generators/lite.md`** describing the `pu:lite:*`
  generators, with full sections for `pu:lite:tune` and `pu:lite:maintenance` (purpose,
  options, idempotency, the `busy_timeout` rationale, and the VACUUM live-writer
  exclusion rationale). Documenting the other existing `pu:lite:*` generators on this page
  is a nice-to-have but the two new ones are required.
- Add the new page to the VitePress sidebar in `docs/.vitepress/config.ts` (near the
  existing `/reference/app/generators` entry) so it is reachable.
- Skills require a gem release to take effect; a skill update is **out of scope** for this
  change (docs page + sidebar only).

## Out of scope (YAGNI)

- App-specific extras from the reference (`sqlite_vec` extension loading, per-app
  cleanup jobs, Rails Pulse summary/cleanup jobs) — those belong to their own generators
  or the app, not this port.
- Changing `pu:lite:setup` behavior.
- Litestream / backup concerns (separate `pu:lite:litestream` generator already exists).

## File change list

| Action | Path |
|---|---|
| Create | `lib/generators/pu/lite/tune/tune_generator.rb` |
| Create | `lib/generators/pu/lite/maintenance/maintenance_generator.rb` |
| Create | `lib/generators/pu/lite/maintenance/templates/app/jobs/sqlite_maintenance_job.rb.tt` |
| Create | `lib/generators/pu/lib/plutonium_generators/concerns/configures_recurring.rb` |
| Modify | `lib/generators/pu/lite/rails_pulse/rails_pulse_generator.rb` (use shared concern) |
| Modify | `docs/public/templates/lite.rb` (chain `pu:lite:tune` + `pu:lite:maintenance`) |
| Create | `test/generators/tune_generator_test.rb` (or extend `lite_generators_test.rb`) |
| Create | `test/generators/maintenance_generator_test.rb` (or extend `lite_generators_test.rb`) |
| Create | `docs/reference/generators/lite.md` |
| Modify | `docs/.vitepress/config.ts` (sidebar entry for the new page) |

> Zeitwerk autoloads concerns by path, so no edit to
> `lib/generators/pu/lib/plutonium_generators.rb` is required for the new concern.
> The `docs/dist/` and `docs/.vitepress/dist/` copies of `lite.rb` are build artifacts —
> do not hand-edit them.
