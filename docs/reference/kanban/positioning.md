# Kanban Positioning

Plutonium uses **decimal fractional positioning** for kanban card ordering. Cards always land exactly where you drop them — no renumbering, no integer gaps to exhaust over time.

## `Plutonium::Positioning` concern

Include this concern in any model you want to position:

```ruby
class Task < ApplicationRecord
  include Plutonium::Positioning

  positioned_on :position, scope: :status
end
```

### `positioned_on(column = :position, scope: nil)`

Configures positional ordering for the model.

| Argument | Description |
|----------|-------------|
| `column` | The `decimal` database column that stores positions. Default: `:position` |
| `scope:` | Group positions by this attribute. Records with different scope values are ordered independently. `nil` = single global ordering across all rows |

After calling `positioned_on`, the model gets:
- A `before_create` callback that assigns the next position in the scope group (appends to end).
- A `reposition!(prev_record:, next_record:)` instance method.
- A `backfill_positions!(order: :created_at)` class method.

### Migration

```ruby
class AddPositionToTasks < ActiveRecord::Migration[8.1]
  def change
    add_column :tasks, :position, :decimal, precision: 10, scale: 6
    add_index  :tasks, [:status, :position]  # match your scope attribute
  end
end
```

Or inline in a `create_table`:

```ruby
create_table :tasks do |t|
  t.string  :status,   null: false, default: "todo"
  t.decimal :position, precision: 10, scale: 6
  t.timestamps
end
add_index :tasks, [:status, :position]
```

---

## `reposition!(prev_record:, next_record:)`

Moves a record so it sits between `prev_record` and `next_record` in its scope group. Pass `nil` for an end to prepend or append.

```ruby
task.reposition!(prev_record: card_a, next_record: card_b)
task.reposition!(prev_record: nil, next_record: first_card)  # prepend
task.reposition!(prev_record: last_card, next_record: nil)   # append
```

**Arithmetic:**
- Both nil → `0.0` (first item in empty group)
- Only `prev_record` → `prev.position + 1` (append)
- Only `next_record` → `next.position - 1` (prepend)
- Both present → `(prev.position + next.position) / 2.0` (midpoint)

**Gap exhaustion:** When the gap between two neighbors is smaller than `1e-6` (i.e., repeated insertions at the same slot have subdivided the decimal to the minimum precision), Plutonium automatically rebalances the scope group by assigning fresh integer positions (`1.0, 2.0, 3.0, …`) before computing the new midpoint. The rebalance happens inside a transaction.

---

## `backfill_positions!(order: :created_at)`

Numbers all existing rows per scope group as `1.0, 2.0, 3.0, …` sorted by `order`. Safe to run on an empty table. Use this in a migration or seed task to initialize positions on existing data:

```ruby
# In a migration after adding the column:
Task.backfill_positions!(order: :created_at)
```

---

## `position_on` DSL modes

The `position_on` call inside `kanban do…end` controls how Plutonium persists positions after a drag-and-drop. Three modes are available:

### Mode A — delegate (default)

```ruby
kanban do
  # Implicit: position_on :position
  # Explicit with custom attribute:
  position_on :sort_order
end
```

On drop, Plutonium calls `record.reposition!(prev_record:, next_record:)`. Requires the model to include `Plutonium::Positioning` and call `positioned_on`.

### Mode B — BYO block

```ruby
kanban do
  position_on :sort_order do |move|
    # move.record — the dropped record
    # move.column — destination column key (Symbol)
    # move.prev   — record immediately before the slot (or nil)
    # move.next   — record immediately after the slot (or nil)
    # move.index  — 0-based insertion index within the destination column
    move.record.update!(sort_order: my_position(move.prev, move.next))
  end
end
```

Plutonium orders the column by `sort_order` for display; your block is responsible only for persisting the new value. The block is called with a single `Plutonium::Kanban::Positioning::Move` argument — it is NOT `instance_exec`'d, so `self` is the proc's original binding.

### Mode C — disabled

```ruby
kanban do
  position_on false
end
```

No ordering is applied (relation is returned unchanged). On drop, `on_drop` still fires; the position attribute is never touched. Cards render in the relation's default order.

---

## Pure math helpers

Available as module-level methods without an AR instance:

```ruby
Plutonium::Positioning.position_between(1.0, 3.0)    # => 2.0
Plutonium::Positioning.position_between(nil, 5.0)    # => 4.0  (prepend)
Plutonium::Positioning.position_between(5.0, nil)    # => 6.0  (append)
Plutonium::Positioning.position_between(nil, nil)    # => 0.0  (first item)

Plutonium::Positioning.gap_exhausted?(1.0, 1.0)      # => true
Plutonium::Positioning.gap_exhausted?(1.0, 3.0)      # => false
Plutonium::Positioning.gap_exhausted?(nil, 5.0)      # => false
```

`EPSILON = 1e-6` is the minimum gap before `gap_exhausted?` returns `true`.
