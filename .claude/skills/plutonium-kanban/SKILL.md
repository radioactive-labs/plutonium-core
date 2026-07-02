---
name: plutonium-kanban
description: Use BEFORE building or customizing a kanban board view for any Plutonium resource — the kanban do…end DSL, column declarations, card_fields, position_on modes, realtime, column actions, kanban_move? policy, and quick-add. The single source for "how do I add a kanban board to a resource".
---

# Plutonium Kanban

Turn any resource index into a drag-and-drop kanban board with a single `kanban do…end` block in the resource Definition. This skill covers the full DSL surface, model setup, authorization, and the caveats.

For field-level rendering on cards (card_fields slots), see [[plutonium-resource]] › Index Views. For policy structure, see [[plutonium-behavior]]. For custom Phlex components on cards, see [[plutonium-ui]].

## 🚨 Critical (read first)

- **`kanban do…end` in the Definition auto-enables `:kanban`** in `defined_index_views` — exactly like `grid_fields` enables `:grid`. You do not need to call `index_views :kanban` separately unless you want to remove the table view.
- **The model needs `include Plutonium::Positioning`** (and a decimal `position` column + `positioned_on` call) for drag ordering to work. Without it, cards render unordered and moves raise an error. Use `position_on false` to explicitly opt out.
- **Static column actions are auto-registered** as interactive resource actions at class-load time. Dynamic boards (`columns do…end`) cannot introspect their columns at load time — declare any column-action interactions separately with top-level `action` calls.
- **Moves bypass `permitted_attributes_for_update`** — the `on_drop` callback runs with full model access. Gate the move itself with `kanban_move?` in the policy.
- **Quick-add (`add: true`) only appears when `create?` is true** in the policy.
- **Same-column drops = positioning only** — a reorder within a column fires neither `on_drop` nor a `drop_interaction`; both represent *entering* a column, so only cross-column drops trigger them.

---

## Model setup

```ruby
class Task < ApplicationRecord
  include Plutonium::Positioning

  # position_on :position (default attr) scoped to the grouping column
  positioned_on :position, scope: :status

  def mark_done!
    update!(status: "done")
  end
end
```

Migration — add the position column with the `t.position` helper (a tuned `decimal(16,8)`; works in `create_table` and `change_table`). Don't hand-roll a small scale — `scale: 6` exactly matches the `1e-6` rebalance threshold and can round to a duplicate. Use `t.position` (scale 8) or ≥ 8 if hand-written:

```ruby
create_table :tasks do |t|
  t.string :title,  null: false
  t.string :status, null: false, default: "todo"
  t.position        # decimal :position, precision: 16, scale: 8
  t.timestamps

  t.index [:status, :position]
end
```

---

## Minimal definition

```ruby
class TaskDefinition < ResourceDefinition
  kanban do
    column :todo,
      scope:   -> { where(status: "todo") },
      on_drop: ->(r) { r.update!(status: "todo") }

    column :doing,
      scope:   -> { where(status: "doing") },
      on_drop: ->(r) { r.update!(status: "doing") }

    column :done,
      scope:   -> { where(status: "done") },
      on_drop: :mark_done!     # Symbol → record.mark_done!
  end
end
```

Set it as the default or only view:

```ruby
default_index_view :kanban   # still shows view switcher with :table
index_views :kanban           # remove table; kanban is the only view
```

---

## Board-level options

| DSL call | Purpose | Default |
|---|---|---|
| `per_column N` | Cap cards rendered per column; `+N more` footer when exceeded | unlimited |
| `position_on :attr` | Custom attribute name for ordering (Mode A) | `:position` |
| `position_on :attr do \|move\| … end` | BYO positioning block (Mode B) | — |
| `position_on false` | No ordering or repositioning (Mode C) | — |
| `card_fields(**slots)` | Override grid slot layout for cards; same slot keys as `grid_fields` | inherits `grid_fields` |
| `realtime true` | ActionCable broadcast after every move | false |
| `lazy false` | Eager-load all column frames on the initial request | `true` (lazy) |
| `show_in :modal` / `:page` | Open a card's show page in a centered modal (`:modal`) or full-page (`:page`). Overrides the definition's `show_in` for this board | inherits definition (`:page`) |
| `columns do … end` | Dynamic columns evaluated at request time with view context | — |

### `card_fields`

Overrides the grid card layout for kanban cards. Uses the same slot keys as `grid_fields`:

```ruby
card_fields header: :title, meta: [:status, :priority], footer: :due_at
```

### `position_on` modes

- **Mode A (default)** — delegates to `record.reposition!(prev_record:, next_record:)` from `Plutonium::Positioning`. Requires the model concern and a decimal column.
- **Mode B (block)** — you write the persistence. Plutonium still orders by the attribute; the block only persists the new value. Block receives a `Plutonium::Kanban::Positioning::Move` (fields: `record`, `column`, `prev`, `next`, `index`).
- **Mode C (`false`)** — no ordering, no repositioning. `on_drop` still fires.

### `realtime`

Broadcasts refreshed column turbo-frames to all board subscribers after every successful move. Requires ActionCable. Opt in per-board:

```ruby
realtime true
```

### `show_in`

Where a card click opens the record's show page. `:modal` renders the show page in a **centered** dialog; `:page` is a full-page navigation. The show modal is always centered — deliberately NOT the definition's `modal_mode` (which styles `new`/`edit`). No per-card wiring: the `Show` page detects the modal frame (`in_modal?`) and wraps its details in the centered modal chrome.

`show_in` also exists **on the definition** (`show_in :modal` / `:page`, default `:page`), where it governs the table and grid show links too. The kanban board inherits the definition's value unless it sets its own — so set it once on the definition for everywhere, or on the board to override just the board.

From inside the show modal, an expand icon (or ⌘/Ctrl/middle-click on the card) opens the full page in a new tab.

```ruby
class TaskDefinition < ResourceDefinition
  show_in :modal      # table + grid + board open show in a centered modal
  kanban do
    # show_in :page   # override: this board navigates full-page
  end
end
```

### Dynamic columns

Evaluates the block at request time with the view context as `self` (`current_user`, `params`, `current_scoped_entity`, helpers all available). The block must return an Array of `Plutonium::Kanban::Column` objects — `column` is a DSL method only available outside the `columns` block. Declare any column-action interactions as top-level definition `action` calls — the block is not introspectable at class-load time.

```ruby
kanban do
  columns do
    # `self` is the view context here — use Plutonium::Kanban::Column.new, NOT `column`.
    current_user.teams.map do |team|
      Plutonium::Kanban::Column.new(
        :"team_#{team.id}",
        label:   team.name,
        scope:   -> { where(team_id: team.id) },
        on_drop: ->(r) { r.update!(team_id: team.id) }
      )
    end
  end
end
```

---

## Column options

```ruby
column :key,
  label:     "Custom Label",   # defaults to key.to_s.titleize
  color:     :green,           # Tailwind-mapped color hint
  wip:       3,                # max cross-column moves into this column
  scope:     -> { where(…) },  # 0-arg lambda or Symbol (sent to relation)
  on_drop:   ->(r) { … },      # 1-arg lambda or Symbol → record.method!
  drop_interaction: MarkLostInteraction, # record-scoped interaction run on cross-column drop (see below)
  collapsed: true,             # starts collapsed (Stimulus persists toggle to localStorage)
  add:       true,             # show "+ Add" button (requires create?)
  accepts:   true,             # true (default), false, Array of source keys, or 1-arg Proc
  locked:    false,            # reject all incoming drops (server-enforced)
  role:      :backlog          # :backlog, :done or :lost (see presets below)
```

### Column role presets

| Role | Preset behaviour |
|---|---|
| `:backlog` | `add: true` |
| `:done` | `color: :green`, `collapsed: true` |
| `:lost` | `color: :red`, `collapsed: true` |

`:done` and `:lost` are the two terminal roles — collapsed by default, colour
signalling the outcome (`:done` = positive close, `:lost` = negative close). The
natural pair for won/lost pipelines (leads, deals, tickets).

Explicit options override the preset (e.g. `role: :done, collapsed: false`).

### `accepts:`

Controls which source columns may drop cards here:

- `true` (default) — any source allowed
- `false` — column is a drop target but refuses everything (snap-back)
- `Array` — list of source column keys allowed: `accepts: [:doing]`
- `Proc` (1-arg) — per-card predicate: `accepts: ->(record) { record.state == "doing" }`

Checked server-side. Client-side visual hints read `data-kanban-accepts`.

### `on_drop:`

Runs inside a transaction after authorization and before repositioning. Receives the record for lambda form:

```ruby
on_drop: ->(r) { r.update!(status: "done") }   # update! directly
on_drop: ->(r) { r.status = "done" }            # attribute assignment — saved automatically
on_drop: :mark_done!                            # dispatched as record.mark_done!
```

If `on_drop` only assigns attributes without calling `save!`/`update!`, the controller calls `record.save!` automatically when the record has unsaved changes after `on_drop` returns.

### `drop_interaction:`

Run an input-collecting interaction when a card is dropped **into** this column from another column — for entries that need more than a membership flip (a reason, a mail, an audit entry).

```ruby
column :lost, scope: -> { where(status: "lost") }, drop_interaction: MarkLostInteraction

class MarkLostInteraction < ResourceInteraction
  attribute :resource                       # MUST be record-scoped (singular), not :resources
  attribute :reason, :string
  input :reason
  validates :reason, presence: true
  def execute
    resource.update!(status: "lost", lost_reason: reason)
    succeed(resource).with_message("Marked as lost")   # message → toast
  end
end
```

- **Auto-registered as a HIDDEN record action** keyed by the interaction's conventional name (`MarkLostInteraction` → `:mark_lost`) — no button on show/table/grid; reachable only by dropping.
- **Move flow:** cross-column drop opens the interaction's form as a modal; on submit `on_drop` + interaction + repositioning commit in **one atomic transaction**. Validation failure rolls it all back (membership write included) and re-renders the modal with errors — nothing persists. Put side-effects on `deliver_later` so a rollback sends no stray mail.
- **Same-column reorder = positioning only** — neither `on_drop` nor the interaction fires (both = *entering* a column).
- **Quick-add unaffected:** `+ Add` still uses `on_drop`'s dry-run; the interaction is not involved.
- **Author contract:** with both present, `on_drop` owns the membership attribute (`status`) and the interaction owns extras. If the interaction also writes membership it must set the **same** value (idempotent). With no `on_drop`, the interaction owns everything (like `:lost`).
- **Limitation:** custom success *responses* (`with_redirect_response`, `with_file_response`, …) are NOT honored on the drop path — board re-renders + modal closes. Use `.with_message` for feedback.

### Column actions

Declared inside the column block. Auto-registered as interactive resource actions:

```ruby
column :done, … do
  action :archive_all,
    interaction: ArchiveTasksInteraction,
    on:          :all,          # :all or :visible
    label:       "Archive all",
    icon:        Phlex::TablerIcons::Archive,
    confirmation: "Archive all done tasks?"
end
```

`on: :all` — passes every record in the column scope. `on: :visible` — passes only the currently rendered subset (respects `per_column`).

---

## Authorization

### `kanban_move?` → `update?`

Every drag-and-drop is authorized via `kanban_move?` in the policy. Default:

```ruby
def kanban_move?
  update?
end
```

Override for finer control:

```ruby
class TaskPolicy < ResourcePolicy
  def kanban_move? = user.member?   # members can drag; only admins edit
end
```

When `kanban_move?` returns `false`, the board renders read-only — no drag handles, no drop zones.

**Layered authorization for `drop_interaction:` columns.** A drop into a column with a `drop_interaction` must pass **both** the board-wide `kanban_move?` **and** the interaction's own named policy predicate (`MarkLostInteraction` → `def mark_lost? = update?`). The first gates whether the card moves at all; the second gates that specific transition — no `condition:` proc needed.

### Move authorization flow

1. Record loaded via current `relation_scope` (same as index).
2. `kanban_move?` checked — HTTP 403 on failure.
3. Column `accepts:` / `locked:` checked — HTTP 422 + card snap-back on failure.
4. `wip:` limit checked for cross-column moves — HTTP 422 on failure.
5. `on_drop` fires + record repositioned, all in a transaction.

On a 422 rejection (steps 3–4) the response re-renders the source column (snap-back) **and** appends a dismissable warning toast naming the reason (e.g. `“Pending” is at its WIP limit (5).`) to the board's `#kanban-flash` region — so the snap-back is never silent. The toast renders the shared `plutonium/toast` partial directly (not via `flash`), so a stale undisplayed flash can't leak into the turbo-stream response.

### No permitted-attributes gate

Moves do not pass through `permitted_attributes_for_update`. `on_drop` is trusted author code; it is responsible for assigning only the appropriate attributes.

### Quick-add

The `+ Add` button (column `add: true`) only renders when the policy's `create?` is true. The opened form is the standard new-resource form.

---

## Worked example (full)

```ruby
class TaskDefinition < ResourceDefinition
  kanban do
    per_column 25
    card_fields header: :title, meta: [:status]

    column :todo,
      scope:   -> { where(status: "todo") },
      on_drop: ->(r) { r.update!(status: "todo") },
      role: :backlog                    # add: true

    column :doing,
      scope:   -> { where(status: "doing") },
      on_drop: ->(r) { r.update!(status: "doing") },
      wip: 3

    column :done,
      scope:   -> { where(status: "done") },
      on_drop: :mark_done!,
      accepts: ->(task) { task.status == "doing" },
      role:    :done do                 # color: :green, collapsed: true
      action :archive_all,
        interaction: ArchiveTasksInteraction,
        on:    :all,
        label: "Archive all"
    end
  end
end
```

---

## Full docs

- Guide: `docs/guides/kanban.md`
- DSL reference: `docs/reference/kanban/dsl.md`
- Positioning reference: `docs/reference/kanban/positioning.md`
- Authorization reference: `docs/reference/kanban/authorization.md`
- Working example: `test/dummy/app/definitions/task_definition.rb`

---

## Related skills

- [[plutonium-resource]] — Definition layer, `grid_fields`, index views, actions
- [[plutonium-behavior]] — Policy methods, `kanban_move?`, interactions
- [[plutonium-ui]] — Custom Phlex components for card rendering
