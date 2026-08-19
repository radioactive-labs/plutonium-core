# Async Interactions

::: warning Experimental
Async interactions are experimental — the DSL and behavior may change in a future release.
:::

For the task-oriented walkthrough — declaring the action, its policy, and where it appears — start with the [Custom actions guide](/guides/custom-actions). This page is the reference.

`async` turns an interaction from "does the work inline" into "persists a run, enqueues it, and redirects to it."

Reach for it once the work stops being something a user can reasonably wait on: archiving ten thousand records, generating a report, calling a third party that takes its time. The run outlives the request, gets a progress page for free, and stays queryable after the fact.

## 🚨 Critical

- **Opt-in and migrated.** `config.async_interactions.enabled = true` + `rails db:migrate` (off by default).
- **`async` replaces `execute` entirely.** The interaction still validates, authorizes and renders its form exactly as before; only what happens on submit changes.
- **Permissions are re-derived at perform time, never replayed from dispatch.** A run created a job, not a snapshot of "what the initiator could do then." See [Authorization](#authorization-is-re-derived-not-replayed).
- **The run itself is a resource.** Register it once per portal (`rails g pu:async_interactions:install --dest=your_portal`); its show page IS its progress page.
- **A stalled run does not silently replay.** `pu:async_interactions:install` schedules `Async::ReapJob` when Solid Queue is in the bundle; on any other scheduler you must add it yourself, or a crash mid-batch leaves the row `"running"` forever. See [Stalled runs](#stalled-runs-and-reapjob).

## Enabling

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.async_interactions.enabled = true
  config.async_interactions.queue = :default        # ActiveJob queue for run jobs
  config.async_interactions.stall_after = 1.hour     # see Stalled runs, below
end
```

```bash
rails db:migrate   # creates plutonium_async_runs
```

The flag gates the migration, not just the behaviour: while it is off the runs migration path is never registered, so the table does not exist. A `async` interaction that runs anyway raises `Plutonium::Interaction::Concerns::Dispatchable::NotEnabledError` naming the flag, rather than a raw "no such table" from inside ActiveRecord.

## Declaring the work

`async` takes a block, and the block is the run's class body. Define `perform_on(record)` for **targeted** work (bulk/record actions, one call per target) or `perform` for **opaque** work (resource actions with no subject):

```ruby
class Blogging::ArchivePosts < ResourceInteraction
  presents label: "Archive", icon: Phlex::TablerIcons::Archive
  attribute :resources          # bulk — perform_on runs once per record
  attribute :reason, :string

  async do
    on_failure :continue        # :halt (default) | :continue | :transactional

    def perform_on(post)
      post.archive!(reason: options["reason"])
    end
  end
end
```

One class. There is no second file, and no name to invent for the run.

### Why the block declares `perform_on` rather than executing

The block is **not** the body of `#execute`. The work happens later, in a job, in a process with no controller, no request and no `view_context` — it cannot be a closure over anything in the interaction, which is the same reason the row records the initiator and tenant instead of serialising them. So the block declares a `Plutonium::Interaction::Async::Run` subclass with exactly the API a standalone run has, and the validated attributes arrive through `options`.

`def` opens a fresh scope, so those method bodies cannot accidentally capture the interaction's locals.

The generated class is named `<Interaction>::Run` rather than left anonymous, because the class name is persisted in the run's `type` column and constantized in another process. An anonymous class would write a row nothing could read back.

| `on_failure` | Behavior when a target raises |
|---|---|
| `:halt` (default) | Stops at the first failure; the run ends `"failed"`, targets after the failure point are never attempted |
| `:continue` | Records the failure, keeps going; the run ends `"completed"` (see [Outcome vs state](#outcome-vs-state) for why that's not the same as a clean success) |
| `:transactional` | Wraps the whole batch in one DB transaction; any failure rolls back everything applied so far |

### Attributes reach the run through `options`

Everything the interaction validated, except the targets, is written to the run's `options` and read back in the job:

```ruby
attribute :reason, :string
async do
  def perform_on(post) = post.archive!(reason: options["reason"])
end
```

`options` is a JSON column, so dispatch writes it through `ActiveJob::Arguments`. Primitives are stored verbatim — a String stays a String in the column — and only values needing one get a serializer envelope, so a `Date` arrives as a `Date` and a `BigDecimal` as a `BigDecimal` rather than as strings. Hosts can register their own serializers.

An attribute that can't be carried at all is refused at dispatch, naming the interaction, rather than being written to a row whose work then fails deep in a job.

### Files

A file can't ride the options column: JSON has no files, and the request's tempfile is deleted on the way out. So an uploaded file is staged to its backend's cache at dispatch and carried as the token — `options["import_file"]` is that token, a String.

Use `attachment` to read it back:

```ruby
class Catalog::ImportProducts < ResourceInteraction
  attribute :import_file

  async do
    def perform
      attachment(:import_file).open do |file|
        CSV.foreach(file, headers: true) { |row| Catalog::Product.create!(row.to_h) }
      end
    end
  end
end
```

`attachment(:key)` returns one, `attachments(:key)` all of them for a multiple-file attribute, each exposing `filename`, `content_type`, `url`, `open` and `download`. Reviving reaches storage, so it is not folded into `options`: the progress page reads options on every poll and has no need of the file.

#### Per-field backend and uploader

`backend:` and `uploader:` are read off the attribute's own `input` declaration — the same options, in the same place, a wizard step reads them from:

```ruby
attribute :import_file
input :import_file, as: :uppy, uploader: Catalog::ImportUploader
```

The uploader's `Attacher.validate` rules run when the interaction validates, so a file that breaks them **fails the form** — the submitter sees a field error and nothing is dispatched. Without that the interaction would validate clean, dispatch, and the author's `validate_max_size` would surface as a run failure on a page the submitter has already left. A no-op for ActiveStorage fields and for uploaders declaring no rules.

Validating means staging first, since Shrine validates an assigned cached file — so an upload that fails validation has still been written to the cache, and is reaped by the backend's own unattached-cache cleanup. Wizards make the same trade on every step submit.

Where no `backend:` is declared: `config.async_interactions.attachment_backend`, then `config.attachment_backend`, then auto-detection (active_shrine loaded → Shrine, else ActiveStorage). Same layering wizards use.

### Sharing one run across interactions

Pass a class instead of a block when several interactions do the same kind of work:

```ruby
class Blogging::ArchivePostsRun < Plutonium::Interaction::Async::Run
  on_failure :continue
  def perform_on(post) = post.archive!
end

class Blogging::ArchivePosts < ResourceInteraction
  async Blogging::ArchivePostsRun
  attribute :resources
end
```

Passing both a class and a block raises `ArgumentError` — the block *is* a run class, so there is nothing to combine.

`async` must be the only thing that defines `#execute` on the class. Declaring it on a class that already has its own `execute` raises `ArgumentError` at load time (an interaction either executes inline or runs async, never both).

## What gets recorded at dispatch

Nothing is passed in explicitly. Everything the run needs is already reachable from the interaction's own state:

- **Targets.** `attribute :resource` / `attribute :resources`, already narrowed by the controller's policy scope, stored as ids (`target_ids`) and re-resolved at perform time, never serialized as records.
- **Initiator + tenant.** `current_user` / `current_scoped_entity`, two of the things every Plutonium policy authorizes on.
- **Nested-route parent.** `current_parent` and `current_nested_association` — `/orgs/1/posts/5/comments` records `(Post#5, :comments)`. Both halves or neither, since `Policy#default_relation_scope` raises on one alone. This is the third policy input, and it is not optional detail: that method picks **one** branch, parent *or* entity, so a nested run without its parent re-derives targets under the tenant where dispatch used the parent — wider than the scope the initiator was shown. It also leaves a host predicate reading `parent` looking at `nil`, which (being declared `optional: true`) answers false rather than raising, refusing every target for a reason that names the predicate instead of the missing context.
- **The policy actually resolved.** `policy_class_name`, not an inferred `"#{Model}Policy"` (a namespaced portal or an STI fallback would make that guess wrong), plus `policy_action`, the predicate dispatch checked (e.g. `"archive?"`).
- **`authorization_namespace`.** The portal's module name, so perform-time policy lookup finds the same narrowed policy dispatch did.

An opaque (untargeted) run records none of the target/policy columns: there's no subject to check, so there's nothing to re-verify.

## Authorization is re-derived, not replayed

The job has no controller, no request, no `current_user`. `Async::Context` rebuilds the authorization triple from the row and re-checks it from scratch. It does not trust anything the dispatching request already decided:

- The **scope** check re-runs `Post.associated_with(tenant)` style filtering — or, for a nested dispatch, the parent's association. A target that left the tenant or the parent, or was deleted, between dispatch and perform is reported `missing`/`unauthorized`, never silently skipped.
- The **predicate** check re-asks the policy the same question dispatch asked (`policy_action`), per target, immediately before `perform_on`, not once up front. An initiator whose permission was revoked mid-run stops applying to the remaining targets.
- A **policy mismatch** (the class renamed/re-parented/re-namespaced since dispatch) refuses to run at all, rather than silently authorizing under a different policy than the initiator was ever subject to.
- A **deleted subject** — initiator, tenant or parent — refuses the run. In each case the association nils out, and nil reads as "there was never one": no tenant, or not a nested dispatch. Both of those drop a filter rather than narrowing, so the `*_type` column is what tells "carries none" apart from "carries one that is gone".

This is deliberate and asymmetric: a resolution failure always fails **closed** (refuse / report missing), never open (never "assume permitted").

## Outcome vs state

Read `run.outcome`, not `run.state`, when displaying or branching on the result. A `:continue` run that couldn't apply every target still ends with `state == "completed"`, since the author declared partial application acceptable. `outcome` is what distinguishes that from a clean pass:

```ruby
run.state    # "completed"
run.outcome  # "completed_with_errors"   (state == "completed" && errors_log.any?)
```

The progress page, the table's `outcome` column, and the running banner all render `outcome`, never bare `state`.

## Registering the Run resource

Register it once per portal so its show page becomes routable:

```bash
rails g pu:async_interactions:install --dest=admin_portal
```

```ruby
# packages/admin_portal/config/routes.rb
register_resource ::Plutonium::Interaction::Async::Run
```

```ruby
# packages/admin_portal/app/controllers/admin_portal/async_runs_controller.rb
class AdminPortal::AsyncRunsController < AdminPortal::ResourceController
  controller_for ::Plutonium::Interaction::Async::Run

  include AdminPortal::Concerns::Controller
end
```

`controller_for` is required: the controller's name doesn't match `Run`'s real, namespaced class, so inference can't find it on its own. No policy/definition files are generated: `Plutonium::Interaction::Async::RunPolicy`/`Async::RunDefinition` already resolve automatically (Rails matches `Plutonium::Interaction::Async::RunDefinition` by the exact class name, and ActionPolicy's own lookup finds `AsyncRunPolicy` the same way).

If Solid Queue is in the bundle, this also schedules `Async::ReapJob` in `config/recurring.yml` (`--schedule` to override the default `every 15 minutes`) — see [Stalled runs and ReapJob](#stalled-runs-and-reapjob). Idempotent, so running the generator against a second portal doesn't duplicate the entry.

A registered run resource gets, for free:

- **A progress page.** The show page IS the progress page. It self-refreshes via polling (not ActionCable) while `state` is `pending`/`running`, and stops carrying the poll once the run settles, so a finished run is a static page, not a background request per viewer.
- **A running banner.** Any OTHER resource's index page lists runs currently in progress against it, above the collection, so a user who dispatched a bulk action and navigated away can find it again. Scoped through the same `authorized_resource_scope` every cross-resource read goes through, so a run in another tenant can never surface. If a resource_class is registered in a portal that never registered `Run`, the banner is skipped there instead of raising while trying to build a link to a route that doesn't exist.
- **Tenant scoping.** A run's `associated_with` scope filters on the tenant it was dispatched in (recorded on the row), not on walking the object graph, since the two polymorphic tenant columns make the generic scope unusable.
- **A humanized target label.** `run.target_label` reads the target class through `model_name.human` ("Post", not "Blogging::Post"), falling back to the raw string if that class has since been renamed or removed.

## Stalled runs and ReapJob

A worker crash mid-batch (or a job the queue silently drops) leaves a run `"running"` (or `"pending"`) forever; nothing else ever revisits it on its own. `Plutonium::Interaction::Async::ReapJob` finds runs with no recorded activity (`last_activity_at`, falling back to `created_at` for a run never even picked up) past `config.async_interactions.stall_after`, and resumes them: resets to `"pending"` and re-enqueues.

This is safe, not a replay. The executor tracks `handled_target_ids` (every target already dispositioned, success or failure) and resumes only the remainder, so a target already applied before the interruption is not redone.

`rails g pu:async_interactions:install` schedules this for you when Solid Queue is in the bundle:

```yaml
# config/recurring.yml (Solid Queue)
production:
  reap_stalled_async_runs:
    class: Plutonium::Interaction::Async::ReapJob
    schedule: every 15 minutes
```

Without Solid Queue — or for another scheduler like `whenever` — add it yourself:

```ruby
# whenever gem
every 15.minutes do
  runner "Plutonium::Interaction::Async::ReapJob.perform_later"
end
```

A 15 to 30 minute cadence is reasonable against the default 1-hour `stall_after`: frequent enough that a stalled run doesn't sit for long, with enough margin that clock jitter doesn't matter.

::: warning This is a time heuristic, not a lease
Resuming is based on elapsed time, not a true distributed lock. A run that is merely slow (not dead) and happens to cross `stall_after` gets resumed too.

What bounds that is `lock_version`. Both the reaper's resume and the executor's claim bump it, so the worker that is still alive holds a version the row no longer has: its very next write raises `ActiveRecord::StaleObjectError`, and the executor treats that as "no longer mine" — it abandons the pass without marking the run failed and without overwriting the new worker's progress. Two things it deliberately does not do: it cannot interrupt a `perform_on` already in flight, so one target may be applied twice (once by each side), and it cannot roll back what the superseded worker already committed. Set `stall_after` well above this app's slowest legitimate run — the fence bounds the damage of a bad value, it does not make one free.

### Long work must say it is alive

`stall_after` is a **silence** threshold, not a runtime limit. Every write the executor makes refreshes the clock, so a targeted run with quick targets heartbeats once per target for free. Two shapes get nothing, and both are exactly the "long-running task" case:

- **Opaque work.** Between the claim and `finish!` the executor writes nothing, because there is nothing to count. A `perform` that outlives `stall_after` is reaped mid-flight and — having no `handled_target_ids` to resume from — re-runs **from scratch**.
- **A single `perform_on`** that outlives `stall_after` on its own.

Call `heartbeat!` from inside such work:

```ruby
class Billing::ReissueInvoicesRun < Plutonium::Interaction::Async::Run
  def perform
    invoices.each_slice(500) do |slice|
      reissue(slice)
      heartbeat!        # "still working" — resets the stall clock
    end
  end
end
```

This is deliberately not automatic. A background thread would have to guess a cadence, and would go on reporting a wedged worker as healthy; only the work itself knows it is making progress.

`heartbeat!` also **answers**. The write is conditional on this worker still holding the row's `lock_version`, so one that was superseded inside a long `perform` raises `ActiveRecord::StaleObjectError` at its next beat and abandons the pass — for opaque work that is the only place it can find out before `finish!`. Under `:transactional` the beat is inside the batch transaction like everything else, so it stays invisible to the reaper until the batch commits.

### Queue-level concurrency

On a queue that provides ActiveJob concurrency controls — Solid Queue does, whenever it is in the bundle — the run job also declares a per-run semaphore, and the reaper a global one:

| Job | Key | Limit | Duration |
|---|---|---|---|
| `Async::Job` | the run's id | 1 | `config.async_interactions.stall_after` |
| `Async::ReapJob` | constant | 1 | Solid Queue's default |

This is declared only when the method exists; Plutonium depends on no queue backend, and nothing above requires one.

It is not a second copy of the claim. `claim!` can only *refuse* a duplicate delivery, and only once a worker is already running it — by which point a reaper's resume has re-entered `perform_on` for one target. The semaphore removes the race a step earlier: the second delivery waits instead of racing, so on a queue that supports it the double-applied target does not happen at all. Keying the run job on `stall_after` matters here — Solid Queue's 3-minute default would expire the semaphore mid-batch on any run big enough to be worth dispatching.
:::

## Related

- [Interactions](/reference/behavior/interactions) — `async` is declared inside `Plutonium::Resource::Interaction`; everything else about inputs, validation and outcomes is unchanged.
- [Policies](/reference/behavior/policies) — the policy dispatch checks and the job re-checks are the same predicate.
