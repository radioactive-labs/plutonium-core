# Kanban Boards

::: warning Experimental
Kanban boards are experimental — the DSL and behavior may change in a future release.
:::

Turn any resource index into a drag-and-drop kanban board — columns, WIP limits, quick-add, column actions, and opt-in realtime — all from a single `kanban do…end` block in your definition.

![A kanban board grouped by status — cards with badges, a WIP badge on Pending, a quick-add button, and collapsible columns](/images/guides/kanban-board.png)

## What you get

- Drag cards between columns; the server persists the column change and the position within the column.
- Decimal fractional positioning — cards always land exactly where you drop them without renumbering.
- Per-column `+ Add` button opens the resource's normal new form, pre-seeded for that column.
- Column actions run an interaction against all (or visible) cards in a column.
- WIP limits, locked columns, and cross-column drop restrictions enforced server-side.
- Opt-in realtime: every connected viewer sees the same board state after any move.

## Worked example — Task board

A complete board for a `Task` model grouped by status — migration, model, definition, and policy.

### 1. Migration

The model needs a `decimal` position column. Use the **`t.position`** helper — it adds a `decimal` column already tuned for fractional ordering (`precision: 16, scale: 8`), so you can't pick a scale too small to rebalance cleanly (see [Positioning › Migration](/reference/kanban/positioning#migration)).

```ruby
class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.string :status, null: false, default: "todo"
      t.position        # decimal :position, precision: 16, scale: 8
      t.timestamps

      t.index [:status, :position]
    end
  end
end
```

### 2. Model

```ruby
class Task < ApplicationRecord
  include Plutonium::Positioning

  positioned_on :position, scope: :status
  # ^^ auto-assigns position on create; reposition! scopes to the same status

  validates :status, inclusion: { in: %w[todo doing done] }

  def mark_done!
    update!(status: "done")
  end
end
```

### 3. Definition

```ruby
class TaskDefinition < ResourceDefinition
  kanban do
    per_column 25

    column :todo,
      scope: -> { where(status: "todo") },
      on_drop: ->(r) { r.update!(status: "todo") },
      role: :backlog          # shorthand for add: true

    column :doing,
      scope: -> { where(status: "doing") },
      on_drop: ->(r) { r.update!(status: "doing") },
      wip: 3

    column :done,
      scope: -> { where(status: "done") },
      on_drop: :mark_done!,   # Symbol → record.mark_done!
      accepts: [:doing],      # only cards from :doing can land here
      role: :done do          # shorthand for color: :green, collapsed: true
      action :archive_all,
        interaction: ArchiveTasksInteraction,
        on: :all,
        label: "Archive all"
    end
  end
end
```

### 4. Policy

A move is authorized via `kanban_move?`, which defaults to `update?`. Override it only when you want board-drag access to differ from full-edit access:

```ruby
class TaskPolicy < ResourcePolicy
  # Allow all authenticated members to move cards,
  # but require :admin to edit the form directly.
  def kanban_move?
    true
  end
end
```

### 5. Routes — no changes needed

The `kanban_move` member route is wired automatically when the controller includes `Plutonium::Resource::Controllers::KanbanActions` (included by default in all Plutonium resource controllers).

Visit the resource index and use the view switcher to select the Kanban view.

![After dragging a card from Doing to Done — both column frames re-render and the WIP badge on Doing updates in place](/images/guides/kanban-after-move.png)

### When a drop is rejected

If a move is refused server-side — the destination is at its `wip:` limit, its `accepts:` policy rejects the card, or the source column is `locked:` — the card snaps back to where it started **and** a dismissable toast explains why:

![A warning toast reading “Pending” is at its WIP limit (5) after a rejected drop](/images/guides/kanban-wip-toast.png)

The toast is appended to a `#kanban-flash` region in the board shell (outside the per-column frames, so it survives the snap-back re-render). The client-side drag hints already grey out columns a card plainly can't enter, so the toast mainly surfaces the cases the browser can't pre-check — most commonly a WIP-full column or a per-card `accepts:` Proc.

### Opening a card

Clicking a card opens its show page. Where it opens is controlled by [`show_in`](/reference/kanban/dsl#show_in) — full-page by default, or a **centered modal** that keeps the board visible behind it:

![A card's show page open in a centered modal over the board, with an expand icon to open the full page](/images/guides/kanban-show-centered-modal.png)

```ruby
class TaskDefinition < ResourceDefinition
  show_in :modal          # open show in a modal everywhere (table, grid, board)

  kanban do
    # show_in :page       # …or override just this board back to full-page
  end
end
```

- Set `show_in :modal` on the **definition** to open show in a modal from the table, grid, and board alike. Set it on the **kanban block** to change only the board. An unset board inherits the definition (which defaults to `:page`).
- The show modal is always **centered** — distinct from `new`/`edit`, which follow the definition's `modal_mode` (a slideover by default).
- From inside the modal, an expand icon opens the record's full page in a new tab. ⌘/Ctrl-click (or middle-click) on a card does the same directly.

---

## Worked example — Status enum board

A shorter example that groups by a Rails enum for status. Cards reuse `grid_fields` for their slot layout — no explicit `card_fields` needed.

```ruby
class KitchenSinkDefinition < ResourceDefinition
  kanban do
    column :active, label: "Active", role: :backlog,
      scope:   -> { where(status: :active) },
      on_drop: ->(ks) { ks.status = :active }

    column :pending, label: "Pending", color: :yellow, wip: 5,
      scope:   -> { where(status: :pending) },
      on_drop: ->(ks) { ks.status = :pending }

    column :archived, label: "Archived", role: :done,
      scope:   -> { where(status: :archived) },
      on_drop: ->(ks) { ks.status = :archived }

    per_column 10
  end
end
```

Key points:
- `role: :backlog` enables the `+ Add` button (equivalent to `add: true`).
- `wip: 5` caps the Pending column; a cross-column drop that would push it past 5 is rejected server-side.
- `role: :done` collapses the Archived column by default and shows a green header dot.
- `on_drop` here assigns the attribute in memory (`ks.status = :active`). The framework calls `record.save!` automatically when the record has unsaved changes after `on_drop` returns — you do not need to call `update!` explicitly.

---

## Columns

### Static columns

Declared at definition class-load time with `column :key, **opts`:

```ruby
kanban do
  column :backlog,
    label: "Product Backlog",      # default: key.to_s.titleize
    color: :blue,                  # dot color in the column header
    scope: -> { where(stage: 0) }, # 0-arg lambda evaluated on the relation
    on_drop: ->(r) { r.update!(stage: 0) }
end
```

### Dynamic columns

Use `columns do…end` when the column list depends on request context (`current_user`, `params`, etc.):

```ruby
kanban do
  columns do
    # `self` is the view_context — current_user, params, helpers all work.
    current_user.projects.map do |project|
      Plutonium::Kanban::Column.new(
        :"project_#{project.id}",
        label: project.name,
        scope: -> { where(project_id: project.id) },
        on_drop: ->(r) { r.update!(project_id: project.id) }
      )
    end
  end
end
```

::: warning Dynamic boards and column actions
Column actions declared inside a `columns do…end` block **cannot be auto-registered** at class-load time (the block is only evaluated at request time). Declare those interaction classes as top-level definition actions separately:

```ruby
class TaskDefinition < ResourceDefinition
  # Must be a top-level action so the route exists at startup.
  action :archive_project_tasks, interaction: ArchiveProjectTasksInteraction

  kanban do
    columns do
      current_user.projects.map do |project|
        col = Plutonium::Kanban::Column.new(:"project_#{project.id}", ...)
        col.action :archive_project_tasks, interaction: ArchiveProjectTasksInteraction
        col
      end
    end
  end
end
```
:::

### Column options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `label:` | String | `key.to_s.titleize` | Column header text |
| `color:` | Symbol or String | `nil` | Dot color in the column header — `:red`, `:orange`, `:amber`, `:yellow`, `:green`, `:blue`, `:purple`, `:pink`, `:gray`, or a raw CSS value |
| `scope:` | Symbol or Proc | `nil` | Filters the resource relation to this column's cards. Symbol → named scope; Proc → 0-arg lambda called with `instance_exec` on the relation (e.g. `-> { where(status: "todo") }`) |
| `on_drop:` | Symbol or Proc | `nil` | Called when a card lands in this column. Symbol → `record.public_send(sym)`; Proc → 1-arg lambda `->(record) { … }` where `self` is the view context |
| `role:` | `:backlog`, `:done`, `:lost` | `nil` | Preset shorthand (see below) |
| `collapsed:` | Boolean | `false` | Start collapsed |
| `add:` | Boolean | `false` | Show `+ Add` quick-add button |
| `accepts:` | `true`, `false`, Array of keys, or Proc | `true` | Which drops are accepted. `true` = all, `false` = none, `[:doing]` = only from `:doing`. A 1-arg Proc `->(record) { … }` is evaluated **per-card on the server** at drop time and returns a boolean (e.g. `->(task) { task.status == "doing" }`) |
| `locked:` | Boolean | `false` | Prevent dragging cards **out of** this column |
| `wip:` | Integer | `nil` | Work-in-progress limit. Cross-column drops that would exceed this count are rejected |

### Role presets

| Role | Equivalent to |
|------|---------------|
| `:backlog` | `add: true` |
| `:done` | `color: :green, collapsed: true` |
| `:lost` | `color: :red, collapsed: true` |

`:done` and `:lost` are the two terminal roles (both collapsed by default) — the
won/lost pair for pipelines like leads, deals, or tickets; the colour signals the
outcome.

Explicitly provided options override the preset.

**Collapse toggle:** Click the arrow button in any column header to collapse or expand it. Collapsed columns render as a thin vertical strip with the label rotated. The Stimulus controller persists each column's collapsed/expanded state to `localStorage` (key: `pu-kanban:<collection-path>:<column-key>:collapsed`) so the preference survives page reloads. The `collapsed:` DSL option sets the server-rendered initial state; `localStorage` takes precedence on subsequent loads.

---

## Column actions

Declare actions inside a column block to run an interaction against that column's cards:

```ruby
column :done,
  scope: -> { where(status: "done") },
  on_drop: :mark_done! do

  action :archive_all,
    interaction: ArchiveTasksInteraction,   # must be a bulk interaction (has `attribute :resources`)
    on: :all,                               # :all (default) or :visible
    label: "Archive all",
    icon: Phlex::TablerIcons::Archive,
    confirmation: "Archive all done tasks?"
end
```

- `on: :all` — passes IDs of **all** cards in the column (ignoring `per_column`).
- `on: :visible` — passes IDs of only the rendered, `per_column`-capped cards.

Column actions are rendered as buttons in the column header. They open the normal interactive-action modal (with form, authorization, success/failure handling) pre-loaded with the column's card IDs.

---

## Positioning

By default Plutonium uses decimal fractional positioning: cards always slot exactly where you drop them without ever renumbering the whole column. You need:

1. A `decimal` database column (precision ≥ 10, scale ≥ 6 recommended).
2. `include Plutonium::Positioning` in the model.
3. `positioned_on :position, scope: :status` — the `scope:` option groups positions by the grouping attribute so cards in different columns don't compete.

### Position modes

```ruby
kanban do
  # Mode A (default) — delegate to Plutonium::Positioning.
  # Uses :position attribute, requires the model concern.
  position_on :position

  # Mode A with a custom attribute name:
  position_on :sort_order

  # Mode B — BYO positioning. The block receives a Move struct.
  # Use when you want to call a custom service or use a different ordering scheme.
  position_on :sort_order do |move|
    # move.record  — the dropped record
    # move.column  — the destination column key (Symbol)
    # move.prev    — the record immediately before the drop slot (or nil)
    # move.next    — the record immediately after the drop slot (or nil)
    # move.index   — 0-based insertion index within the destination column
    MyPositioningService.call(move.record, prev: move.prev, next: move.next)
  end

  # Mode C — no ordering. Cards render in the relation's default order.
  # On-drop still fires; position is just never updated.
  position_on false
end
```

See [Positioning reference](/reference/kanban/positioning) for the full API and the rebalancing behavior when the decimal gap is exhausted.

---

## Per-column card limit

```ruby
kanban do
  per_column 25
  # ...
end
```

Each column loads at most 25 cards. When the total exceeds the limit, a `+N more` footer appears. Column actions with `on: :visible` respect the cap; `on: :all` ignores it.

---

## Quick-add

When `add: true` (or `role: :backlog`) is set on a column, a `+ Add` button appears in the column header. Clicking it opens the resource's normal new form in a modal, pre-filled with the values that `on_drop` would set.

Authorization: the button is only rendered when `create?` returns `true` in the current policy.

The pre-seeding works by doing a dry-run of `on_drop` against a sentinel record — it intercepts `save!`/`update!` to capture the attribute changes without writing to the database. Exotic `on_drop` callbacks with external side effects (API calls, background jobs) will fire on every `+ Add` click; keep `on_drop` to attribute assignment for clean quick-add behavior.

---

## Authorization

Every drag-and-drop move is authorized by the `kanban_move?` policy predicate. By default it delegates to `update?`. Override it in your policy to decouple board move rights from full edit-form access:

```ruby
class TaskPolicy < ResourcePolicy
  # Board drags require only :member role; full edit requires :admin.
  def kanban_move?
    user.member?
  end

  def update?
    user.admin?
  end
end
```

When `kanban_move?` returns `false`, the board is rendered read-only (dragging is disabled). See [Authorization reference](/reference/kanban/authorization) for details.

---

## Realtime updates

Enable opt-in realtime broadcasting so every viewer of the same board sees moves immediately:

```ruby
kanban do
  realtime true
  # ...
end
```

After a successful move, Plutonium broadcasts the updated column frames to all connected viewers on the same stream. Stream names are tenant-scoped: viewers of different tenant entities can never cross-contaminate each other's streams. See [Reference › Kanban › DSL](/reference/kanban/dsl#realtime) for the stream name format.

### Setup (required for realtime to actually update other viewers)

Plutonium emits the `<turbo-cable-stream-source>` subscription element and broadcasts on the server, but the **client must have an ActionCable consumer** to receive it. Plutonium's bundled JavaScript ships `@hotwired/turbo` only (no cable client), so you must wire the rest up yourself:

1. **Gems** — `turbo-rails` and `actioncable` (Rails includes ActionCable; `turbo-rails` provides `Turbo::StreamsChannel` and `turbo_stream_from`).
2. **Cable adapter** (`config/cable.yml`) — `async` is fine for a single-process dev server; use **Redis** (or Solid Cable) for multi-process production, otherwise a broadcast from one worker won't reach clients connected to another.
3. **Mount ActionCable** — `mount ActionCable.server => "/cable"` (Rails mounts it by default when `action_cable/engine` is loaded).
4. **Load the cable client in your app's JavaScript** — this is the step most people miss. Add **one** of:
   ```js
   // app pack, alongside your other imports
   import "@hotwired/turbo-rails"   // registers <turbo-cable-stream-source> + a consumer
   ```
   …or, if you only want ActionCable:
   ```js
   import * as ActionCable from "@rails/actioncable"
   window.ActionCable ||= ActionCable
   ```
   Without this, the server broadcasts but no browser is subscribed, so other viewers won't update until they reload.

::: tip Verify it
With two browser tabs on the same board, move a card in one — the other should update without a reload. If it doesn't, check the browser console/network for a `/cable` WebSocket connection; a missing connection means the cable client (step 4) isn't loaded.
:::

---

## Lazy loading

By default (`lazy true`), each column is a Turbo Frame that loads its card list on demand when it enters the viewport. Set `lazy false` to load all columns eagerly on the initial page request:

```ruby
kanban do
  lazy false
  # ...
end
```

---

## Switching views

The index page renders a view-switcher toggle when more than one index view is available (`:table`, `:grid`, `:kanban`). Declare the default:

```ruby
class TaskDefinition < ResourceDefinition
  kanban do
    # ...
  end

  # Call AFTER the kanban block — :kanban isn't a valid default until
  # `kanban` has enabled the view. Reversing the order raises ArgumentError
  # at class load.
  default_index_view :kanban
end
```

To make the kanban board the **only** view (hide the switcher), call `index_views :kanban` after the block:

```ruby
class TaskDefinition < ResourceDefinition
  kanban do
    # ...
  end

  index_views :kanban   # drop :table/:grid; kanban is the sole view
end
```
