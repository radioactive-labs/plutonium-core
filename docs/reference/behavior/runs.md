# Async Interactions (Runs)

`dispatches_to` turns an interaction from "does the work inline" into "persists a run, enqueues it, and redirects to it." Use it for bulk operations over many records, single long-running work, or anything that needs an audit trail. The run outlives the request, gets a progress page for free, and stays queryable after the fact.

## 🚨 Critical

- **Opt-in and migrated.** `config.interaction_runs.enabled = true` + `rails db:migrate` (off by default).
- **`dispatches_to` replaces `execute` entirely.** The interaction still validates, authorizes and renders its form exactly as before; only what happens on submit changes.
- **Permissions are re-derived at perform time, never replayed from dispatch.** A run created a job, not a snapshot of "what the initiator could do then." See [Authorization](#authorization-is-re-derived-not-replayed).
- **The run itself is a resource.** Register it once per portal (`rails g pu:runs:install --dest=your_portal`); its show page IS its progress page.
- **A stalled run does not silently replay.** `pu:runs:install` schedules `Runs::ReapJob` when Solid Queue is in the bundle; on any other scheduler you must add it yourself, or a crash mid-batch leaves the row `"running"` forever. See [Stalled runs](#stalled-runs-and-reapjob).

## Enabling

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.interaction_runs.enabled = true
  config.interaction_runs.queue = :default        # ActiveJob queue for run jobs
  config.interaction_runs.stall_after = 1.hour     # see Stalled runs, below
end
```

```bash
rails db:migrate   # creates plutonium_interaction_runs
```

The flag gates the migration, not just the behaviour: while it is off the runs migration path is never registered, so the table does not exist. A `dispatches_to` interaction that runs anyway raises `Plutonium::Interaction::Concerns::Dispatchable::NotEnabledError` naming the flag, rather than a raw "no such table" from inside ActiveRecord.

## Declaring a run

A run is an STI subclass of `Plutonium::Interaction::Run`. Define `perform_on(record)` for **targeted** work (bulk/record actions, one call per target) or `perform` for **opaque** work (resource actions with no subject):

```ruby
class Blogging::ArchivePostsRun < Plutonium::Interaction::Run
  on_failure :continue   # :halt (default) | :continue | :transactional

  def perform_on(post)
    post.archive!
  end
end
```

| `on_failure` | Behavior when a target raises |
|---|---|
| `:halt` (default) | Stops at the first failure; the run ends `"failed"`, targets after the failure point are never attempted |
| `:continue` | Records the failure, keeps going; the run ends `"completed"` (see [Outcome vs state](#outcome-vs-state) for why that's not the same as a clean success) |
| `:transactional` | Wraps the whole batch in one DB transaction; any failure rolls back everything applied so far |

Wire the interaction to it with `dispatches_to`:

```ruby
class Blogging::ArchivePosts < Plutonium::Resource::Interaction
  dispatches_to Blogging::ArchivePostsRun

  attribute :resources   # bulk — perform_on runs once per record
end
```

`dispatches_to` must be the only thing that defines `#execute` on the class. Declaring it on a class that already has its own `execute` raises `ArgumentError` at load time (do the work inline, or dispatch it, not both).

## What gets recorded at dispatch

Nothing is passed in explicitly. Everything the run needs is already reachable from the interaction's own state:

- **Targets.** `attribute :resource` / `attribute :resources`, already narrowed by the controller's policy scope, stored as ids (`target_ids`) and re-resolved at perform time, never serialized as records.
- **Initiator + tenant.** `current_user` / `current_scoped_entity`, the pair every Plutonium policy authorizes on.
- **The policy actually resolved.** `policy_class_name`, not an inferred `"#{Model}Policy"` (a namespaced portal or an STI fallback would make that guess wrong), plus `policy_action`, the predicate dispatch checked (e.g. `"archive?"`).
- **`authorization_namespace`.** The portal's module name, so perform-time policy lookup finds the same narrowed policy dispatch did.

An opaque (untargeted) run records none of the target/policy columns: there's no subject to check, so there's nothing to re-verify.

## Authorization is re-derived, not replayed

The job has no controller, no request, no `current_user`. `Runs::Context` rebuilds the authorization triple from the row and re-checks it from scratch. It does not trust anything the dispatching request already decided:

- The **scope** check re-runs `Post.associated_with(tenant)` style filtering. A target that left the tenant, or was deleted, between dispatch and perform is reported `missing`/`unauthorized`, never silently skipped.
- The **predicate** check re-asks the policy the same question dispatch asked (`policy_action`), per target, immediately before `perform_on`, not once up front. An initiator whose permission was revoked mid-run stops applying to the remaining targets.
- A **policy mismatch** (the class renamed/re-parented/re-namespaced since dispatch) refuses to run at all, rather than silently authorizing under a different policy than the initiator was ever subject to.

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
rails g pu:runs:install --dest=admin_portal
```

```ruby
# packages/admin_portal/config/routes.rb
register_resource ::Plutonium::Interaction::Run
```

```ruby
# packages/admin_portal/app/controllers/admin_portal/interaction_runs_controller.rb
class AdminPortal::InteractionRunsController < AdminPortal::ResourceController
  controller_for ::Plutonium::Interaction::Run

  include AdminPortal::Concerns::Controller
end
```

`controller_for` is required: the controller's name doesn't match `Run`'s real, namespaced class, so inference can't find it on its own. No policy/definition files are generated: `Plutonium::Interaction::RunPolicy`/`RunDefinition` already resolve automatically (Rails matches `Plutonium::Interaction::RunDefinition` by the exact class name, and ActionPolicy's own lookup finds `RunPolicy` the same way).

If Solid Queue is in the bundle, this also schedules `Runs::ReapJob` in `config/recurring.yml` (`--schedule` to override the default `every 15 minutes`) — see [Stalled runs and ReapJob](#stalled-runs-and-reapjob). Idempotent, so running the generator against a second portal doesn't duplicate the entry.

A registered run resource gets, for free:

- **A progress page.** The show page IS the progress page. It self-refreshes via polling (not ActionCable) while `state` is `pending`/`running`, and stops carrying the poll once the run settles, so a finished run is a static page, not a background request per viewer.
- **A running banner.** Any OTHER resource's index page lists runs currently in progress against it, above the collection, so a user who dispatched a bulk action and navigated away can find it again. Scoped through the same `authorized_resource_scope` every cross-resource read goes through, so a run in another tenant can never surface. If a resource_class is registered in a portal that never registered `Run`, the banner is skipped there instead of raising while trying to build a link to a route that doesn't exist.
- **Tenant scoping.** A run's `associated_with` scope filters on the tenant it was dispatched in (recorded on the row), not on walking the object graph, since the two polymorphic tenant columns make the generic scope unusable.
- **A humanized target label.** `run.target_label` reads the target class through `model_name.human` ("Post", not "Blogging::Post"), falling back to the raw string if that class has since been renamed or removed.

## Stalled runs and ReapJob

A worker crash mid-batch (or a job the queue silently drops) leaves a run `"running"` (or `"pending"`) forever; nothing else ever revisits it on its own. `Plutonium::Interaction::Runs::ReapJob` finds runs with no recorded activity (`last_activity_at`, falling back to `created_at` for a run never even picked up) past `config.interaction_runs.stall_after`, and resumes them: resets to `"pending"` and re-enqueues.

This is safe, not a replay. The executor tracks `handled_target_ids` (every target already dispositioned, success or failure) and resumes only the remainder, so a target already applied before the interruption is not redone.

`rails g pu:runs:install` schedules this for you when Solid Queue is in the bundle:

```yaml
# config/recurring.yml (Solid Queue)
production:
  reap_stalled_interaction_runs:
    class: Plutonium::Interaction::Runs::ReapJob
    schedule: every 15 minutes
```

Without Solid Queue — or for another scheduler like `whenever` — add it yourself:

```ruby
# whenever gem
every 15.minutes do
  runner "Plutonium::Interaction::Runs::ReapJob.perform_later"
end
```

A 15 to 30 minute cadence is reasonable against the default 1-hour `stall_after`: frequent enough that a stalled run doesn't sit for long, with enough margin that clock jitter doesn't matter.

::: warning This is a time heuristic, not a lease
Resuming is based on elapsed time, not a true distributed lock. A run that is merely slow (not dead) and happens to cross `stall_after` gets resumed too.

What bounds that is `lock_version`. Both the reaper's resume and the executor's claim bump it, so the worker that is still alive holds a version the row no longer has: its very next write raises `ActiveRecord::StaleObjectError`, and the executor treats that as "no longer mine" — it abandons the pass without marking the run failed and without overwriting the new worker's progress. Two things it deliberately does not do: it cannot interrupt a `perform_on` already in flight, so one target may be applied twice (once by each side), and it cannot roll back what the superseded worker already committed. Set `stall_after` well above this app's slowest legitimate run — the fence bounds the damage of a bad value, it does not make one free.
:::

## Related

- [Interactions](/reference/behavior/interactions) — `dispatches_to` is declared inside `Plutonium::Resource::Interaction`; everything else about inputs, validation and outcomes is unchanged.
- [Policies](/reference/behavior/policies) — the policy dispatch checks and the job re-checks are the same predicate.
