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
constant-poll busy handler (`busy_handler_timeout`), which has better tail-latency
than SQLite's internal exponential backoff. Setting a busy-timeout pragma would
replace the better handler with the worse one, so this generator never emits it.

The generator is idempotent — re-running it detects the existing pragmas and skips.
It only ever touches the `default:` block, so a `pragmas:` mapping nested under
another environment is left untouched.

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

If `solid_queue` is not installed, the job file is still created but not scheduled —
add a `sqlite_maintenance` entry to whatever scheduler you use.
