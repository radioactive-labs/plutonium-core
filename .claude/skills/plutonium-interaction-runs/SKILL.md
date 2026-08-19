---
name: plutonium-interaction-runs
description: Use BEFORE building any bulk operation, long-running interaction, or anything needing an audit trail. Covers dispatches_to, the Run STI model, failure policies (halt/continue/transactional), authorization re-derivation at perform time, registering InteractionRun as a resource (progress page + running banner), and scheduling ReapJob for stalled runs. The single source for "how do I make an interaction async".
---

# Plutonium Interaction Runs

`dispatches_to` turns an interaction from "does the work inline" into "persists a run, enqueues it, and redirects to it." Reach for it when a synchronous interaction would time out (hundreds/thousands of records), take longer than a request budget (report generation, a third-party API call), or needs to leave an audit trail nothing currently records.

For everything about the interaction itself (inputs, validation, outcomes, `execute`), load [[plutonium-behavior]] first. `dispatches_to` only replaces what `execute` does, not the rest of the interaction's shape.

## 🚨 Critical (read first)

- **Experimental.** The DSL and behavior may change in a future release — same status as [[plutonium-wizard]] and [[plutonium-kanban]]. Fine to build on; expect to revisit it on upgrade.
- **Enable the subsystem first.** `config.interaction_runs.enabled = true` in `config/initializers/plutonium.rb`, then `rails db:migrate`. Off by default, so no `plutonium_interaction_runs` table otherwise.
- **`dispatches_to` fully replaces `#execute`.** Declaring it on a class that already defines its own `execute` raises `ArgumentError` at load. Do the work inline, or dispatch it, never both.
- **Define `perform_on(record)` for targeted work, `perform` for opaque work.** A run class implementing neither fails loudly (naming the class) the first time it's performed, rather than a bare `NoMethodError`.
- **A nested dispatch records its parent.** `parent_type`/`parent_id`/`parent_association` join initiator and tenant on the row, because `Policy#default_relation_scope` picks parent scoping **or** entity scoping, not both — a nested run missing its parent re-derives targets under the wider tenant scope, and any predicate reading `parent` silently answers false. A parent deleted mid-run refuses the run, exactly like a deleted tenant.
- **Permissions are re-derived at perform time, never replayed from dispatch.** The job rebuilds `(initiator, tenant)` from the row and re-checks the policy scope and predicate per target, immediately before each `perform_on`. A permission revoked mid-run stops applying to what's left. Both failure directions (scope, predicate) fail closed (refuse/report), never open.
- **Register `Run` as a resource per portal.** Its show page IS the progress page, and other resources' index pages get a "runs in progress" banner for free. Nothing renders without registration.
- **Read `outcome`, never bare `state`, when displaying a run's result.** A `:continue` run that under-applied still has `state == "completed"`; only `outcome` says `"completed_with_errors"`.
- **Long work must call `heartbeat!`.** `stall_after` measures SILENCE, and the executor only writes per target — so opaque `perform` writes nothing at all between claim and finish. An opaque run longer than `stall_after` is reaped and, having no `handled_target_ids`, re-run from scratch. Call `heartbeat!` inside the loop. It also raises `StaleObjectError` if another worker took the run over, which for opaque work is the only way to find out.
- **A crashed/stalled run does not auto-heal.** Nothing revisits a `"running"` row on its own. `pu:runs:install` schedules `Plutonium::Interaction::Runs::ReapJob` for you when Solid Queue is in the bundle; otherwise (or on another scheduler) you must schedule it yourself. Unscheduled, a crash mid-batch leaves that row stuck forever.

---

## ✅ Before you build: verify the ground truth (CHECK, don't ask for it)

| Check | How | Why it matters |
|---|---|---|
| Subsystem enabled | grep `config/initializers/plutonium.rb` for `interaction_runs.enabled` | Not enabled means no table; `dispatches_to` raises `Dispatchable::NotEnabledError` the moment it dispatches, naming the flag |
| Run registered in the target portal | grep the portal's `config/routes.rb` for `register_resource ::Plutonium::Interaction::Run` | Unregistered means dispatch redirects to a 404; the running banner silently skips that portal (by design, see below) |
| Existing run classes for the pattern | `ls app/runs/` or grep `< Plutonium::Interaction::Run` | Match the host's existing `on_failure` conventions rather than guessing |
| ReapJob scheduled | grep `config/recurring.yml` / `config/schedule.rb` for `ReapJob` | An `on_submit`-shaped bulk workflow with no reaper leaves crashed runs stuck |

---

## Declaring a run

STI subclass of `Plutonium::Interaction::Run`. One run class per interaction (or reuse one across several interactions that do the same kind of work):

```ruby
class Blogging::ArchivePostsRun < Plutonium::Interaction::Run
  on_failure :continue   # :halt (default) | :continue | :transactional

  def perform_on(post)   # targeted: called once per resolved target
    post.archive!
  end
end

class Reports::GenerateMonthlyRun < Plutonium::Interaction::Run
  def perform             # opaque: no target, called once
    Reports::Monthly.generate!(options["period"])
  end
end
```

| `on_failure` | One target raises |
|---|---|
| `:halt` (default) | Stop immediately; run ends `"failed"`; remaining targets never attempted |
| `:continue` | Record the failure (`errors_log`), keep going; run ends `"completed"`. Check `outcome`, not `state`, to see it under-applied |
| `:transactional` | Whole batch in one DB transaction; any failure rolls back everything, including targets already applied |

Wire the interaction to it:

```ruby
class Blogging::ArchivePosts < Plutonium::Resource::Interaction
  dispatches_to Blogging::ArchivePostsRun

  attribute :resources   # bulk: perform_on runs once per record
end
```

`attribute :resource` (singular) means a one-target run; `attribute :resources` (plural) means bulk; neither means opaque. Same inference rule ordinary interactive actions use, see [[plutonium-resource]] › Actions.

### What's recorded, and why

Nothing is passed explicitly. Dispatch reads it off the interaction/controller it's already running in:

- **Targets** as ids (`target_ids`), re-resolved through the policy scope at perform time. Never serialized records, which would be stale and unauthorized the moment anything changed.
- **Initiator + tenant** (`current_user` / `current_scoped_entity`), the pair every Plutonium policy authorizes on.
- **`policy_class_name`**, the policy dispatch actually resolved, not an inferred `"#{Model}Policy"` (wrong under a namespaced portal or an STI target).
- **`policy_action`**, the predicate dispatch checked (e.g. `"archive?"`), re-asked per target at perform time.
- **`authorization_namespace`**, the portal's module name, so perform-time lookup finds the same policy dispatch did.

An opaque run records none of the target/policy columns. Nothing to re-verify without a subject.

## Registering the Run resource

Use the generator, per portal. Never hand-write the route/controller:

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

`controller_for` is required — the controller's name doesn't match `Run`'s real, namespaced class, so inference can't find it on its own. No policy/definition files are generated: `Plutonium::Interaction::RunPolicy`/`RunDefinition` already resolve automatically (exact class-name match for the definition, ActionPolicy's own lookup for the policy).

If Solid Queue is in the bundle, this also schedules `Runs::ReapJob` in `config/recurring.yml` — see [Scheduling ReapJob](#scheduling-reapjob-stalled-runs). `--schedule` overrides the default `every 15 minutes`. Idempotent, so running it against a second portal doesn't duplicate the entry.

Registering gets you, for free:

- **Progress page.** The show page IS the progress page, self-polling while `pending`/`running`, and stops carrying the poll once settled (a finished run is a static page, not an eternal background request per viewer).
- **Running banner.** Any OTHER registered resource's index lists in-progress runs targeting it, above the collection, scoped through the same `authorized_resource_scope` every cross-resource read uses (a run in another tenant can't surface). If a `resource_class` is registered in a portal that never registered `Run`, the banner is skipped there instead of raising while building a link to a nonexistent route. No action needed on your part.
- **`target_label`.** The show page/table read `run.target_label` (`model_name.human`, e.g. `"Post"`) rather than the raw `target_type` string (`"Blogging::Post"`).
- **Tenant scoping via `associated_with`.** Filters on the tenant the run was dispatched in (recorded on the row), because the two tenant columns are polymorphic and the generic object-graph scope can't walk them.

## Scheduling ReapJob (stalled runs)

A worker crash mid-batch, or a job the queue silently drops, leaves a run `"running"`/`"pending"` forever. Nothing else revisits it. `ReapJob` finds runs with no activity (`last_activity_at`, or `created_at` if never picked up) past `config.interaction_runs.stall_after` (default `1.hour`), and resumes them: resets to `"pending"`, re-enqueues.

This is safe, not a blind replay. The executor tracks `handled_target_ids` and only re-attempts what's left.

Safe *given a heartbeat*: `handled_target_ids` only exists for targeted work, so opaque work resumes by re-running `perform` whole. Long opaque work must call `heartbeat!` (see Critical, above) so it is never judged stalled in the first place.

`rails g pu:runs:install` schedules it automatically when Solid Queue is in the bundle:

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

15 to 30 minutes is a reasonable cadence against the default 1-hour `stall_after`. This is a time heuristic, not a true lease: a merely-slow (not dead) run that crosses `stall_after` gets resumed too. `lock_version` bounds what that costs — the resumed row's version no longer matches the still-live worker's, so that worker stops at its next write instead of racing the new one. It does **not** interrupt an in-flight `perform_on` (one target can be applied twice, once by each side), and it does not roll back what the superseded worker already committed. Set `stall_after` well above the app's slowest legitimate run.

On Solid Queue (or any queue providing ActiveJob concurrency controls) this is tightened further, automatically and with no configuration: `Runs::Job` declares a semaphore of 1 keyed on the run id, held for `stall_after`, and `ReapJob` one global sweep at a time. A second delivery of the same run then waits rather than racing, so the one target the fence cannot save from a double apply is not applied twice either. Nothing declares it when the queue does not support it.

## Full reference

`docs/reference/behavior/interaction-runs.md` has the complete write-up: authorization re-derivation in detail, outcome-vs-state, everything above with more context.

## Related Skills

- [[plutonium-behavior]] — the interaction itself: inputs, validation, `succeed`/`failed`, policies.
- [[plutonium-resource]] — Actions (inferred bulk/record/resource shape), Definition (`field`/`display`/`column`).
- [[plutonium-tenancy]] — entity scoping, `associated_with`, portal tenant strategies.
- [[plutonium-wizard]] — the other long-lived, persisted flow primitive (multi-step, not async execution). `Wizard::SweepJob` is `ReapJob`'s sibling for abandoned wizard sessions.
