# Positioning & Drag-to-Reorder

Manual ordering for a resource: a decimal `position` column on the model, a `position_on` line in the definition, and Plutonium renders a drag grip on the index **table** and the **card grid** — and on any **nested association table** of the same resource.

Ordering is **fractional**. A drop writes one decimal (the midpoint between its two neighbours), so the common case updates exactly one row. No `UPDATE … SET position = position + 1` sweep across the table.

The same machinery drives the [kanban board](/reference/kanban/), which is why a board and a table share one vocabulary: see [Two verbs, one feature](#two-verbs-one-feature).

## 🚨 Critical

- **The concern is `Plutonium::Positioning::Model`, not `Plutonium::Positioning`.** This changed — see [the upgrade note](#upgrading-from-include-plutonium-positioning) before you touch anything.
- **`position_on` silently sets `default_sort`** when your definition hasn't declared one. See [the warning](#what-position-on-expands-to).
- **The model owns storage; the definition owns the UI.** `positioned_on` (model) says *how positions are stored*. `position_on` (definition) says *this list is orderable*. Never restate the column or the scope in the definition.
- **Dragging is offered only while the collection is sorted ascending by the position attribute.** Under any other sort the grip renders as a link back to that sort, and the server rejects the drop outright.
- **`reposition?` on the policy gates the drop.** It defaults to `update?`. Override it to let someone reorder without granting full edit access — or to forbid reordering while still allowing edits.
- **Prefer [Mode A](#mode-a-delegate) — the framework-owned write.** A block ([Mode B](#mode-b)) is a supported escape hatch for models already ordered by a positioning gem, but it hands you semantics Mode A handles for you. Already on `acts_as_list`? [Migrating](#migrating-off-a-positioning-gem) is a column change, two lines on the model, and a backfill.

## Two verbs, one feature {#two-verbs-one-feature}

There are exactly two, and the split is deliberate:

| Verb | Lives on | Answers |
|---|---|---|
| `positioned_on :column, scope: :attr` | the **model** | *How are positions stored?* Which column, and what groups rows into independent orderings. |
| `position_on` | the **definition** (and inside `kanban do…end`) | *Is this list orderable, and who writes the new position?* |

The definition-layer verb is `position_on` on both a definition and a kanban board — the **same** verb, not a third one. A board with no `position_on` of its own inherits the definition's. So the framework's whole positioning vocabulary is two words, and you learn the board by learning the table.

```ruby
class Task < ApplicationRecord
  include Plutonium::Positioning::Model
  positioned_on :position, scope: :status     # ← storage
end

class TaskDefinition < Plutonium::Resource::Definition
  position_on                                 # ← "this UI can be reordered"
end
```

That second line names neither the column nor the scope. It reads them off the model, and **raises at class-load** if they disagree (see [Mode A](#mode-a-delegate)).

---

## Quick start

**1. Migration** — use the `t.position` helper. It emits a `decimal` column already tuned for fractional ordering (`precision: 16, scale: 8`), so the scale can't be too small to rebalance cleanly. It works in `create_table` and `change_table` alike:

```ruby
create_table :tasks do |t|
  t.string :status, null: false, default: "todo"
  t.position                       # decimal :position, precision: 16, scale: 8
  t.timestamps

  t.index [:status, :position]     # match your scope attribute
end
```

```ruby
t.position :sort_order             # custom column name
t.position index: true             # also add a single-column index
t.position scale: 10               # override precision/scale
```

**2. Model** — include the concern and declare the column:

```ruby
class Task < ApplicationRecord
  include Plutonium::Resource::Record
  include Plutonium::Positioning::Model

  positioned_on :position, scope: :status
end
```

**3. Definition** — one line:

```ruby
class TaskDefinition < Plutonium::Resource::Definition
  position_on
end
```

**4. Existing rows** need positions. `backfill_positions!` numbers every row per scope group as `1.0, 2.0, 3.0, …`:

```ruby
Task.backfill_positions!(order: :created_at)
```

That's it. The index table and the card grid now render a drag grip, `POST /tasks/:id/reposition` is live, and `TaskPolicy#reposition?` (inherited, `= update?`) gates it.

---

## The model layer — `Plutonium::Positioning::Model`

### Upgrading from `include Plutonium::Positioning` {#upgrading-from-include-plutonium-positioning}

::: danger Breaking change — the concern moved down a level
`Plutonium::Positioning` is now a **pure namespace**. The ActiveRecord concern is `Plutonium::Positioning::Model`.

```ruby
# Before
include Plutonium::Positioning

# After
include Plutonium::Positioning::Model
```

`positioned_on`, `reposition!` and `backfill_positions!` are unchanged — only the `include` line moves.

**Why it had to change.** Every constant nested inside an included module joins the including class's constant lookup. While the concern *was* `Plutonium::Positioning`, a bare `Config` written anywhere inside a positioned model resolved to `Plutonium::Positioning::Config` instead of the application's own `::Config` — silently, with no error, in a class the app author never suspected. Splitting the namespace from the mixin stops the leak: `Model` nests nothing.
:::

### `positioned_on(column = :position, scope: nil)`

| Argument | Description |
|---|---|
| `column` | The `decimal` column that stores positions. Default `:position`. |
| `scope:` | Group positions by this attribute. Rows with different scope values are ordered **independently**. `nil` = one global ordering across the whole table. |

After the call the model gains:

- a `before_create` callback assigning the next position **in its scope group** (appends to the end);
- `reposition!(prev_record:, next_record:)`;
- `backfill_positions!(order: :created_at)` on the class.

::: warning Including the concern is not enough
`include Plutonium::Positioning::Model` without a `positioned_on` call installs no `before_create` hook — every row is created with a `NULL` position and the list orders arbitrarily. `position_on` in the definition raises at class-load rather than let that ship.
:::

### `reposition!(prev_record:, next_record:)`

Moves the record so it sits between the two neighbours **within its scope group**. Pass `nil` for an end.

```ruby
task.reposition!(prev_record: a,    next_record: b)     # midpoint
task.reposition!(prev_record: nil,  next_record: first) # prepend
task.reposition!(prev_record: last, next_record: nil)   # append
```

It returns a `Plutonium::Positioning::Result`, whose **`rebalanced?`** tells the caller whether rows *other than this one* moved. That is the signal the drop endpoint uses to decide between "204, nothing to repaint" and "here is the whole collection back".

The arithmetic, the `EPSILON = 1e-6` rebalance threshold, and the pure `Plutonium::Positioning.position_between` / `.gap_exhausted?` helpers are documented in full under [Kanban › Positioning](/reference/kanban/positioning) — the model layer is shared, so there is one description of it and both surfaces point at it.

---

## The definition layer — `position_on`

### Four forms

```ruby
position_on                       # Mode A — follow the model's column  ← use this
position_on :sort_order           # Mode A — must MATCH the model's column
position_on(:rank) { |move| … }   # Mode B — another gem owns the write (escape hatch)
position_on false                 # Mode C — ordering off
```

[Mode A](#mode-a-delegate) is the one to reach for: the framework owns the write, and the bare form cannot disagree with the model. [Mode B](#mode-b) exists for models already ordered by a positioning gem — it is supported and tested, but it hands you semantics Mode A handles, so prefer [migrating off the gem](#migrating-off-a-positioning-gem) where you can.

### What `position_on` expands to {#what-position-on-expands-to}

Every form except `false` also registers three things:

```ruby
sort :position                        # so the column is sortable at all
default_sort :position, :asc          # ⚠ see below
action :reposition, hidden: true      # route + policy predicate, no button
```

The `sort` registration is load-bearing rather than a convenience: dragging is only permitted while the list is in ascending position order, so without a permitted sort there would be **no way back out** of the disabled state.

::: warning `position_on` claims `default_sort`
If your definition has not declared a `default_sort`, `position_on` sets it to `<attribute>, :asc` — replacing the framework default of `id, :desc`. A resource that used to list newest-first will list in position order after you add this line.

That is almost always what you want (a hand-ordered list that ignores its own order is useless), but it is a change you did not write. To keep a different default, just declare one — **in either order**, above or below `position_on`:

```ruby
class TaskDefinition < Plutonium::Resource::Definition
  default_sort :created_at, :desc
  position_on                     # registers `sort :position`, leaves default_sort alone
end
```

`position_on` only claims `default_sort` while nobody has declared one, so an explicit declaration always wins regardless of where it sits in the class body. Note the consequence: with a foreign default sort, the list opens **not draggable** — the grip renders as a link that applies the position sort.

"Explicit" is by declaration, not by value: `default_sort :id, :desc` wins too, even though it names the same field and direction as the framework default. Writing it means you chose it.

**Inherited declarations count.** A base definition is the usual way an app applies one house ordering to every resource, and `position_on` respects it:

```ruby
class ResourceDefinition < Plutonium::Resource::Definition
  default_sort :created_at, :desc   # house style, every resource
end

class TaskDefinition < ResourceDefinition
  position_on                       # inherits :created_at — NOT draggable on open
end
```

Every positioned resource under that base therefore opens in the disabled state until the user clicks the grip. If you want position order to win for a particular resource, declare it there:

```ruby
class TaskDefinition < ResourceDefinition
  position_on
  default_sort :position, :asc
end
```
:::

### Mode A — delegate (the default) {#mode-a-delegate}

The framework owns the write. On drop, Plutonium calls `record.reposition!(prev_record:, next_record:)`.

```ruby
position_on           # follows the model's positioning_column
position_on :position # explicit, and must agree with the model
```

Mode A validates the model **at class-load**, with errors that name the fix:

| Situation | Result |
|---|---|
| Model does not `include Plutonium::Positioning::Model` | `ArgumentError` pointing at the concern, and at Mode B as the escape hatch |
| Model includes it but never calls `positioned_on` | `ArgumentError` — no `before_create`, so every row would sort arbitrarily |
| `position_on :rank` while the model says `positioned_on :position` | `ArgumentError` — the list would be *ordered* by one column while `reposition!` *wrote* another, so dragging would appear to do nothing |

That last one is why the bare form is the recommended one: it cannot disagree with the model.

### Mode B — bring your own positioning gem {#mode-b}

::: tip Reach for Mode A first
Mode A is one word in the definition. The *correct* `acts_as_list` block further down this page is fifteen lines of rank arithmetic, and writing it means already knowing three things neither library's README tells you:

- **`move.index` is page-relative**, while a positioning gem's `insert_at` addresses the whole group;
- **removing a record shifts its neighbours' ranks by one**, in a direction that depends on whether the record started above or below them;
- **a blank `move.prev` means "nothing above me *on screen*"**, not "top of the list".

These docs got two of those three wrong for a while — in the very section written to explain the first. That is the honest case for preferring Mode A. Not that Mode B is broken: it is supported, it is [tested against the real gem](#why-move-index-cannot-be-the-anchor), and the recipe below is correct. But its correctness lives in arithmetic you own and have to keep owning, and Mode A's does not.

Choosing today? Choose Mode A. Already on a positioning gem? [Migrating](#migrating-off-a-positioning-gem) is a column change, two lines on the model, and a backfill.
:::

Give `position_on` a block and Plutonium stops writing positions. It still **orders** the collection by the attribute you name, still renders the grip, still routes and authorizes the drop — but the block persists the new value.

The block receives a single `Plutonium::Positioning::Move`:

| Field | Meaning |
|---|---|
| `move.record` | the dropped record |
| `move.prev` | the record immediately **before** the slot **on the client's page**, or `nil` |
| `move.next` | the record immediately **after** the slot **on the client's page**, or `nil` |
| `move.index` | 0-based insertion index among the other rows **on that page** — see [why it cannot be your anchor](#why-move-index-cannot-be-the-anchor) |
| `move.column` | the destination kanban column key — `nil` on tables and grids, which have no columns |

It is called with `call`, not `instance_exec` — `self` inside the block is wherever you wrote it.

#### What the framework stops doing {#mode-b-handover}

A block is an opaque write. Plutonium cannot know what it touched, or against what notion of "neighbour" it decided, so three things Mode A does are simply not done for you:

| | Mode A | Mode B |
|---|---|---|
| **Hidden boundary neighbours** | resolved server-side before the write, so a drop at the edge of a page anchors to the real row the client couldn't see | not resolved — `resolve_position_boundaries` returns early unless the config delegates. The block gets the client's viewport verbatim, `nil` and all |
| **Drop under a foreign sort** | rejected `422` before any write | not checked server-side. Only the client-side gate applies; the block owns its own notion of neighbours |
| **Response** | `204` when nothing else moved | always `200` + a turbo-stream of the collection |

That last row is not a missing optimisation. Gems in this space routinely renumber the entire group on every move — `acts_as_list` does exactly that — so the client's optimistic DOM is stale by definition. A repaint per drop is the only way the two are guaranteed to agree.

The first two rows are the ones to weigh before choosing Mode B: they are the semantics you are taking on, and the worked example below is what taking them on looks like.

#### Migrating off a positioning gem {#migrating-off-a-positioning-gem}

If nothing external depends on the gem's contiguous integer ranks, moving to Mode A is a column change, two lines on the model, and a backfill.

**1. Change the column.** `acts_as_list` stores contiguous integers; Plutonium stores fractional decimals, and `t.position` emits `decimal(16, 8)` for exactly that reason — a whole-number column would round every midpoint straight back onto a neighbour. `t.position` *adds* a column, so an existing one wants `change_column`:

```ruby
class ChangeTaskPositionToDecimal < ActiveRecord::Migration[8.0]
  def change
    change_column :tasks, :position, :decimal, precision: 16, scale: 8
  end
end
```

**2. Swap the macro on the model.** Note that `scope:` takes a bare Symbol here — the [Array-form trap](#worked-example-acts-as-list) goes away with the gem:

```ruby
class Task < ApplicationRecord
  include Plutonium::Resource::Record

  acts_as_list scope: [:status]              # [!code --]
  include Plutonium::Positioning::Model      # [!code ++]
  positioned_on :position, scope: :status    # [!code ++]
end
```

**3. Number the existing rows.** `backfill_positions!(order:)` walks each scope group and writes `1.0, 2.0, 3.0, …` in `order` order. Pass `order: :position` to keep the ordering the gem already produced:

```ruby
Task.backfill_positions!(order: :position)
```

Then drop the block from the definition — a bare `position_on` is the whole of Mode A.

::: warning `backfill_positions!` is a one-shot
It loads the table, groups it in Ruby, and writes every row with `update_column` — no callbacks, no validations, no `updated_at`. That is what you want for a backfill and not what you want in a request. Run it from a migration or a `rails runner`, once.
:::

#### Worked example: staying on `acts_as_list` {#worked-example-acts-as-list}

For when the gem is not yours to remove — another codepath calls `move_higher`, a report reads the integer ranks, or the migration simply isn't due yet. This block is correct and stays correct; it is just longer than the one word above.

::: danger Anchor off the neighbours, never off `move.index`
`insert_at(move.index + 1)` is the obvious block to write and it is **wrong on any list that paginates or filters** — which, since Plutonium paginates every index at 20 rows by default, means wrong on any list with 21 rows in it. The numbers are in [Why `move.index` cannot be the anchor](#why-move-index-cannot-be-the-anchor). Use the block below.
:::

```ruby
class Task < ApplicationRecord
  include Plutonium::Resource::Record

  # NOTE the Array. `scope: :status` does NOT work: acts_as_list runs a bare
  # Symbol scope through its `idify` helper, which appends `_id` to anything
  # that is neither an association nor already `*_id`. `scope: :status` becomes
  # `scope: :status_id` and every create dies with
  # `NoMethodError: undefined method 'status_id'`. The Array form is literal.
  acts_as_list scope: [:status]   # integer :position, 1-based, contiguous
end

class TaskDefinition < Plutonium::Resource::Definition
  # No Plutonium::Positioning::Model, no positioned_on — acts_as_list owns
  # both the column and the write. Plutonium only orders, routes and authorizes.
  position_on :position do |move|
    record = move.record

    target =
      if move.prev
        # Land immediately after prev. When the record currently sits ABOVE
        # prev, removing it shifts prev up one — so prev's own rank is already
        # the slot the record should occupy.
        (record.position > move.prev.position) ? move.prev.position + 1 : move.prev.position
      elsif move.next
        # Nothing visible above, but rows may still sit above off-page or behind
        # a filter. Land immediately before next, mirrored: when the record
        # currently sits above next, removing it shifts next up one.
        (record.position < move.next.position) ? move.next.position - 1 : move.next.position
      else
        1 # the only row in the list
      end

    record.insert_at(target)
  end
end
```

`insert_at(n)` in `acts_as_list` means "end up at rank `n` after the move", and every rank in the expression above is a **real** rank read off a neighbour record — never a viewport offset. `default_sort :position, :asc` is registered for you, which is exactly the order `acts_as_list` maintains.

Both the `elsif move.next` branch and the `else 1` are load-bearing. A blank `prev` means "nothing above me **on my screen**"; falling straight through to rank 1 sends the row to the top of the whole list, past every row the page or the filter hid.

::: tip `insert_at` swallows a failed save
`insert_at` calls `save`, not `save!`, so a record that fails validation mid-move silently no-ops — the drop answers `200` and the streamed collection shows the row back where it started. Use `insert_at!` if you would rather the endpoint surface the errors as a `422` with a toast — the validation-failure row of [the response table](#the-endpoint).
:::

#### Why `move.index` cannot be the anchor {#why-move-index-cannot-be-the-anchor}

Plutonium hands a Mode B block the client's neighbours **verbatim** — it does not look up the rows pagination or a filter hid, the way Mode A does. So `move.index` is a claim about the **viewport**, while `insert_at` addresses the **whole scope group**. The two only agree on an unfiltered page 1.

These are measured, not reasoned — `test/plutonium/resource/controllers/position_actions_acts_as_list_test.rb` drives each one through `POST <member>/reposition` against the real gem:

| List | Gesture | `insert_at(move.index + 1)` | Anchored off neighbours |
|---|---|---|---|
| 25 rows, page 2 | drag rank 25 between ranks 21 and 22 (`to_index: 1`) | `insert_at(2)` → the row lands at **rank 2**, 20 slots away on page 1 | rank **22**, where it was dropped |
| 25 rows, page 2 | drag rank 25 to the top of page 2 (`prev_id` blank, `to_index: 0`) | `insert_at(1)` → the row lands at **rank 1**, the head of the whole list | rank **21**, below the last row of page 1 |
| 10 rows, filter shows ranks 1 and 10 | drag rank 1 below the filtered row at rank 10 (`to_index: 1`) | `insert_at(2)` → the row moves **one slot**, staying at the top | rank **10**, below the hidden rows |
| 10 rows, filter shows ranks 5 and 10 | drag rank 10 above the filtered row at rank 5 (`prev_id` blank, `to_index: 0`) | `insert_at(1)` → **rank 1**, above four rows the filter hid | rank **5**, immediately above the row it was dropped on |

Mode A has none of this to think about: it resolves hidden boundary neighbours server-side before the write (see [Nested resources & scope groups](#nested-resources-scope-groups)). Mode B is a real escape hatch and the block above is a correct one — the price of the hatch is simply that the semantics are yours. If nothing outside the gem depends on those integer ranks, [the migration](#migrating-off-a-positioning-gem) hands them back.

### Mode C — disabled

```ruby
position_on false
```

No ordering is applied (the relation passes through unchanged), no `sort`/`default_sort` is registered, no `reposition` action is created, and the endpoint answers **404**. Useful to switch a resource's ordering off in one portal while another keeps it — see [portal overrides](/reference/resource/definition).

### Kanban boards inherit the definition's `position_on`

A board resolves its positioning strategy as: **its own `position_on`, else the definition's, else the historic default** (`:position`, Mode A).

```ruby
class TaskDefinition < Plutonium::Resource::Definition
  position_on :sort_order       # table, grid AND board all order by :sort_order

  kanban do
    column :todo
    column :done
  end
end
```

```ruby
class TaskDefinition < Plutonium::Resource::Definition
  position_on :sort_order       # table and grid

  kanban do
    position_on :board_rank     # …but the board overrides it
  end
end
```

Resolution is **lazy**, so declaration order in the class body does not matter — a `kanban do…end` written above `position_on` still picks it up.

---

## When dragging is offered

A drop says "put me between these two rows". That only describes a position when the **visual order is the stored order**. Under a title sort the neighbours say nothing; under a *descending* position sort they say the opposite of what the write would assume.

So the grip is live only when the collection is sorted **ascending, by the position attribute, and by nothing else** — whether that comes from the default sort or from the user clicking the column header. Both halves of the feature enforce the same rule from the same predicate:

- **Client** — the Stimulus controller is not even attached under a foreign sort. There is nothing to drag against.
- **Server** — a Mode A drop arriving under a foreign sort is rejected with `422` **before any write**, and the collection is streamed back with a toast. (Mode B has no server-side sort check: the block owns its own notion of neighbours, so only the client-side gate applies.)

### The disabled grip is the way out of the disabled state

Under a foreign sort the grip does not disappear — it renders as a **link that applies the ascending position sort**. Hiding it would leave the user with no hint that the list is reorderable at all, and no way to make it so. This is precisely why `position_on` registers `sort <attribute>`.

Per record, the grip is also gated on `reposition?`: a row this viewer may not reorder renders exactly as it did before, with no grip at all. Offering an affordance that can only ever answer `403` is worse than offering none.

---

## The affordance: table, grid, and board

| Surface | What you drag | Axis |
|---|---|---|
| Index table | the **grip** in the row's first cell | vertical |
| Card grid | the **grip** in the card's top-left gutter | horizontal, wrap-aware |
| Nested association table | the **grip**, same as the index table | vertical |
| Kanban board | the **whole card** | both (cross-column) |

On a table the grip sits *inside* the first cell, pulled left into padding the cell already had, so the cell's content does not shift by a pixel whether the grip is there or not. It appears on hover, and on keyboard focus.

::: details Why only the grip is draggable on a table — but the whole card is on a board
Two concrete costs of making a `<tr>` draggable, both silent regressions on an ordinary data table:

1. **`draggable="true"` disables text selection inside the element** in every major browser. On a data table that quietly removes the ability to select and copy a cell value.
2. **`row_click_controller` makes the whole row the Show affordance.** A draggable row fights it: a drag that starts and ends in place still fires a click, and the user is navigated away instead of left where they were.

Neither applies to a kanban card — it has no cell text to select and no row-click behaviour — so the board keeps whole-card dragging, which is the better gesture where you can afford it. The inconsistency is deliberate.

A **grid** card gets a grip rather than whole-card dragging, because unlike a kanban card it *does* carry a row-click show affordance: reason 2 applies to it exactly as it does to a table row.
:::

---

## The endpoint — `POST <member>/reposition` {#the-endpoint}

Mounted on every resource (like the kanban move routes). Resources that declare no `position_on` answer `404`.

```
POST /tasks/42/reposition?<the collection's own query string>
     prev_id=41&next_id=43&to_index=2
```

The trailing query string is load-bearing, not decoration: it is the index's own query — search, filters, scope, sort, page, view — and it is what lets the endpoint re-render **exactly the page the user is looking at** through the ordinary index pipeline. Page 3 of a filtered list comes back as page 3 of that filtered list.

The client moves the row **optimistically**, so the response is deliberately quiet in the common case:

| Outcome | Response |
|---|---|
| Clean Mode A drop, both neighbours resolved | `204 No Content` — nothing repaints |
| `reposition!` had to rebalance the group | `200` + turbo-stream of the collection |
| A neighbour did not resolve, or belongs to another positioning group | `200` + stream |
| Mode B (opaque block write) | `200` + stream |
| `reposition?` denied | `403` + stream + toast (the row snaps back) |
| `index?` denied | `403`, **no body** — you may not see the list, so the refusal must not carry it to you |
| Mode A drop under a foreign sort | `422` + stream + toast, **no write** |
| Validation failure, or the record was destroyed meanwhile | `422` + stream + toast |
| No `position_on`, Mode C, or the kanban view is selected | `404` |

### Authorization

```ruby
class TaskPolicy < ResourcePolicy
  # Defaults to update?. Override to decouple the two.
  def reposition? = record.status != "archived"
end
```

Two checks run, in this order:

1. **`index?` on the resource class.** You must be able to *see* a list to reorder it — without this, a policy with `index? == false` but `update? == true` would be handed the whole listing by the reconciliation render.
2. **`reposition?` on the record.**

The same `reposition?` decides whether the grip renders at all, per row.

---

## Nested resources & scope groups {#nested-resources-scope-groups}

`scope:` on `positioned_on` is the **model author's** decision, and Plutonium never second-guesses it from the definition. The two combinations behave differently, and it is worth knowing which you have.

**Scoped to the parent** (the usual case for a nested table):

```ruby
class Catalog::Variant < ApplicationRecord
  include Plutonium::Positioning::Model
  positioned_on :position, scope: :product_id
end
```

Each product's variants are numbered independently. A rebalance touches one product's rows. This is what you want.

**Positioned globally, rendered nested:**

```ruby
positioned_on :position          # scope: nil — one ordering across the whole table
```

Reordering within one parent still works correctly. Positions interleave across parents (product A holds `1.0, 3.0, 5.0` while product B holds `2.0, 4.0`), but because the list is ordered *by position*, the relative order inside A is exactly what the user sees and drags. And when a drop lands at the top or bottom of the visible page, the server looks up the real boundary neighbour in the model's group rather than taking `nil` at face value — which is what stops a bottom-of-page drop writing a position that duplicates a row the client could not see.

The one thing that leaks is a **rebalance**: gap exhaustion renumbers the whole *model-level* group, which with `scope: nil` is every row in the table, including other parents'. Positions stay in the same relative order, so nothing visibly moves — but far more rows are written than the user's gesture suggests. If a resource is normally viewed per-parent, scope it per-parent.

::: tip A neighbour from another group is drift, not an anchor
When the model *is* scoped, the endpoint rejects a neighbour id that resolves to a row in a **different** scope group and reconciles instead. This is not exotic: a `scope: :status` resource lists several groups in one table, with independent and freely interleaved numberings, so anchoring off a neighbour from another group would fling the record to an arbitrary point in its own.
:::

---

## Hidden actions

`position_on` registers `action :reposition, hidden: true`. The flag is general — see [Actions › Hidden actions](/reference/resource/actions#hidden-actions).

A hidden action has a live route, a policy predicate, and (if interactive) the full form/params machinery. It simply renders in **no** toolbar, row dropdown, card, or bulk bar. It is how the framework exposes an endpoint reachable by a gesture rather than a button.

::: danger `hidden: true` is a display gate, NOT an authorization boundary
The route is live. Anyone who can construct the URL can `POST` to it. Authorization lives in the policy — `def reposition?` — and runs whether or not anything rendered.
:::

---

## Accessibility & known limitations

**Keyboard reorder works.** The grip is a real `<button>`, so it is tabbable and carries a screen-reader label. With it focused:

| Key | Effect |
|---|---|
| <kbd>↑</kbd> | move the row/card one slot earlier |
| <kbd>↓</kbd> | move it one slot later |

Focus travels with the row — including across a rebalance, where the whole collection is replaced and focus is restored onto the same record's new grip.

Arrow navigation is deliberately **linear on a grid too**: <kbd>↑</kbd> means the previous *card* in reading order, not the card one line above. A single position attribute stores a one-dimensional order, and two-dimensional navigation could not express the in-between slots at all.

::: warning Drag does not work on touch devices
The drag gesture uses **native HTML5 drag-and-drop**, which browsers do not fire from touch input. This limitation is inherited from the kanban board and applies identically here. Touch users cannot drag to reorder.

There is no automatic fallback. If touch reordering matters for your resource, expose an explicit ordering path — a "move up"/"move down" pair of [record actions](/reference/resource/actions), or a numeric position field on the edit form.
:::

---

## Related

- [Kanban › Positioning](/reference/kanban/positioning) — the shared model API in full: arithmetic, `EPSILON`, rebalancing, `backfill_positions!`, the pure helpers
- [Kanban › DSL](/reference/kanban/dsl) — `position_on` inside `kanban do…end`
- [Actions](/reference/resource/actions) — `hidden:`, `condition:`, and the policy rule
- [Query](/reference/resource/query) — `sort`, `default_sort`
- [Nested resources](/reference/tenancy/nested-resources) — nested association tables
