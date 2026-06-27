# Kanban Boards

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

This is the actual fixture used by Plutonium's test suite, so the syntax is verified.

### 1. Migration

The model needs a `decimal` position column (fractional positioning requires decimal precision).

```ruby
class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.string :status, null: false, default: "todo"
      t.decimal :position, precision: 10, scale: 6
      t.timestamps
    end
    add_index :tasks, [:status, :position]
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
| `color:` | Symbol or String | `nil` | Dot color — `:red`, `:orange`, `:yellow`, `:green`, `:blue`, `:purple`, `:pink`, `:gray`, or a raw CSS value |
| `scope:` | Symbol or Proc | `nil` | Filters the resource relation to this column's cards. Symbol → named scope; Proc → 0-arg lambda called with `instance_exec` on the relation (e.g. `-> { where(status: "todo") }`) |
| `on_drop:` | Symbol or Proc | `nil` | Called when a card lands in this column. Symbol → `record.public_send(sym)`; Proc → 1-arg lambda `->(record) { … }` where `self` is the view context |
| `role:` | `:backlog`, `:done` | `nil` | Preset shorthand (see below) |
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

Explicitly provided options override the preset.

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

This requires ActionCable and `turbo-rails` in your Gemfile. After a successful move, Plutonium broadcasts the updated column frames to all connected viewers on the same stream.

Stream names are tenant-scoped: viewers of different tenant entities can never cross-contaminate each other's streams. See [Reference › Kanban › DSL](/reference/kanban/dsl#realtime) for the stream name format.

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
