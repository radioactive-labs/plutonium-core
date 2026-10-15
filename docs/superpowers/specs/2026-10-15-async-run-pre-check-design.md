# Async run pre_check

**Status:** approved design, not yet planned
**Date:** 2026-10-15
**Area:** `lib/plutonium/interaction/async/`

## Problem

An async run has no stage for refusing its input. Cheap file checks already run
synchronously (the uploader's `Attacher.validate` rules run during interaction
validation, so a wrong type or size fails the form). Checks too slow or too deep
for a request have nowhere to go: parsing a 50k-row CSV, checking its headers,
validating every row, looking up referenced records. Today the only option is to
raise inside `perform`, which reads as a crash partway through and gives the user
one problem per attempt.

## Decisions

| Question | Decision |
|---|---|
| After the check passes | Processing starts in the same job. No confirmation step. |
| Reporting problems | Collect every problem, then reject the run if any were recorded. |
| How a rejected run reads | `state` stays `failed`; `outcome` reads `rejected`. |
| Declaration style | A plain method in the run class, like `perform` / `perform_on`. |
| Cap on stored problems | Configurable, `config.async_interactions.max_rejections`, default 100. |

## API

```ruby
async do
  def pre_check
    attachment(:import_file).open do |f|
      CSV.foreach(f, headers: true).with_index(2) do |row, line|
        reject "line #{line}: missing email" if row["email"].blank?
        heartbeat! if (line % 1_000).zero?
      end
    end
  end

  def perform
    # only runs if pre_check rejected nothing
  end
end
```

A targeted run's check receives the resolved, authorized records:

```ruby
async do
  def pre_check(invoices)
    currencies = invoices.map(&:currency).uniq
    reject "mixed currencies: #{currencies.join(", ")}" if currencies.size > 1
  end

  def perform_on(invoice)
    invoice.reissue!
  end
end
```

### `Run#pre_check` / `Run#pre_check(records)`

- Optional. The base class defines a no-op, so existing runs are unaffected.
- Invoked through `send`, matching how `perform` / `perform_on` are invoked, so a
  private definition works.
- Arguments follow the run's shape: none for opaque work, the resolved records for
  targeted work. A definition with the wrong arity fails the run with a message
  naming the class and the expected signature.

### `Run#reject(message)`

- Records one problem and returns, so the check can report every bad row in one
  pass.
- Valid only while `pre_check` runs. Called from `perform`, `perform_on`, or
  anywhere else it raises, since a rejection nothing reads would be lost.

## Execution

In `Async::Executor`, after `claim!`:

- **Opaque:** `pre_check` → `perform` → `finish!`
- **Targeted:** resolve targets → `record_unresolved` and the existing partial-batch
  refusal for `:halt` / `:transactional` → `pre_check(resolved.records)` → the
  per-target loop (or the transactional batch) → `finish!`

`pre_check` sees only the records the loop is about to process. Missing or
unauthorized ids are already recorded failures by then.

After `pre_check` returns:

- **Nothing rejected:** processing starts.
- **Anything rejected:** the executor calls `Run#reject_run!(messages, overflow:)`. `perform` /
  `perform_on` never run, no target is touched, and `progress_done` stays 0.

An exception raised inside `pre_check` takes the existing failure path in
`Executor#call`. That run reads `failed`, not `rejected`: "your input is wrong" and
"the check itself broke" are different reports.

## Recording

No migration.

Each rejection becomes an `errors_log` entry:

```ruby
{"target_id" => nil, "message" => "line 12: missing email", "stage" => "pre_check"}
```

- A nil `target_id` is already the run-level sentinel, so progress counters and
  `handled_target_ids` are untouched.
- `stage` is a new key. Entries written before it have none, and current readers
  ignore unknown keys.

`Run#reject_run!(messages, overflow:)` writes the entries and `state: "failed"`,
`finished_at`, `last_activity_at` in one `update!`, so a crash cannot leave a
failed run without its reasons or reasons on a run still marked running (the same
reasoning as `record_target_failures!`).

### Cap

- Only the first `max_rejections` messages are stored.
- When more were rejected, one extra entry (also `stage: "pre_check"`) records the
  remainder: "and 4900 more problems were found"
  (`plutonium.async.executor.rejections_truncated`, `one` / `other`).
- `Async::Configuration#max_rejections`, default `100`. Not added to the install
  generator's initializer template; documented with the other settings.
- The cap is applied in `reject`: it stores at most `max_rejections` messages and
  counts the rest, so memory stays bounded and the remainder is exact.
  `reject_run!` receives the stored messages and the overflow count.

## Outcome and display

- `Run#outcome` returns `"rejected"` when `state == "failed"` and any `errors_log`
  entry has `"stage" => "pre_check"`. A completed run can never carry such an
  entry.
- `state` stays `failed`, so `ReapJob`, `in_progress`, the running banner and the
  poll-stop logic are unchanged.
- **Badge:** `rejected: :warning` in the `display :outcome` and `column :outcome`
  declarations in `RunDefinition`, and in `BADGE_VARIANTS` in
  `lib/plutonium/ui/interaction/async/run_progress.rb`. Warning, not danger: the
  input was refused and nothing broke.
- **Badge text:** the existing `Plutonium::Translation.value_label` lookup
  (`plutonium.values.*`), falling back to "Rejected".
- **Progress panel:** a rejected run shows "Nothing was processed"
  (`plutonium.async.progress.rejected`) above the failures list, so "0 of 50
  targets" does not read as a run that died at its first target.
- **Failures list:** unchanged. Entries with a nil `target_id` already render
  without the `#id:` prefix.

## Edge cases

- **Resume after a reap:** A resumed opaque run re-runs `pre_check` then
  `perform` from the start (as opaque work already does). A resumed targeted run
  skips the check if an earlier pass applied a target (a handled id with no
  failure entry; failed targets do not count), since targets are only performed
  after the check passes. Otherwise it checks only the unhandled records.
  Skipping keeps a half-applied run from being rejected as "nothing was
  processed".
- **`:transactional`:** `pre_check` runs before the transaction opens. A rejected
  batch never opens one.
- **Heartbeat:** the executor writes nothing while `pre_check` runs. A long check
  must call `heartbeat!`, as opaque `perform` must today.
- **Reaped mid-check:** `heartbeat!` and `reject_run!` both raise
  `ActiveRecord::StaleObjectError` against a superseded row. `Executor#superseded?`
  already turns that into "no longer mine".

## Testing

**Executor (`test/plutonium/interaction/async/executor_test.rb`)**
- Opaque and targeted runs pass the check, then perform.
- A rejection stops `perform` / `perform_on`; `progress_done` stays 0; outcome is
  `rejected`.
- Several rejections are all recorded.
- The cap: `max_rejections` respected, plus the "and N more" entry with the exact
  remainder.
- An exception raised in `pre_check` reads `failed`, not `rejected`.
- A wrong-arity `pre_check` fails with a message naming the expected signature.
- `reject` outside `pre_check` raises.
- A resumed targeted run's check receives only the remaining records.
- A `:transactional` run is rejected without opening a transaction.

**Run (`test/plutonium/interaction/async/run_test.rb`)**
- `outcome` reads `rejected` from tagged entries; entries without `stage` are
  unaffected.
- `reject_run!` writes entries and state in one update.

**Integration (`test/integration/admin_portal/`)**
- The progress page shows the Rejected badge, the "Nothing was processed" line and
  the messages; the index shows the badge.

**Dummy app**
- An opaque CSV import interaction in the admin portal, backing the integration
  test and the docs example. Hand-authored: there is no interaction generator.

## Docs

- `docs/reference/behavior/async-interactions.md`: a "Checking input before
  processing" section; `max_rejections` with the other settings.
- `.claude/skills/plutonium-async-interactions/SKILL.md`: a matching section, and
  `pre_check` added to the heartbeat warning in Critical.
- Every sample checked against the implementation before it is published.

## Out of scope

- A confirmation step between check and processing.
- Excluding individual targets from the check and processing the rest (the
  `:continue` failure policy covers per-target failures).
- Progress reporting for opaque work.
