# Kanban authorization & `accepts:` simplification

**Status:** implemented (full suite green — 0 failures; 12 pre-existing `model_name` errors unrelated)
**Branch:** `feat/kanban-drop-interactions` (PR #67)
**Supersedes:** the earlier `enter_interaction_key` collision fix idea (never shipped)

## Why

The thread started from a real bug in how `enter_interaction`'s policy key is derived:

```ruby
# Plutonium::Kanban::Column#enter_interaction_key (today)
@enter_interaction.name.demodulize.sub(/Interaction\z/, "").underscore.to_sym
# BlockTaskInteraction → :block_task
```

That key is used **both** as the internal action-registration key **and** as the
authorization method name (`block_task?`). Because it's derived only from the
class basename, it isn't unique:

- **Same class on two columns** → same key → shared policy method, no per-column auth.
- **Different classes, same demodulized name** (`Leads::CloseInteraction` vs
  `Deals::CloseInteraction` → `:close`) → last-writer-wins registration → one
  column silently runs the other column's interaction. Genuine, silent bug.

Chasing a fix surfaced a deeper inconsistency: **per-column authorization only
exists as a side effect of declaring an interaction.** A plain column can't say
"only managers may drop here" without smuggling `current_user` into an `accepts:`
Proc — authorization in the wrong layer.

## Decisions

### 1. One authorization method: `kanban_move?`

Collapse all move authorization to a single `kanban_move?`. No `enter_<column>?`
convention, no per-interaction derived policy method.

- Default stays argument-less and delegates to `update?` (unchanged for existing boards).
- Advanced boards branch on `from`/`to`, supplied via **authorization context**
  (ActionPolicy rules take no positional args — context is the sanctioned channel).

```ruby
# controller (kanban_move)
authorize_current! record, to: :kanban_move?,
  context: { kanban_from: from, kanban_to: to }

# policy — opt in only when you need it
def kanban_move?
  return super unless authorization_context[:kanban_to]&.key == :closed_won
  user.admin?
end
```

Consequence: **`enter_interaction` stops needing a policy method entirely.** It's
authorized by `kanban_move?` like every other move. The class-derived key is
demoted to an internal form/param routing key only.

### 2. `enter_interaction` registration key becomes internal + column-scoped

Since the key is no longer an authorization name, uniqueness only has to hold for
internal action routing. Scope it to the column so it's collision-free by
construction and never surfaces to the author:

```ruby
def enter_interaction_key
  return nil unless @enter_interaction
  :"#{key}_enter_interaction"   # :blocked → :blocked_enter_interaction
end
```

The registered hidden action's policy check delegates to `kanban_move?` (it does
NOT get its own author-facing policy method).

### 3. Strip the Proc form of `accepts:`

`accepts:` keeps only its structural, client-hintable forms:

- `true` / `false` / `Array` of source keys → workflow topology + drag-time drop
  hints (the browser reads `data-kanban-accepts`; a policy can't run client-side).

The **Proc form is removed outright — no deprecation bridge.** It's server-only
(gives no client hint), record-based, and overlaps with `kanban_move?`.
Record-conditional rejection moves to `kanban_move?`, which now sees both the
record and `to` via context.

The constructor **raises** on a `Proc` accepts value (`ArgumentError`), in every
env. "Let it break" means fail loud — NOT silently fall through `accepts?`'s
`else` branch to `accepts: true`, which would quietly *open up* a column that used
to restrict drops. No `on_drop`-style env-gated bridge; a plain raise.

Delete `Column#accepts_record?` (the per-card evaluator) — with no Proc form the
move handler just calls `accepts?(source_key)`.

### 4. No exit authorization method

Considered `exit_<column>?` for symmetry with `on_exit`. Rejected as
over-built: exit-gating is an order of magnitude rarer than entry-gating, and it
doubles the auth surface plus makes a denial ambiguous (from vs to). The
structural "never lets go" case stays as `locked:`; per-user exit rules are
expressible in `kanban_move?` via the `from` context when actually needed.

## Net model

| Layer | Mechanism |
|---|---|
| Structure (definition, client-hintable) | `accepts:` (true/false/Array), `locked:`, `wip:` |
| Authorization (policy) | **`kanban_move?`** only — argument-less default → `update?`; reads `from`/`to` from context |
| Behavior | `on_enter` / `on_exit`; `enter_interaction` (input collection, authorized by `kanban_move?`) |

Deletes: `accepts:` Proc + `accepts_record?`, the `enter_<column>?` idea, the
class-derived interaction policy method. Adds: `from`/`to` in the move's auth
context. Simpler on every axis.

## Migration (in-repo)

**`lib/plutonium/kanban/column.rb`**
- `enter_interaction_key` → column-scoped (decision 2).
- `accepts:` Proc → deprecate (raise local / warn+permissive deployed), drop `accepts_record?`.

**`lib/plutonium/resource/controllers/kanban_actions.rb`**
- Pass `context: { kanban_from: from, kanban_to: to }` to the `kanban_move?` authorize.
- Replace `accepts_record?(record, from.key)` with `accepts?(from.key)`.
- Registered enter_interaction action authorizes via `kanban_move?`, not a derived method.

**`lib/plutonium/definition/index_views.rb`**
- Register the enter_interaction under the column-scoped key.

**Dummy (`test/dummy/app/…`)**
- `task_definition.rb`: `:done` `accepts: ->(t){ t.status=="doing" }` → `accepts: [:doing]`.
- `task_policy.rb`: delete `mark_lost?`, `block_task?`, `archive_task?` and their
  `deny_*` toggles; fold the "denied" test path into `kanban_move?` (context-aware) or
  a `deny_kanban_move` toggle.

**Tests**
- `column_test.rb`: `enter_interaction_key` now `:lost_enter_interaction`; add an
  `accepts:` Proc deprecation test (raise-in-test + warn-map-in-prod) mirroring `on_drop`.
- `kanban_drop_interaction_test.rb`: the denied-drop cases assert via `kanban_move?`
  (no more per-interaction policy method).
- `kanban_move_test.rb` / dom-contract: drop `accepts:` Proc assertions; assert
  `[:doing]` topology + `data-kanban-accepts` hint instead.

**Docs / skill**
- `docs/reference/kanban/{dsl,authorization}.md`, `docs/guides/kanban.md`,
  `.claude/skills/plutonium-kanban/SKILL.md`: remove `accepts:` Proc; document
  `from`/`to` context on `kanban_move?`; state enter_interaction has no policy method.

## Open questions

1. **Context key names — RESOLVED: declared optional targets.** ActionPolicy
   *strips* undeclared context keys (verified: a per-call `context: {kanban_to:}`
   comes back nil unless declared). So `authorize :kanban_from, optional: true` /
   `authorize :kanban_to, optional: true` on the base `Resource::Policy` — same
   shape as `parent` (nil for every non-move authorization), with clean readers
   (`kanban_to&.key`). Pure per-call context is not possible.
2. **`accepts: false` vs `locked:`** — both now purely structural. Keep both
   (entry-refuse vs exit-refuse), they're not redundant.
3. **`accepts:` Proc removal — DECIDED: hard-remove, raise, no bridge.** Delete the
   Proc branch + `accepts_record?`; constructor raises `ArgumentError` on a `Proc`
   value so broken definitions fail loud rather than silently going permissive.
