# Native drag-and-drop for positioned resources

**Date:** 2026-07-31
**Status:** Design approved, pending implementation plan

## Problem

`Plutonium::Positioning` (`lib/plutonium/positioning.rb`) is already standalone and
kanban-independent. A model calls `positioned_on :position, scope: :project_id` and gets
automatic position assignment on create, `reposition!(prev_record:, next_record:)` with
fractional midpoints and gap rebalancing, and a `t.position` migration helper.

Nothing consumes it except kanban. A resource whose model is positioned still renders an
index table with no way to reorder it. The drag-and-drop machinery that would do so exists,
but is welded into `src/js/controllers/kanban_controller.js` (717 lines) and
`Plutonium::Resource::Controllers::KanbanActions`.

This design exposes reordering on ordinary collection surfaces — index tables, nested
association tables, and grid/card views — and extracts the drag mechanics so kanban and the
new surfaces share one implementation.

## Goals

- A resource opts in with one line in its definition and gets drag-to-reorder on every
  collection surface.
- The reposition endpoint is a first-class *hidden action*: real route, real policy
  predicate, rendered nowhere.
- One drag implementation, shared with kanban.
- One positioning strategy machine, shared with kanban — including the block escape hatch
  that lets `acts_as_list`, `positioning`, `ranked-model`, or anything else own the write.
- No regression to kanban's behaviour.

## Non-goals

- Cross-page dragging. Reordering is within-page only.
- Realtime broadcast of reorders. Kanban has it; tables do not, and the design does not
  preclude adding it later.
- Touch drag. Native HTML5 DnD does not fire on touch devices. This limitation is inherited
  from the existing kanban implementation and is not addressed here.

---

## 1. Hidden actions

### Current state

`Action::Base` carries a one-off `@kanban_drop` flag (`lib/plutonium/action/base.rb:26`,
`:84`, `:145`) meaning "this action exists for its route, policy predicate, and params
machinery, but must never render." Its only producer is
`lib/plutonium/definition/index_views.rb:148`, which auto-registers a column's
`enter_interaction`.

Four render sites filter on it:

| Site | Selects |
|---|---|
| `lib/plutonium/ui/page/index.rb:36` | resource actions |
| `lib/plutonium/ui/page/show.rb:18` | record actions |
| `lib/plutonium/ui/table/resource.rb:163` | row actions |
| `lib/plutonium/ui/grid/card.rb:303` | card actions |

Two further sites do **not** filter — both bulk-action selectors:

| Site | Selects |
|---|---|
| `lib/plutonium/ui/grid/resource.rb:95` | `.select { \|k, a\| a.bulk_action? }` |
| `lib/plutonium/ui/table/resource.rb:189` | `.select { \|k, a\| a.bulk_action? && a.condition_met?(view_context) }` |

Today that gap is plugged by an `ArgumentError` in `Plutonium::Kanban::Column`
(`lib/plutonium/kanban/column.rb:38`) which rejects collection-shaped `enter_interaction`s
specifically so they cannot be classified as bulk actions and leak into the bulk bar.

### Change

Rename the concept to `hidden`, and expose it on the action DSL:

```ruby
action :reposition, hidden: true
action :ping_webhook, interaction: PingWebhook, hidden: true
```

A hidden action gets its route, its `name?` policy predicate, and — if interactive — its
form and param extraction. It renders in no toolbar, row dropdown, card, or bulk bar.

- `Action::Base#kanban_drop?` becomes `#hidden?`; `kanban_drop:` is removed from
  `initialize` and `to_options`. It is internal, so there is no deprecation path.
- All six sites above filter on `!a.hidden?`, including both bulk-action selectors. The
  `ArgumentError` in `Kanban::Column` stays as a defence-in-depth check with its comment
  updated — it is no longer the only thing preventing the leak.
- `index_views.rb:148` passes `hidden: true`.

`hidden?` is a **display** gate, not an authorization boundary — the same contract as
`condition:` (`lib/plutonium/action/base.rb:98`). Authorization stays in the policy.

---

## 2. Shared positioning strategy

`Plutonium::Kanban::Positioning::Config` (`lib/plutonium/kanban/positioning.rb`) already
implements exactly the strategy machine tables need — three modes, built by kanban's
`position_on` DSL (`lib/plutonium/kanban/dsl.rb:46`):

| Mode | Built by | Ordering | Write |
|---|---|---|---|
| A `:delegate` | `position_on` / `position_on :attr` | `reorder(attr)` | `record.reposition!(prev_record:, next_record:)` |
| B `:block` | `position_on(:attr) { \|move\| … }` | `reorder(attr)` | the block, given a `Move` |
| C `:disabled` | `position_on false` | unchanged | no-op |

Mode B is the escape hatch for other positioning gems. The framework orders by the declared
attribute and delegates the write entirely:

```ruby
position_on :position do |move|
  move.record.insert_at(move.index + 1)   # acts_as_list
end
```

It is promoted out of the kanban namespace to `Plutonium::Positioning::Config`, alongside
`Plutonium::Positioning::Move`. Both the kanban block and the definition
build the same Config. `Move#column` is `nil` outside a board; every other field is
identical. `Plutonium::Kanban::Positioning` becomes a thin alias so kanban's existing
`position_on` surface is unchanged.

This mirrors the JS drag-core extraction (§5.1) — same reasoning, same shape: one machine,
two consumers.

## 2.1 `position_on` — the definition DSL

```ruby
class TaskDefinition < Plutonium::Resource::Definition
  position_on
end

class Task < ApplicationRecord
  include Plutonium::Positioning
  positioned_on :position, scope: :project_id
end
```

Deliberately the **same verb as kanban's**, not a new one. The signature is identical:

```ruby
position_on                          # Mode A, attribute :position
position_on :sort_order              # Mode A, custom attribute
position_on(:rank) { |move| … }      # Mode B, another gem owns the write
position_on false                    # Mode C, ordering off
```

Reusing the verb keeps the framework at **two** positioning verbs rather than three:
`positioned_on` on the model (how positions are stored) and `position_on` everywhere in the
definition layer (what is orderable). A third name would have been one more thing to learn
and one more near-miss to typo.

`positioned_on` and `position_on` differ by two letters, which is a genuine footgun — but a
**pre-existing** one, since both already coexist today. Reusing `position_on` does not
worsen it; introducing a third verb would have.

In **Mode A** the model remains the single owner of *how* positions are stored — column and
scope. The definition restates neither; `positioned_on`'s `scope:` is never duplicated at the
definition layer. A boot-time error fires if the model does not `include Plutonium::Positioning`.

In **Mode B** that check does not apply — the model need not include the concern at all, since
it never calls `reposition!`. The attribute is still required, because ordering and the
drag-enabled check (§4) key off it.

`position_on` expands to:

```ruby
sort <attribute>
default_sort <attribute>, :asc
action :reposition, hidden: true
# + drag affordances on the resource's collection surfaces
```

Registering `sort <attribute>` is load-bearing, not cosmetic. Dragging is only permitted when
the collection is ordered by that attribute (§4); without a registered sort, `?sort=position`
is not a permitted sort and there is no route back out of the disabled state.

Each expansion is a normal declaration and can be overridden after the fact. A definition
that writes `default_sort :name` after `position_on` gets the disabled-grip state by default,
which is a legitimate choice.

Mode C registers nothing: no sort, no action, no grips. It exists so a resource can inherit a
positioned definition and switch ordering off.

### 2.2 Board inheritance

A kanban board inherits the definition's `position_on`; a `position_on` inside the
`kanban do…end` block overrides it for the board only.

```ruby
class TaskDefinition < Plutonium::Resource::Definition
  position_on :position        # table, grid, nested tables, AND the board

  kanban do
    columns :todo, :doing, :done
  end
end
```

This is what makes the shared verb honest. Without inheritance, `position_on` would mean two
different things depending on which scope it was written in — worse than having two different
names. With it, there is one concept, declared once, overridable where it needs to differ.

It mirrors `show_in`, which already works this way: `Board#show_in_for(definition)`
(`lib/plutonium/kanban/board.rb:37`) is `@show_in || definition.show_in`.

**Implementation note.** A board currently *always* has a config —
`Plutonium::Kanban::DSL` seeds `@position_config = Positioning::Config.default` in its
constructor (`lib/plutonium/kanban/dsl.rb:18`) — so "not declared" and "declared as the
default" are indistinguishable. That seed must become `nil`, with resolution moving to a new
`Board#position_config_for(definition)`:

```ruby
def position_config_for(definition)
  @position_config || definition.defined_position_config || Positioning::Config.default
end
```

Resolution must be **lazy**, not resolved at board-build time. `kanban` eagerly compiles the
board at class-load (`lib/plutonium/definition/index_views.rb:121`), so a board built before
a later `position_on` line would silently miss it — making the declaration order-dependent,
which is exactly the kind of footgun this feature should not ship with.

The five `board.position_config` call sites in `KanbanActions` (lines 136, 259, 581, 733, 784)
become `board.position_config_for(current_definition)`. This is kanban's third touchpoint in
this change, and the most mechanical of the three.

### Scope on nested resources

If `Comment` is `positioned_on :position` with no scope but `CommentDefinition` is nested
under `Post`, positions are global across all comments. Reordering within one post still
behaves correctly — a fractional insert between two visible neighbours lands in the right
place regardless. Only a rebalance renumbers more rows than the author expects.

This is a documented contract, not a runtime check. No boot warning, no derivation of scope
from the request. `scope:` is the model author's job, covered in the docs and the
`plutonium-resource` skill.

---

## 3. Server — the reposition endpoint

`POST <member>/reposition`, params `{prev_id:, next_id:}` — the ids of the dropped row's
visible neighbours. Either is nullable for a drop at an end of the list.

New concern `Plutonium::Resource::Controllers::PositionActions`, routed from
`lib/plutonium/routing/mapper_extensions.rb` alongside the kanban routes (lines 154-155).

### Flow

1. `record = current_authorized_scope.find(params[:id])` — satisfies the scope verifier.
2. `authorize_current! record, to: :reposition?`. `reposition?` is added to
   `Plutonium::Resource::Policy` defaulting to `update?`.
3. Resolve `prev_id` and `next_id` **within the same authorized scope**. A neighbour id that
   does not resolve is treated as drift, not as `nil` — a `nil` would silently mean "drop at
   the end", which is a different and wrong outcome.
4. `config.reposition!(record:, column: nil, prev_record:, next_record:, index:)` — the shared
   Config from §2, so Mode A and Mode B are dispatched identically to how kanban does it. In
   Mode A this reaches `record.reposition!`, which already handles the exhausted-gap rebalance
   internally (`lib/plutonium/positioning.rb:88`).
5. Respond per §3.1.

### 3.1 Response

The client has already moved the row optimistically, so the common case needs no payload.

| Case | Response |
|---|---|
| Mode A, clean drop, no rebalance, both neighbours resolved | `204 No Content` |
| Mode A, `reposition!` triggered a rebalance | `turbo_stream.update` the tbody |
| Mode B, any successful drop | `turbo_stream.update` the tbody |
| A neighbour id did not resolve in scope (drift) | `turbo_stream.update` the tbody |
| Policy denial | `403` + unchanged tbody + toast |
| Validation failure / record gone | `422` + unchanged tbody + toast |

Mode B **always** reconciles. The block is an opaque write — the framework cannot know what it
did, and gems in this space routinely renumber the whole group on every move (`acts_as_list`
does). Optimistically returning `204` there would leave the client's view stale in the common
case rather than the rare one, so Mode B trades the empty-response optimisation for
correctness.

Rejections mirror `render_kanban_rejection` (`kanban_actions.rb:803`): re-render the
collection unchanged so the row snaps back, and append a toast explaining why.

### 3.2 Rebalance signal

The Mode A row above needs to know whether `reposition!` rebalanced. Today it returns the
result of `update!` and discards that fact (`lib/plutonium/positioning.rb:84-94`).

`reposition!` will return a small result value carrying `rebalanced?` rather than have the
controller re-derive it by comparing positions before and after — which would be both racy
and a duplication of the concern's own gap logic.

`Config#reposition!` surfaces this: `rebalanced?` in Mode A, and unconditionally `true` in
Mode B (per §3.1), so the controller has one thing to branch on and no mode-awareness of its
own.

### 3.3 Rescues

Mirror the kanban handlers (`kanban_actions.rb:331-372`), which encode several non-obvious
lessons worth preserving:

- `rescue ::ActionPolicy::Unauthorized` — the leading `::` is required. `Plutonium::ActionPolicy`
  exists, so a bare constant resolves to that namespace and never matches.
- `ActiveRecord::RecordNotFound` — the row was destroyed between render and drop.
- `ActiveRecord::RecordInvalid` — a model callback left the record invalid.

Each streams a snap-back rather than letting an HTML error page get morphed into the table.
Where a rescue fires before `authorize_current!` has bumped its counter, call
`skip_verify_authorize_current!`.

---

## 4. When dragging is permitted

Dragging is enabled only when the collection's effective ordering is the attribute declared
on `position_on` (§2.1) — `:position` by default, whatever the author named otherwise.

| State | Behaviour |
|---|---|
| Ordered by the declared attribute | Grips live |
| Sorted by any other column | Grips disabled |
| Search / filter / scope active, ordered by the attribute | Grips live |
| Page 2+ | Grips live, within-page only |
| Mode C (`position_on false`) | No grips at all |

Filters stay draggable. Dropping between two visible neighbours is well-defined even when
rows are hidden between them — the record lands somewhere among the hidden rows, exactly as
kanban behaves on a filtered board.

A foreign sort is different in kind, not degree: under a name sort the visible neighbours are
in arbitrary position order, so `prev` may hold a *higher* position than `next` and
`position_between` would produce a value that is not between them. Disabling is a
correctness requirement, not a UX preference.

### Escaping the disabled state

A disabled grip is a `<button>` that applies the position sort when clicked, labelled
"Sort by position to reorder". The disabled affordance is itself the way to re-enable it.

This is why `position_on` registers `sort <attribute>`. It also sidesteps a real problem: the
position column is a decimal nobody wants rendered, and
`lib/plutonium/ui/table/resource.rb:154` only produces a sort control
(`current_query_object.sort_params_for(name)`) for *displayed* columns. There is no header to
click, so the grip carries the control instead.

---

## 5. Client

### 5.1 Shared core

Extract the pure drag mechanics from `kanban_controller.js` into `src/js/drag/sortable.js`:
dragstart/dragover/drop wiring, drop-indicator placement, insertion-index computation, and
snap-back. It knows nothing about columns, WIP limits, or boards.

Consumers:

- `src/js/controllers/positioned_controller.js` (new) — tables, nested tables, grids.
  Registered in `src/js/controllers/register_controllers.js`.
- `src/js/controllers/kanban_controller.js` (migrated) — retains everything board-specific:
  columns, collapse, lazy frames, WIP, drop interactions, realtime broadcast.

The extraction is strictly behaviour-preserving. No drag semantics change while code moves.
Kanban's existing suite is the regression gate.

### 5.2 The affordance

The grip lives inside the row's **first cell**, in its left padding. There is no dedicated
grip column.

```
┌──────┬───────────────┬─────────┐
│  ☐   │ Name          │ Status  │
├──────┼───────────────┼─────────┤
│  ☐   │ Ship v2       │ Open    │   idle — grip hidden
│  ☐   │☷ Fix login    │ Open    │   hovered — grip revealed
│  ☐   │ Write docs    │ Done    │   idle
└──────┴───────────────┴─────────┘
```

- Revealed on row hover; always visible on keyboard focus.
- **Only the grip carries `draggable="true"`**, never the `<tr>`.

That last point is the whole reason for this shape. `draggable="true"` on an element
disables text selection within it in every major browser — on a kanban card that costs
nothing, but on a data table it would silently remove the ability to select and copy a cell
value. A draggable row would also fight `row_click_controller.js`
(`src/js/controllers/row_click_controller.js:16`), which already makes the entire row the
Show affordance: a drag that starts and drops in place fires a click and navigates away.

Kanban keeps whole-card dragging. The inconsistency is deliberate — neither concern applies
to a card — and should be stated in the docs rather than smoothed over.

### 5.3 Keyboard support

The grip is a real `<button>`, so it is focusable and reachable by tab. When focused,
`ArrowUp` / `ArrowDown` move the row one slot, posting to the same reposition endpoint with
the appropriate neighbours.

Native HTML5 DnD is mouse-only, so without this the feature is unusable by keyboard. The
cost is small because the endpoint and neighbour computation already exist.

---

## 6. Surfaces

| Surface | Affordance | Notes |
|---|---|---|
| Index table | Hover grip in first cell | Grip doubles as sort-by-position when disabled |
| Nested / association table | Same | Neighbours resolve within the parent-scoped `current_authorized_scope` |
| Grid / card index | Hover grip on the card | `lib/plutonium/ui/grid/card.rb` |
| Kanban board | Unchanged — whole card | Migrated onto the shared core, behaviour identical |

---

## 7. Testing

- `test/plutonium/positioning_test.rb` — extend for the `rebalanced?` result value (§3.2).
- `test/plutonium/kanban/positioning_test.rb` — must pass unchanged against the promoted
  `Plutonium::Positioning::Config` (§2), proving the move is behaviour-preserving. New cases
  for `Move#column` being nil off-board, and for `position_on` building each of the three modes.
- Mode B integration: a dummy-app resource backed by a non-Plutonium positioning strategy,
  asserting the block receives a correct `Move` and that the response always reconciles (§3.1).
- New hidden-action unit tests: route and policy predicate live; absent from all six render
  sites, explicitly including both bulk-action selectors
  (`lib/plutonium/ui/grid/resource.rb:95`, `lib/plutonium/ui/table/resource.rb:189`), which
  are the gap this change closes.
- New `reposition` controller tests: authorization, neighbour-outside-scope drift, rebalance
  reconciliation, each rejection path's snap-back.
- Kanban's existing suite is the regression gate for the JS extraction — it must pass
  unchanged.
- System test driving a real drag in `test/dummy`, plus a keyboard reorder.

## Risks

**Kanban is touched three times** — the `Positioning::Config` promotion (§2), the lazy
`position_config_for` resolution (§2.2), and the JS drag-core extraction (§5.1). All three
reach into a large, working, heavily-tested feature. They are independent of one another,
which is the mitigation: each is behaviour-preserving, each has kanban's existing suite as
its gate, and any can be abandoned without the others.

They are not equally risky. The Config promotion is a namespace move behind an alias, and
`position_config_for` is a mechanical change across five call sites — both are low. The JS
extraction is the outlier, because it touches drag behaviour itself. If it proves invasive,
shipping `positioned_controller.js` standalone and migrating kanban separately remains a
valid fallback, at the cost of two drag implementations that will drift.

**`default_sort` override is implicit.** `position_on` silently changes a resource's default
ordering from `:id, :desc` (`lib/plutonium/definition/sorting.rb:25`) to `:position, :asc`.
This is the correct default, but it is action at a distance and must be documented
prominently.

## Documentation

- `docs/reference/` — a positioning page covering `positioned_on`, `position_on`, the model/
  definition split, the three modes, and the nested-scope contract from §2.1.
- A worked Mode B example for at least one third-party gem (`acts_as_list` is the most
  common), since "can I use my existing positioning gem" is the first question this feature
  will attract.
- Hidden actions in the actions reference.
- Update the `plutonium-resource` and `plutonium-ui` skills.
- Note the deliberate table-vs-kanban affordance difference (§5.2).
