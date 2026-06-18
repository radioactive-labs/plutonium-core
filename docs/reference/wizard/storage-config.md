# Storage & config

The wizard subsystem is DB-backed by a single framework table, gated by an opt-in config flag. This page covers enabling it, the table, configuration, encryption, and the cleanup sweep.

## Enabling the subsystem

Wizards are core code, but the storage table is **opt-in** so apps that don't use wizards stay schema-clean.

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.wizards.enabled = true            # false by default
  config.wizards.cleanup_after = 14.days   # global default idle TTL for the sweep
  config.wizards.database = :primary       # which DB the wizard table lives on (multi-db)
  config.wizards.encrypt_data = true       # encrypt every wizard's data at rest (needs AR encryption keys)
end
```

```bash
rails db:migrate
```

| Config | Default | Meaning |
|---|---|---|
| `config.wizards.enabled` | `false` | The subsystem's master switch. Registers the gem migration (so `rails db:migrate` creates the table) **and** draws wizard routes — both `register_wizard` and the resource-mounted `wizard`-macro actions. While `false`, `register_wizard` is a no-op (it logs a warning so a registered-but-disabled wizard isn't a silent 404) and no wizard routes are mounted. Required to use wizards. |
| `config.wizards.cleanup_after` | `14.days` | Global default idle TTL for the abandonment sweep; overridable per wizard via `cleanup_after`. |
| `config.wizards.database` | `:primary` | Which database connection the wizard table lives on. **v1 supports the primary database only** — see below. |
| `config.wizards.encrypt_data` | `false` | Encrypt **every** wizard's staged `data` at rest by default. Off by default because it needs ActiveRecord encryption keys; a wizard still overrides it individually with `encrypt_data` / `encrypt_data false`. See [Encryption](#encryption). |

## Gem-shipped migration

The migration ships **in the gem** and Rails runs it **in place** — there is no copy-into-your-app step (unlike `pu:rodauth`/`pu:invites`, which are app-customized templates). Enabling `config.wizards.enabled` registers the gem migration path; `rails db:migrate` then runs it.

- Once run, the table is dumped into your `schema.rb` / `structure.sql` like any other, so `db:schema:load` on fresh/CI databases recreates it normally.
- Disable later → the path isn't registered; the existing table is left alone (never auto-dropped).
- `db:migrate:status` shows the migration's file living in the gem (cosmetic; reads "file missing" if the gem is later removed) — standard for gem-shipped migrations.

::: warning v1 supports the primary database only
The wizard table lives on your app's **primary** database in v1. `config.wizards.database` is **reserved for future use** — multi-database routing for wizard sessions is a roadmap follow-up. Setting it to anything other than `:primary` (while wizards are enabled) **raises at boot**, rather than silently registering the migration on the primary database.
:::

## The table — `plutonium_wizard_sessions`

One framework-owned table serves everything; **no changes to your models.**

| Column | Purpose |
|---|---|
| `wizard` | The wizard class name. |
| `status` | `in_progress` \| `completing` \| `completed`. |
| `current_step` | The step cursor. |
| `instance_key` (unique) | The deterministic identity digest (see [Anchoring & resume](/reference/wizard/anchoring-resume#instance-identity)). |
| `owner_type` / `owner_id` | The user (nullable — `null` for an `anonymous`/guest run). Authenticated lookups are owner-scoped against this. |
| `anchor_type` / `anchor_id` | The anchor record (nullable). |
| `scope_type` / `scope_id` | The portal scoping entity / tenant (nullable). |
| `engine` | The portal (engine class name) the run was launched in, e.g. `"OrgPortal::Engine"`. The "continue where you left off" listing only shows — and links — runs whose `engine` matches the portal being viewed (two portals can share an entity scope, so `scope` alone can't identify the portal). |
| `token` | The per-run id for guest/tokened (no-`concurrency_key`) instances (nullable). |
| `data` | Staged field values (JSON; `jsonb` on PostgreSQL). |
| `tracked_records` | GlobalIDs of records registered via `persist`, by step key. Exposed to authors as `persisted[:key]`. |
| `visited` | Visited step keys. |
| `expires_at` | Concrete expiry, stamped `now + cleanup_after` on every write (`nil` = `:never`). |
| `completed_at` | Completion timestamp. |

What the single table powers:

- **Resume** — look up the `in_progress` row by `instance_key`.
- **One-time check** — does a `completed` row exist for `(wizard, owner)` or `(wizard, anchor)`.
- **In-progress listing** — by owner, portal (`engine`), and tenant scope, so a run is only ever listed by the portal it was launched in.
- **Multi-tenancy** — the portal scoping entity is folded into `instance_key` and stored as `scope_*`, so the same user's same non-anchored wizard doesn't collide across tenants.
- **Sweep** — idle `in_progress`/`completing` rows past `expires_at`.

::: tip The `persisted` / `tracked_records` naming
The column is `tracked_records`, not `persisted` — an AR attribute named `persisted` collides with `ActiveRecord::Persistence#persisted?`. The author-facing accessor stays `persisted[:key]`; the store maps it to the column.
:::

## Encryption

A wizard may opt into encrypting its staged field values at rest, for flows that stage PII:

```ruby
class CheckoutWizard < Plutonium::Wizard::Base
  encrypt_data
  # ...
end
```

This encrypts the `data` column (the staged step values) — off by default. The `tracked_records` column (record GlobalIDs only) and the queried `owner`/`anchor`/`scope`/`token` columns stay plaintext.

**Encrypt everything by default.** Once your app has ActiveRecord encryption keys, you can flip encryption on for *all* wizards with one global flag, then override per wizard:

```ruby
config.wizards.encrypt_data = true   # every wizard's `data` is encrypted at rest
```

```ruby
class PublicSurveyWizard < Plutonium::Wizard::Base
  encrypt_data false   # explicit opt-OUT, even when the global default is on
end
```

Resolution: an explicit `encrypt_data` / `encrypt_data false` on the wizard always wins; a wizard that declares neither inherits `config.wizards.encrypt_data` (off unless you set it). It stays opt-in globally because it requires keys — see the warning below.

**How it works.** Because `data` is one shared `jsonb` column across all wizards — some opting in, some not — a static model-level `encrypts :data` doesn't fit (it would encrypt every row, and fights the `jsonb` type). Instead, the store encrypts at write time using **ActiveRecord's configured encryptor** (`ActiveRecord::Encryption.encryptor`, the same keys as `encrypts`) and stores a self-describing envelope inside the column:

```json
{ "_enc": "<ciphertext>" }
```

A row therefore decrypts based on its **own shape**, independent of the wizard's current `encrypt_data?` — so toggling the flag never strands existing runs.

::: warning Requires ActiveRecord encryption keys
`encrypt_data` reuses your app's ActiveRecord encryption keys (`active_record.encryption.primary_key` / `deterministic_key` / `key_derivation_salt`, typically via credentials). If a wizard declares `encrypt_data` but no keys are configured, the **first write raises** a `Configuration` error naming the wizard — rather than ActiveRecord's later, context-free failure. Set the keys (`bin/rails db:encryption:init`) before enabling it.
:::

## Files

File uploads can't sit in the JSON column. Use ActiveStorage direct upload (the existing `uppy` input) and store the blob's `signed_id` in `data` — which also sidesteps the classic "abandoned wizard leaks temp files" problem.

## Cleanup & the SweepJob

`cleanup_after` stamps a concrete `expires_at` (`now + ttl`) on every write, so an actively-progressing wizard keeps pushing its expiry forward. A later change to the wizard's TTL never retroactively shifts existing rows. `cleanup_after :never` stores a null `expires_at`, opting out of sweeping (partial records persist by design).

`Plutonium::Wizard::SweepJob` reaps idle `in_progress` / `completing` rows past `expires_at`: for each it runs the wizard's cleanup (each step's `on_rollback` if declared, then always destroy every tracked record, in reverse order) and deletes the row. Completed rows are never touched. The job is idempotent and safe to re-run.

### SweepJob is load-bearing for save-as-you-go

::: warning Schedule the SweepJob
- For **`execute`-only** wizards, an unscheduled sweep merely leaves stale session rows (harmless).
- For **`on_submit` (save-as-you-go)** wizards, the sweep is the **only** thing that cleans up abandoned real domain records. Without it, partial records accumulate forever.

Schedule `Plutonium::Wizard::SweepJob` as a recurring job (e.g. via your scheduler / cron / `solid_queue` recurring tasks) for any app that uses `on_submit`.
:::

```ruby
# e.g. a recurring job
Plutonium::Wizard::SweepJob.perform_later
```

On completion of a one-time wizard, the row is kept as the durable marker but its `data` / `tracked_records` are nulled out (privacy + size).

## Related

- [Anchoring & resume](/reference/wizard/anchoring-resume) — `instance_key`, resume.
- [DSL reference](/reference/wizard/dsl) — `cleanup_after`, `encrypt_data`, `persist`.
- [One-time wizards](/reference/wizard/one-time) — durable completion markers.
