# Kanban DSL Reference

Complete reference for the `kanban do…end` block declared inside a resource Definition.

## Entry point

```ruby
class PostDefinition < ResourceDefinition
  kanban do
    # board-level options + column declarations
  end
end
```

Calling `kanban` automatically adds `:kanban` to `defined_index_views`. To set it as the default view:

```ruby
default_index_view :kanban
```

To make it the only view:

```ruby
index_views :kanban
kanban do ... end
```

---

## Board-level options

### `per_column(n)`

```ruby
per_column 25
```

Maximum cards rendered per column. When the column total exceeds `n`, a `+N more` footer appears. Column actions with `on: :all` still operate against the full column set; `on: :visible` is capped to the rendered subset.

Default: `nil` (unlimited).

---

### `position_on`

Controls how card positions are persisted after a drag-and-drop. Three modes:

#### Mode A — delegate to `Plutonium::Positioning` (default)

```ruby
# Default: uses :position attribute
# (no explicit call needed if the model includes Plutonium::Positioning)

# Custom attribute name:
position_on :sort_order
```

Requires the model to:
1. `include Plutonium::Positioning`
2. Call `positioned_on :position, scope: :grouping_attribute`
3. Have a `decimal` database column for the position attribute

On drop, calls `record.reposition!(prev_record:, next_record:)` which computes the decimal midpoint and updates the record.

#### Mode B — BYO block

```ruby
position_on :sort_order do |move|
  # move is a Plutonium::Kanban::Positioning::Move value object:
  #   move.record  — the dropped ActiveRecord record
  #   move.column  — destination column key (Symbol)
  #   move.prev    — record immediately before the insertion slot, or nil
  #   move.next    — record immediately after the insertion slot, or nil
  #   move.index   — 0-based insertion index within the destination column
  move.record.update!(sort_order: compute_position(move.prev, move.next))
end
```

The block is evaluated via `call` (not `instance_exec`) — it is a plain Ruby proc/lambda.

Plutonium still orders column cards by `sort_order` (the first argument); your block is responsible only for persisting the new value.

#### Mode C — disabled

```ruby
position_on false
```

No ordering is applied. Cards render in the relation's natural order. On drop, only `on_drop` fires (if set); the position attribute is never touched.

---

### `realtime(v = true)` {#realtime}

```ruby
realtime true
```

Enables ActionCable broadcasting after every successful move. After a drop, Plutonium pushes the refreshed column frames to all viewers subscribed to this board's stream.

**Stream name format:**

```
["kanban", "<tenant_gid_or_global>", "<ResourceClass.name>"]
```

- Tenant-scoped portals use the entity's Global ID parameter as the second segment.
- Portals without entity scoping use the literal string `"global"`.

Two viewers share a stream only if they have the same resource class **and** the same scoped entity — cross-tenant leakage is impossible by construction.

Requires `turbo-rails` + ActionCable (gems), a cable adapter in `config/cable.yml` (Redis/Solid Cable in multi-process production), ActionCable mounted at `/cable`, **and** an ActionCable client loaded in your app's JavaScript. Plutonium's bundle ships `@hotwired/turbo` only — without `@hotwired/turbo-rails` (or `@rails/actioncable`) in your pack, the `<turbo-cable-stream-source>` never connects and other viewers won't update. Server-side broadcasting works regardless; this is purely the client subscription. See the [guide's Realtime setup](/guides/kanban#setup-required-for-realtime-to-actually-update-other-viewers).

Default: `false`.

---

### `lazy(v = true)`

```ruby
lazy false   # eager-load all columns on initial page request
```

When `true` (the default), each column is a Turbo Frame that loads its card list on demand (lazy loading). The frame loads when it enters the viewport.

When `false`, all column frames are loaded in the initial page request (one HTTP request per column).

---

### `card_fields(**slots)`

```ruby
card_fields(
  header: :title,
  subheader: :assignee,
  meta: [:due_date, :priority]
)
```

Overrides the slot layout for every kanban card on this board, using the same slot names as `grid_fields` (`:image`, `:header`, `:subheader`, `:body`, `:meta`, `:footer`). The kanban card renderer resolves its slots as `card_fields || definition.grid_fields`, so a board-level `card_fields` takes precedence over the resource's `grid_fields`.

When `card_fields` is not set, cards fall back to the resource definition's `grid_fields`. If neither is declared, the card renders the default header-only layout.

---

## Static columns

Declare columns at class-load time:

```ruby
kanban do
  column :todo,
    label: "To Do",
    color: :blue,
    scope: -> { where(status: "todo") },
    on_drop: ->(r) { r.update!(status: "todo") },
    role: :backlog

  column :done,
    scope: -> { where(status: "done") },
    on_drop: :mark_done!,
    accepts: [:doing],
    role: :done do
    action :archive_all, interaction: ArchiveTasksInteraction, on: :all
  end
end
```

### Column options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `label:` | String | `key.to_s.titleize` | Column header label |
| `color:` | Symbol or String | `nil` | Header color dot. Named colors: `:red`, `:orange`, `:amber`, `:yellow`, `:green`, `:blue`, `:purple`, `:pink`, `:gray`. Raw CSS string also accepted |
| `scope:` | Symbol or Proc | `nil` | Relation filter for this column. **Symbol** → `relation.public_send(sym)` (named AR scope). **Proc** → 0-arg lambda called via `instance_exec` on the relation, e.g. `-> { where(status: "todo") }` |
| `on_drop:` | Symbol or Proc | `nil` | Fired when a card is dropped into this column. **Symbol** → `record.public_send(sym)`. **Proc** → 1-arg lambda `->(record) { … }` where `self` inside the block is the view context (giving access to `current_user`, helpers, etc.). The callback may assign attributes in memory (`r.status = :done`) or call `update!` directly; if the record has unsaved changes after `on_drop` returns the controller saves it automatically. |
| `role:` | `:backlog`, `:done` | `nil` | Applies a preset (see below) |
| `collapsed:` | Boolean | `false` | Column starts collapsed (a thin strip with the label rotated). The Stimulus controller persists the toggled state to `localStorage` (key: `pu-kanban:<path>:<column-key>:collapsed`) so the user preference survives page reloads; this DSL value sets the server-rendered initial state only. |
| `add:` | Boolean | `false` | Show a `+ Add` quick-add button |
| `accepts:` | `true`, `false`, Array, or Proc | `true` | Drop policy. `true` accepts any source column. `false` rejects all drops (display-only column). An Array of column key symbols accepts only those sources. A 1-arg Proc `->(record) { … }` is evaluated **per-card on the server** at drop time (via `accepts_record?`) and returns a boolean — e.g. `->(task) { task.status == "doing" }`. The client-side drag hint treats a Proc column as permissive (`data-kanban-accepts="all"`) since the browser can't run the Proc; the server enforces it precisely on every move |
| `locked:` | Boolean | `false` | Prevent dragging cards **out of** this column |
| `wip:` | Integer | `nil` | WIP limit. Reject cross-column drops when `dest_count + 1 > wip`. Has no effect on same-column reordering |

### Role presets

| Role | Equivalent options |
|------|--------------------|
| `:backlog` | `add: true` |
| `:done` | `color: :green, collapsed: true` |

Explicitly passed options override the preset. Unknown role values raise `ArgumentError`.

---

## Dynamic columns

Use `columns do…end` when the column list depends on the current request:

```ruby
kanban do
  columns do
    # `self` is the view context — current_user, params, and helpers all work.
    current_user.visible_statuses.map do |status|
      Plutonium::Kanban::Column.new(
        :"status_#{status.id}",
        label: status.name,
        color: status.color_symbol,
        scope: -> { where(status_id: status.id) },
        on_drop: ->(r) { r.update!(status_id: status.id) }
      )
    end
  end
end
```

The block is evaluated at request time. You can mix static pre-declared columns with a dynamic block: if both are present, the `columns` block takes precedence (the board is considered dynamic).

::: warning Column action registration for dynamic boards
Column actions declared inside a `columns do…end` block **cannot be auto-registered** at class-load time. Register the interaction as a top-level definition `action` as well:

```ruby
class TaskDefinition < ResourceDefinition
  action :archive_column_tasks, interaction: ArchiveTasksInteraction

  kanban do
    columns do
      build_status_columns.each do |col|
        col.action :archive_column_tasks, interaction: ArchiveTasksInteraction, on: :all
        col
      end
    end
  end
end
```
:::

---

## Column actions

Declare actions inside a column `do…end` block:

```ruby
column :done,
  scope: -> { where(status: "done") },
  on_drop: :mark_done! do

  action :archive_all,
    interaction: ArchiveTasksInteraction,
    on: :all,
    label: "Archive all",
    icon: Phlex::TablerIcons::Archive,
    confirmation: "Archive all done tasks?"
end
```

### Action options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `interaction:` | Class | Yes | An interaction class. Must have `attribute :resources` (plural) — it runs as a bulk action |
| `on:` | `:all` or `:visible` | No (default `:all`) | `:all` passes IDs of all column cards (ignoring `per_column`). `:visible` passes only the rendered, capped subset |
| `label:` | String | No | Button text. Defaults to `key.to_s.humanize` |
| `icon:` | Phlex icon class | No | Icon rendered before the label |
| `confirmation:` | String | No | Browser `confirm()` message shown before the action fires |

Column actions are rendered as small buttons in the column header. They open the standard interactive-action modal with full authorization, form rendering, and success/failure handling.

**Auto-registration:** For static columns, the `kanban` DSL automatically calls `action(key, interaction:, …)` at definition class-load time so the bulk route resolves. For dynamic `columns do…end` boards you must register the interaction manually (see warning above).
