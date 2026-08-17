# Async interactions — design

Status: design approved in conversation, not yet implemented.

## The problem

`Plutonium::Resource::Interaction` runs inline. `Interaction.call` validates, runs
`execute`, and returns an `Outcome` the controller turns into a `Response` — all
inside one request. That is correct for the operations it was built for, and
wrong for three kinds of work an app inevitably grows:

- **Bulk over many records.** Archiving 500 projects in a request either times
  out or holds a web worker hostage.
- **One slow operation.** Rebuilding an index, generating a report, calling a
  third-party API. Duration is opaque and often exceeds a request budget.
- **Anything worth auditing.** Nothing records who ran what, with which options,
  or what it did. The interaction leaves no trace.

There is no `perform_later` anywhere in `lib/plutonium` outside
`Wizard::SweepJob`, so this is genuinely absent rather than partially built.

## The idea

**The run becomes a record.** That single change buys everything else:
persistence outlives the request, so async is natural; a row has a lifecycle, so
progress and scheduling follow; it is queryable, so audit is free; and it is a
resource, so it gets an index and show page from machinery that already exists.

Prior art is Bullet Train's Action Models. The adaptation below is deliberately
not a port — Plutonium already owns primitives (policy scopes, entity scoping,
interactions, `Kanban::Broadcaster`) that Bullet Train has to reinvent.

**Interactions dispatch; runs execute.** The interaction keeps its current job —
declare inputs, validate, authorize, render a form. On `execute` it creates a run
and enqueues it. It still succeeds *synchronously*, because dispatching is what
succeeded, so `Outcome` needs no new state. Its response is a redirect to the
run.

## Architecture

### Storage — one table, STI

A single `plutonium_interaction_runs` table with a `type` column. Authors
subclass to configure behaviour; options live in a JSON column, so an async
action costs zero migrations.

| Column | Purpose |
|---|---|
| `type` | STI discriminator — the author's run subclass |
| `state` | `pending` / `running` / `completed` / `failed` |
| `options` | JSON. The dispatching interaction's validated inputs |
| `target_type` | Class name of the targeted resource; `nil` for opaque runs |
| `target_ids` | JSON array of ids selected at dispatch |
| `initiator_type` / `initiator_id` | Polymorphic — who started it |
| `scoped_entity_type` / `scoped_entity_id` | Polymorphic, nullable — tenant context |
| `progress_total` / `progress_done` | Counts. Both `nil` for opaque work |
| `errors_log` | JSON. Per-target failures |
| `started_at` / `finished_at` | Timing, and the basis for sweeping |

The shape follows `Wizard::Session`, which is already a persisted process record
with polymorphic `owner` / `anchor` / `scope` refs and a `SweepJob`. This is not
a new architecture for the codebase; it is the second instance of one that works.

### Two run shapes

The framework picks by what the subclass implements — no mode flag.

```ruby
class ArchiveProjectsRun < Plutonium::Interaction::Run
  on_failure :continue

  # Targets arrive from the dispatching interaction's selection. The framework
  # re-resolves them through the policy scope before each call.
  def perform_on(project) = project.archive(notify: options[:notify_users])
end

class RebuildSearchIndexRun < Plutonium::Interaction::Run
  # No targets: one opaque unit, indeterminate progress.
  def perform = SearchIndex.rebuild!
end
```

There is deliberately **no author-defined `targets` method**. Bullet Train needs
`valid_targets` because its action model receives raw ids with nothing to
constrain them. Plutonium already has that primitive: a bulk action's records
come from the selection, and `relation_scope` answers "which records may this
user touch". A second declaration would be a second place to disagree with the
policy.

### Identifying targets — ids, not GlobalIDs

`target_type` (a real column) plus a JSON array of ids. Not GIDs:

1. **The index feature needs a real column.** "Runs in progress for this
   resource" is `where(target_type: Project.name, state: :running)`. That cannot
   be indexed out of a JSON array of `gid://app/Project/1` strings.
2. **One scoped query, not N locates.** `policy_scope(Project).where(id: ids)`
   re-resolves through `relation_scope` in a single query and enforces
   authorization by construction. `GlobalID::Locator` bypasses the policy scope
   entirely, requiring a separate re-authorization per record.
3. **GIDs solve heterogeneity that does not exist here.** Bulk selection is
   always one resource type; the existing route is already `ids[]=1&ids[]=2`.

GlobalID-style polymorphism is still right for `initiator` and `scoped_entity`,
which genuinely vary by portal — hence the polymorphic columns.

### Authorization outside the request

This is the sharpest correctness issue in the design.

`perform` runs in a job. There is no `current_user`, no request, no ambient
context. Plutonium authorizes on the **pair** `(user, entity_scope)` —
`Authorizable` registers `authorize :entity_scope, through:
:entity_scope_for_authorize`, and PR #74 exists precisely because a nil entity
leaking into that memo broke scoping.

Therefore:

- The run persists **both** `initiator` and `scoped_entity`. Storing only the
  user would re-resolve targets under the wrong tenant — and that fails *open*,
  because a broader scope silently includes records the initiator could not see
  when they dispatched.
- The job **rebuilds** the context from those columns. It never inherits one.
- Authorization is **re-checked at perform time**, not trusted from dispatch.
  Access revoked between enqueue and run must stop the work, or a persisted run
  becomes a way to launder stale permissions.

**Decision: `initiator` is required.** A nullable column would silently come to
mean "unscoped", which is the failure mode above. System-triggered runs
(schedules, callbacks) should get an explicit system initiator later rather than
a null.

### Failure policy

Configured on the run subclass, since the author knows the semantics:

- `on_failure :continue` — record the failure in `errors_log`, keep going.
  Correct for bulk, where 497 successes should not be discarded.
- `on_failure :halt` — stop at the first error.
- `on_failure :transactional` — wrap the whole run in one transaction. Honest
  about its cost: a long transaction over many records risks lock contention,
  and is impossible once the work touches a third-party API.

**Decision: a target that vanishes or falls out of scope between dispatch and
perform is recorded as a per-target failure, not skipped.** "3 targets were no
longer available" is information the operator needs; silence there is how bulk
operations quietly under-apply.

### Progress transport

**Turbo poll by default, broadcast opt-in.** The progress page is a turbo-frame
with a refresh interval — no ActionCable, works on any deployment. A run may opt
into realtime and reuse `Kanban::Broadcaster`, whose stream names are already
keyed on **both** `resource_class` and `scoped_entity` so tenants can never share
a stream. This matches the house posture: kanban's `realtime` defaults to false.

### Surfaces

- **The run is a resource.** The framework ships a definition and policy, so a
  portal can register it and get index and show pages. The progress page is
  simply the run's show page — no bespoke view.
- **Dispatch redirects** to that show page, via the interaction's ordinary
  `Response::Redirect`.
- **The target resource's index lists in-progress runs at the top**, queried by
  `target_type` — which is why it is a column rather than JSON.

## Testing

- **Unit** — state machine, failure policies, progress accounting, options
  round-tripping through JSON.
- **Authorization** — the highest-value tests. A run whose initiator lost access
  between dispatch and perform must not perform. A run must not resolve targets
  outside its stored `scoped_entity`. Both fail open if wrong, so both need
  explicit coverage.
- **Integration** — dispatch returns a redirect; the show page reports progress;
  the target index lists running work.
- **System** — one end-to-end pass on the progress page updating.

## Out of scope

Scheduling (`run_at`), approval workflows, retries, and import/export run types.
All are natural extensions of a persisted run and none is needed to make the
first version useful. Retention/sweeping follows `Wizard::SweepJob`'s pattern
when it is needed; runs are kept indefinitely until then, since audit is a
motivation.
