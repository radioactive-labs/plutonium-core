# Kanban DSL — Design

**Date:** 2026-06-26
**Status:** Design complete and approved through iterative brainstorming. Author-facing DSL and internals settled. No fenced-off explorations remain — terminal/completed column treatment is resolved as **column-scoped actions** (§3.5) plus a **`role: :done`** preset (§3.3).
**Scope:** A declarative kanban board for Plutonium resources, authored in the resource Definition and surfaced as a first-class **index view** (`:kanban`) alongside the existing `:table` and `:grid` views. Lives under a new `Plutonium::Kanban` namespace for its internals.

---

## 1. Goal & Motivation

Plutonium resources can already be viewed as a **table** or a **grid** — these are toggleable *index views* selected by the existing view switcher (`?view=` → per-resource cookie → `default_index_view`). What's missing is a **board**: the same scoped collection rendered as columns of draggable cards, where dragging a card mutates the underlying record.

A kanban is the natural **third member** of the index-view family. It is *not* a separate page, route, or generated file — like grid, you add a block to an existing resource Definition and the `:kanban` view auto-enables.

The board differs from table/grid in one fundamental way: **table and grid are passive layouts; kanban is interactive and mutates data.** That difference is the source of all the genuinely new surface (a move endpoint, positioning, policy-checked drops, optional broadcasting).

### Why mirror the wizard DSL

The `feat/wizard-dsl` branch establishes the pattern this design follows: a declarative author-facing DSL that **compiles to a first-class internal engine** rather than scattering logic across a view. The kanban applies the same shape — DSL in the definition, a real `Plutonium::Kanban::Board` config object internally, a controller concern for the endpoint, a Stimulus controller for drag-drop, an opt-in broadcaster, docs, and a skill.

---

## 2. Locked Decisions

These were settled through brainstorming and are **not open for re-litigation** without explicit user sign-off:

| # | Decision | Choice |
|---|---|---|
| 1 | **Core model** | Hybrid — authored in the resource Definition, compiles to a first-class internal `Plutonium::Kanban::Board` construct. |
| 2 | **Integration** | Extend the existing `IndexViews` system. `:kanban` joins `KNOWN_VIEWS`; the board rides the existing view switcher, `?view=`/cookie resolution, and the index query pipeline. |
| 3 | **Columns** | Explicit column DSL: `column :key, label:, scope:, on_drop:`. `scope:` selects the column's cards; `on_drop:` places a dropped card. They are independent (not assumed inverses). |
| 4 | **Within-column order** | **Persist position, default-on, pluggable** via the `position_on` macro (§5.1). Default (Mode A): shipped decimal positioning on `:position`. Block (Mode B): delegate the write to an existing gem. `position_on false` (Mode C): disabled — scope order, cross-column moves only. |
| 5 | **Access** | View toggle on the index (no separate route). Reuses the existing switcher + param/cookie resolution. |
| 6 | **Real-time** | Opt-in via `realtime true` in the kanban block (Turbo Streams). Default is single-user. |
| 7 | **Card volume** | Per-column cap with a "+N more" indicator (`per_column N`). No global pagination (it produces a meaningless slice across columns). |
| 8 | **Card appearance** | Defaults to the **grid card** rendering (reuses `grid_fields` slots). `card_fields(**slots)` — same API as `grid_fields` — overrides for the board card only. |
| 9 | **Query features** | Search, filters, and scopes are **reused as-is** (they pre-narrow the collection, then columns group). Sorting is **suppressed** in kanban (position governs order). |
| 10 | **Storage** | **No Plutonium-owned tables.** Cards are the resource's own rows; a move is a domain-data update. Only schema requirement: one decimal `position` column on the user's model. |
| 11 | **Column-scoped actions** | A new general primitive (§3.5): `column … do action key, interaction:, on: end`. Acts on a set of the column's cards (`on: :all`/`:visible`) by routing their ids to the existing **`interactive_bulk_action`** (per-record auth). Resolves the "terminal column"; pairs with `role: :done`. `on: :selected` + auto-archive deferred (§8). |
| 12 | **Rendering** | **Lazy per-column turbo frames** (§4.2). The board paints a shell of `<turbo-frame loading="lazy">` column shells; a `kanban_column` endpoint renders each frame's cards. Moves/actions/realtime update only the affected frame(s). Board uses the **un-paginated** relation (Pagy bypassed) and orders each column by `position` (overriding `default_sort`). |
| 13 | **Authorization** | Existing ActionPolicy layer only (§5.3). A move authorizes via one predicate `kanban_move?` → **`update?`** (read-only board if false). **No `permitted_attributes` filtering** — `on_drop` is author code, not user params. Column actions use per-record bulk auth; quick-add uses `create?`. |
| 14 | **Move is an action** | The move is a **direct, non-form record action** (like `destroy`), not a bespoke endpoint — gets routing + policy predicate from the action system, invoked by the drag controller (not a rendered button). Unifies with column actions (bulk) + quick-add (create). |
| 15 | **Rollback ⟂ real-time** | The move POST's **own direct response** re-renders the source+dest frames authoritatively; failure re-renders the unchanged source (snap-back). Works with `realtime` off — broadcasting only mirrors success to *other* viewers. |

---

## 3. Author-facing DSL

A kanban is purely additive to a resource Definition. Declaring the `kanban` block auto-enables the `:kanban` index view, exactly as `grid_fields` auto-enables `:grid`.

```ruby
class TaskDefinition < Plutonium::Resource::Definition
  # Cards reuse the GRID card appearance by default. If grid_fields is
  # declared, kanban cards already look right — no extra card config needed.
  grid_fields(
    header:    :name,
    subheader: :assignee,
    meta:      [:priority, :due_on]
  )

  kanban do
    # --- columns: explicit, ordered; each a scope + a drop rule ---
    column :backlog, label: "Backlog", color: :slate, role: :backlog,  # preset: quick-add intake
      scope:   -> { where(status: :todo, archived: false) },
      on_drop: ->(task) { task.status = :todo }

    column :active, label: "In Progress", color: :amber, wip: 3,  # per-column WIP limit lives ON the column
      scope:   -> { where(status: :doing) },
      on_drop: ->(task) { task.status = :doing; task.started_at ||= Time.current }

    column :done, label: "Done", role: :done,  # preset: success styling + collapsed
      accepts: [:active],        # drop policy: only cards from :active may land here
      scope:   -> { where(status: :done) },
      on_drop: ->(task) { task.status = :done } do
        # column-scoped action (§3.5): runs against the set its `on:` names
        action :archive_all, interaction: ArchiveCompletedTasks, on: :all,
          label: "Archive all", icon: Phlex::TablerIcons::Archive,
          confirmation: "Archive every card in Done?"
      end

    # --- within-column ordering (Decision #4); positioning is pluggable, default-on (§5.1) ---
    # Mode A (DEFAULT): built-in decimal on :position — nothing to declare.
    # position_on :rank                        # Mode A on a different attribute
    # position_on :position do |move|          # Mode B: you apply the write (BYO gem)
    #   move.record.insert_at(move.index)      #   move => record + column + prev + next + index
    # end
    # position_on false                        # Mode C: disabled — scope order, cross-column moves only

    # --- card content (optional; defaults to grid_fields) ---
    # Same API as grid_fields; overrides the grid slots for the board card only.
    # Absent -> reuse grid_fields. Absent both -> a minimal default card.
    card_fields(
      header:    :name,
      subheader: :assignee,
      meta:      [:priority]
    )

    # --- volume (Decision #7) ---
    per_column 25

    # --- multi-user (Decision #6) ---
    realtime true               # broadcast moves via Turbo Streams
  end
end
```

### 3.1 Concepts

| Concept | Meaning |
|---|---|
| **`column key, label:, color:, wip:, scope:, on_drop:`** | An ordered board column. `scope:` selects its cards; `on_drop:` places a dropped card. **Both accept a lambda or a symbol** (§3.2.1): a `scope:` symbol calls that named scope/class method on the resource class (applied to the already-filtered relation); an `on_drop:` symbol calls that method on the dropped record. A lambda `on_drop:` **mutates the record in memory**; the engine performs the `save!`, repositioning, and authorization. `wip:` (optional) is this column's **WIP (Work In Progress)** limit — lives on the column so there's no second list to keep in sync. Plus the **behaviour options** below (§3.3). |
| **column behaviour options** | `collapsed:` (start folded to a count strip, user-toggleable), `add:` (inline quick-add that seeds a new record into the column via its `on_drop`), `accepts:` (drop intake: `true`/`false`/`[source keys]`/predicate), `locked:` (cards can't be dragged out), `role:` (a preset bundling these for an archetype: `:backlog` or `:done`). All optional and individually overridable. See §3.3. |
| **`column … do action … end`** | A column may take a block declaring **column-scoped actions** (§3.5): `action key, interaction:, on:, label:, icon:, confirmation:`. Each acts on a set of the column's cards (`on: :all`/`:visible`) via an interaction, rendered in the column header. |
| **`position_on [:attr] [do \|move\| … end]`** | The single positioning macro (§5.1). **Default-on** (omit it → built-in decimal on `:position`). A symbol picks the order/read attribute; a block makes you own the write (BYO gem), receiving `move` (`record`, `column`, `prev`, `next`, `index`). **`position_on false`** disables positioning (Mode C): scope order, cross-column moves only. |
| **`card_fields(**slots)`** | Card body, **same API as `grid_fields`** (`image/header/subheader/body/meta/footer`). Overrides the grid slots for the board card only. Absent → reuse `grid_fields`; absent both → a minimal default card. |
| **`per_column n`** | Max cards rendered per column; extras collapse into a "+N more" indicator linking to a narrowed view. |
| **`realtime true`** | Opt-in Turbo Stream broadcasting of moves to other open boards. |
| **`columns do … end`** | Dynamic, **request-bound** column builder (§3.4). Evaluated per-request in the board's context (`current_user`, `current_scoped_entity`, `params`, helpers) so columns can be loaded from runtime/tenant data. Alternative to static `column` declarations. |

### 3.2 Key DSL decisions baked in

1. **Cards reuse grid rendering by default** — a kanban card *is* a grid card. Keeps the two card-based views consistent and means grid adopters get kanban cards for free.
2. **`on_drop` mutates in memory; the engine persists** — the lambda only sets attributes; the engine wraps `save!`, recomputes `position`, and enforces the policy so a drop can never bypass `update?` or permitted attributes.
3. **`scope:` selects, `on_drop:` places** — independent by design; the engine never assumes the drop rule is the inverse of the scope.
4. **No generator, no route file** — authoring is additive to a definition; it rides the existing index route plus a new `kanban_move` member action (§5).

### 3.2.1 `scope:` and `on_drop:` accept a lambda **or** a symbol

Both refer to behaviour that often already lives on the model — so a symbol that names it avoids re-wrapping it in a lambda:

```ruby
column :active, label: "In Progress",
  scope:   :in_progress,   # => resource_class.in_progress  (a named AR scope / class method)
  on_drop: :start!         # => record.start!               (an instance method on the model)

column :backlog, label: "Backlog",
  scope:   -> { where(status: :todo) },     # lambda still works
  on_drop: ->(t) { t.status = :todo }       #   for inline logic
```

Resolution:

| Form | `scope:` | `on_drop:` |
|---|---|---|
| **Symbol** | `relation.public_send(:sym)` — a named scope / class method on the resource class, applied to the already-filtered relation. | `record.public_send(:sym)` — an instance method on the model. The method mutates (and may persist); the engine still wraps `save!`, so a non-persisting method works too. |
| **Lambda** | evaluated against the **relation** (Rails scope semantics; `current_user` is *not* in scope here — tenant/user filtering is the policy's job — §6.1). | runs in `ConditionContext(view_context, record)`: mutates the record in memory and *may* use `current_user`; engine persists. |

This keeps simple boards declarative (`scope: :active, on_drop: :start!`) while leaving lambdas for inline/contextual logic. Both forms run through the same policy + positioning + (optional) broadcast path.

### 3.3 Column behaviours & archetypes

Columns are not all interchangeable: an intake column and a terminal column behave differently on screen. Three behaviours are in scope for v1, expressed as overridable options on `column`:

| Option | Behaviour |
|---|---|
| **`collapsed: true`** | Column starts folded to a thin count strip; the user can expand it. Common for long backlogs and finished columns. Collapsibility is always available; this only sets the initial state. |
| **`add: true`** | Renders an inline "+ Add" affordance. Creating a card here seeds a fresh record *into this column* by applying the column's `on_drop` to it, then hands off to the resource's create path. Natural for a backlog/intake column. |
| **`accepts:` / `locked:`** | Drop policy. `accepts:` controls intake — `true` (default), `false` (rejects drops), `[:keys]` (only cards from these source columns), or `->(card) { … }` (predicate). `locked: true` prevents cards being dragged back *out* (a drop-only sink). |

**Archetypes (`role:`)** are thin presets that bundle these for a recognizable column type. Every preset value remains individually overridable on the same `column`. v1 ships two:

- **`role: :backlog`** ⇒ `{ add: true }` — an intake column with quick-add.
- **`role: :done`** ⇒ `{ color: :green, collapsed: true }` — terminal styling, starts folded. The "completed" feel comes from pairing it with a column-scoped action (§3.5, e.g. "Archive all") and/or an `on_drop` that stamps/finishes; those stay explicit rather than baked into the role, because the archive/finish semantics belong to the app's model.

### 3.4 Static vs dynamic (tenant-driven) columns

Boards come in two shapes:

- **Static** — a fixed set of `column` declarations (the §3 example). The columns are known at definition time.
- **Dynamic** — columns built per-request from runtime data via a `columns do … end` block, evaluated in the board's request context (§6.1). This covers tenant-defined stages, user-customizable boards, etc.:

```ruby
kanban do
  columns do
    current_scoped_entity.stages.order(:position).map do |stage|
      column stage.slug, label: stage.name, wip: stage.wip_limit,
        scope:   -> { where(stage_id: stage.id) },
        on_drop: ->(t) { t.stage_id = stage.id }
    end
  end
end
```

`current_scoped_entity` is the **ambient tenant**, always available via the portal's entity strategy. Tenant-driven columns are plain tenancy and stay in the locked design.

### 3.5 Column-scoped actions

A column-scoped action operates on a **set of the column's cards at once** — the new primitive that makes "Archive all in Done", "Assign all backlog to me", or "Export this column" possible. It is *general* (any column, not just terminal), backed by the existing **interaction** system, and declared **inside the column's block** so it lives next to the column it belongs to:

```ruby
column :done, label: "Done", role: :done,
  scope:   -> { where(status: :done) },
  on_drop: ->(t) { t.status = :done } do

  action :archive_all,
    interaction:  ArchiveCompletedTasks,   # an existing Plutonium interaction
    on:           :all,                    # which cards it targets (below)
    label:        "Archive all",
    icon:         Phlex::TablerIcons::Archive,
    confirmation: "Archive every card in Done?"
end
```

**`on:` — the target set (the action specifies it, not a global rule):**

| `on:` | Cards passed to the interaction |
|---|---|
| `:all` (default) | Every record matching the column's `scope` within the **current** filters/search/scope — i.e. the whole column, including overflow beyond `per_column`. The "clear/archive all" semantics. |
| `:visible` | Only the cards currently rendered (respecting the `per_column` cap). Smaller blast radius. |
| `:selected` | The user-selected subset — **requires card-selection UI; deferred to a follow-up** (noted in §8), not built in v1. |

**Mechanics:**
- Rendered in the **column header** (button / overflow menu), gated by the action's policy like any other action.
- On invoke: the engine resolves the target set's **ids** (`on: :all` → the column `scope` ∩ current query; `on: :visible` → the rendered, `per_column`-capped subset) and routes them to the **existing `interactive_bulk_action`** (`GET /…/bulk_actions/:action?ids[]=…`), which **authorizes each record** (`authorize_interactive_bulk_action!`) before running the interaction.
- On success, refreshes only the affected **column frame** (§4.2) via Turbo Stream (and broadcasts if `realtime`). No parallel action stack — column actions *are* bulk actions with a column-derived id set.

---

## 4. Index-view integration (reuses existing machinery)

The board plugs into code that already exists:

| Existing file | Change |
|---|---|
| `lib/plutonium/definition/index_views.rb` | Add `:kanban` to `KNOWN_VIEWS`; declaring `kanban do…end` appends `:kanban` to `defined_index_views` (mirrors `grid_fields`). New class-attributes hold the compiled board config. |
| `lib/plutonium/ui/page/index.rb` | Add `when :kanban then render partial("resource_kanban")` to `render_default_content`. `selected_view` already resolves `:kanban` via `?view=`/cookie/default. |
| `lib/plutonium/ui/table/components/view_switcher.rb` | Add a `kanban` segment (icon + label) to `SEGMENT_LABELS`. (The switcher already renders unknown keys via its fallback, so this is polish.) |
| `lib/plutonium/ui/grid/components/card.rb` | Reused for card rendering (`Card.new(record, resource_definition:, resource_fields:)`) so kanban cards match grid cards; `card_fields` supplies alternate slots. |

Everything else — the toggle UI, param/cookie stickiness, and **search / filters / scopes** feeding the collection — comes for free from the index pipeline.

### 4.1 Query-feature composability

| Feature | On kanban | Rationale |
|---|---|---|
| **Search** | Reused as-is | Narrows the card set across all columns before grouping. |
| **Filters** | Reused as-is | Same — pre-narrows, then columns group. |
| **Scopes** | Reused, with guidance | Pre-filter then group. Compose cleanly **when orthogonal to the column dimension**; a scope on the same attribute the columns group by is a documented authoring smell, not a blocked case. |
| **Sorting** | Suppressed **and `default_sort` overridden** | Within-column order *is* `position`. The board orders each column by `position`, overriding any `default_sort_config` on the query object; the table's column-header sort UI is also absent. |
| **Pagination** | **Bypassed**, replaced by `per_column` | The table view paginates via **Pagy** (`pagy_instance`). The board must consume the **un-paginated, query-applied** relation and cap *per column* (`per_column` + "+N more") — global offset yields a meaningless slice across columns. |

### 4.2 Per-column turbo frames (light rendering)

To keep the board cheap, **each column is its own `<turbo-frame>`**, lazy-loaded:

- The index/kanban render returns the **board shell** — column headers as `<turbo-frame id="kanban-col-<key>" loading="lazy" src="…?view=kanban&column=<key>">`. Cards are *not* in the first paint; each frame fetches **its own** cards in parallel (default **lazy**; eager is a fallback for tiny boards).
- A new lightweight controller action (`kanban_column`) renders one column's cards (the column `scope` ∩ current query, ordered by `position`, capped at `per_column`). This is the frame `src` and the unit of every update.
- **Scoped updates:** a move replaces only the **source + destination** frames (§5 step 8); a column action, "+N more" expansion, and `realtime` broadcasts each target a single frame. The whole board never re-renders.
- **Drag spans frames:** turbo frames are render/update units, not drag boundaries — the Stimulus controller drags across the board; on drop the server returns frame-scoped streams.

---

## 5. The move (a direct, non-form action)

A move is **modeled as a Plutonium action**, not a bespoke endpoint — a *direct* (non-interactive, no form) record action, the same shape as the built-in `destroy` (`action :destroy, route_options: {method: :delete}, record_action: true`). Registering it as an action gives it **routing** and a **policy predicate** for free and puts it in the same family as column actions (bulk) and quick-add (create) — one mental model, no parallel stack.

- **Not a rendered button.** Unlike `destroy`, the move action is invoked by the drag controller, so it's excluded from rendered toolbars/menus — it exists for its route, policy, and handler.
- **Direct, not interactive.** It carries drag params, so it skips the interactive form/commit cycle; `Plutonium::Resource::Controllers::KanbanActions` implements the handler.

**Request payload:** `{ from_column:, to_column:, to_index: }` POSTed to the move action's member route for the card. `from_column` is carried so the engine can enforce the destination's `accepts:`/`locked:` policy (§3.3).

**Server flow (single transaction):**
1. Authorize the move action — predicate **`kanban_move?`**, which **defaults to `update?`** (§5.3). If denied the board is read-only (drag never wires up); a forged request is rejected.
2. Validate the destination's `accepts:`/`locked:` drop policy against `from_column`; reject if disallowed.
3. Look up the target column; apply its `on_drop` (lambda → in-memory mutation; symbol → `record.public_send(:sym)`) against the record (§3.2.1). **No attribute filtering** — `on_drop` is author code, not user params (§5.3).
4. Compute the **fractional** `position` between the neighbors at `to_index` in the destination column (average; ±1 at ends — §5.1).
5. `save!`.
6. (Optional) enforce the destination column's `wip` — reject if `column.scope.count` is already at the limit.
7. Respond with **frame-scoped** Turbo Streams re-rendering the **source + destination** column frames (§4.2) to their **authoritative** server state — never the whole board.

**Success, failure, and why rollback needs no real-time:** the move POST gets a **direct response** (it's the mover's own request). On success the frame re-render reflects the move; on failure (steps 1/2/6) the server re-renders the **unchanged** source column, snapping the dragged card back — an effective rollback driven entirely by the move's own response. **Real-time plays no part here**: broadcasting (§6) only *mirrors* a successful move to *other* viewers' boards; the mover's own correction always comes from its direct response. So rollback works identically whether `realtime` is on or off.

### 5.3 Authorization (minimal — a move is just an update)

A move writes through the author's own `on_drop`; there are **no user-supplied attribute params** to sanitize, so there is **no `permitted_attributes` filtering** for moves. That mechanism guards mass-assignment from *form params* — a move has none, so filtering would be pointless ceremony. The author's lambda *is* the spec of what gets written.

The only check is the yes/no "may this user move cards," answered by the move **action's policy predicate**, a one-line delegating default (exactly like `edit?` delegates to `update?` today):

| Operation | Authorization | Default |
|---|---|---|
| **See a card** | `relation_scope` (`authorized_scope`) | — (board only groups visible records) |
| **Move / reorder** | the move action's predicate `kanban_move?` | **`update?`** → read-only board if false |
| **Column action** | the action's policy method (e.g. `archive_completed?`), **per-record** via `interactive_bulk_action` | the interaction's policy |
| **Quick-add** (`add:`) | `create?` | — |

Want a board draggable by viewers who can't open the edit form? Override `kanban_move?`. Otherwise "can move" = "can update," and **nothing constrains which attributes `on_drop` writes** — that's the author's code, by design.

### 5.1 Positioning (pluggable, default-on)

Positioning is **on by default**, managed by a shipped, kanban-independent module. One macro, `position_on`, expresses all three modes:

```ruby
# (omit position_on)               -> Mode A: built-in decimal on :position  (DEFAULT)
position_on :rank                  -> Mode A on a different attribute
position_on :position do |move|    -> Mode B: order by :position; YOUR block does the write
  move.record.insert_at(move.index) #   (delegate to acts_as_list / positioning / ranked-model)
end
position_on false                  -> Mode C: disabled — scope order, cross-column moves only
```

- **`Plutonium::Positioning` (shipped module).** A general-purpose model concern doing decimal/fractional ordering — kanban-independent, usable anywhere. It is the board's default strategy (Mode A).
- **Decimal mechanics.** A single decimal attribute (conventionally `:position`). Each column renders `column.scope.order(:position)`, so ordering is always *within* a column — no separate "which column am I in" field. On drop at index *i*, `position = (prev + next) / 2` (or `first − 1` / `last + 1` at the ends): O(1), touches only the moved row. When a neighbor gap erodes below a threshold, the engine renumbers that one column in a single pass (rare, column-local).
- **Read vs write.** The symbol names the attribute the board **orders by** when rendering. In Mode A the module also performs the write; in Mode B your block performs the write while the board still orders by that attribute.
- **Block context (`move`).** Carries `record` plus the drop context that's useful: `column` (destination key), `prev`/`next` (neighbor records, `nil` at ends), `index` (target slot). The bundle is extensible.
- **Graceful default.** Mode A assumes a decimal `:position` column. If the model has none, the board **degrades to Mode C** (cross-column moves still work) and emits a dev-mode warning rather than raising — so any resource renders as a board out of the box. *(Flagged for sign-off: alternative is to hard-require the column.)*
- **Seeding & backfill.** Existing rows with `NULL` position have undefined order, so `Plutonium::Positioning` (a) provides a one-shot backfill (number existing rows by a chosen order, e.g. `created_at`) and (b) sets a position on **create** (append to the end of the row's column) — including quick-added cards. Without a position value, a column falls back to its `scope`'s natural order for the un-positioned rows.
- **No owned table** — the attribute lives on the user's model; see §5.2.

### 5.2 No Plutonium-owned tables

Unlike the wizard (which ships `plutonium_wizard_sessions` for transient, cross-request, non-domain state), a kanban has **no transient state**: the cards are the resource's own rows and a move is a plain update to domain data. Therefore kanban introduces **zero owned tables**. The only schema requirement is the decimal `position` column on the user's model (plus the grouping attribute they already have). A migration helper may be provided to add the column, but it lives on the user's table.

---

## 6. Internal architecture (`Plutonium::Kanban` namespace)

Following the wizard pattern — DSL compiles to a real object:

| Unit | Responsibility |
|---|---|
| `Plutonium::Kanban::DSL` | The `kanban do…end` builder; collects columns, ordering, card config, limits, flags. |
| `Plutonium::Kanban::Board` | Compiled config object: ordered columns, card renderer, positioning attr, flags. The first-class construct the engine and components consume. |
| `Plutonium::Kanban::Column` | One column: key, label, color, behaviour options (§3.3), scope lambda, on_drop lambda, wip limit, and any column-scoped `action`s (§3.5). |
| `Plutonium::Kanban::Action` | A compiled column-scoped action: key, interaction, `on:` target (`:all`/`:visible`), label/icon/confirmation. Resolves its target set from the column relation ∩ current query and hands it to the interaction. |
| `Plutonium::Kanban::Context` | The per-request context for the **builder** (`columns do…end`) and **`on_drop`** blocks — a `ConditionContext`-style `SimpleDelegator` over `view_context` exposing `current_user`, `current_scoped_entity`, `params`, helpers (`on_drop` also gets the dragged `record`). **`scope:` lambdas are different** — they evaluate against the **relation** (Rails semantics; tenant/user scoping comes from the policy, not the lambda). See §6.1. |
| `Plutonium::Positioning` | **Shipped, kanban-independent** model concern: decimal/fractional ordering (average neighbors; ends ±1; column-local rebalance on precision exhaustion). The default positioning strategy. |
| `Plutonium::Kanban::Positioning` | Strategy resolution behind the `position_on` macro: Mode A (delegate to `Plutonium::Positioning`), Mode B (invoke the author's block with the `move` context), Mode C / degrade (disabled). |
| `Plutonium::UI::Kanban::Resource` | Phlex board **shell** (lazy column turbo-frames — §4.2), parallel to `Grid::Resource` / `Table::Resource`. |
| `Plutonium::UI::Kanban::Column` | Phlex render of one column's cards (frame body): cards, "+N more", column-action header, WIP badge. |
| `Plutonium::Resource::Controllers::KanbanActions` | Controller concern: the **move** action handler (a direct, non-form action — §5), the lightweight `kanban_column` frame endpoint (§4.2), and column actions (reusing **`interactive_bulk_action`** with the column's card `ids[]` — §3.5). |
| Stimulus `kanban_controller.js` | Cross-frame drag-drop; POSTs the move; **the response re-renders source+dest frames** (success = moved, failure = unchanged source = snap-back). Rollback comes from the move's own response — no dependence on `realtime` (§5). |
| `Plutonium::Kanban::Broadcaster` (opt-in) | `realtime true` → **mirror** a successful move's frame updates to *other* viewers via Turbo Streams, **scoped to tenant + board** (stream name includes `current_scoped_entity` + resource) so updates never leak across tenants. Not involved in the mover's own rollback. |
| Policy hook (in `Plutonium::Resource::Policy`) | `kanban_move?` → `update?` — a single one-line delegating default (like `edit?` → `update?`). No permitted-attributes hook (§5.3). |

---

## 6.1 Request binding & evaluation context

The compiled `Board` is **static config**; it becomes useful only when **bound to a request**. The controller supplies the **already authorized + tenant-scoped** base relation (from `authorized_scope` + the policy's `relation_scope`) and a `Plutonium::Kanban::Context`. **Different blocks bind differently** — this is the precise rule (and a correction to an earlier over-claim that *all* blocks see `current_user`):

| Block | `self` / evaluation | Reaches `current_user` / `current_scoped_entity`? |
|---|---|---|
| **`scope:` lambda** | the **relation** (Rails scope semantics — `where(...)` works), exactly like the definition's `define_scope` bodies | **No.** Tenant/user scoping is the **policy's** job; the base relation is already policy-scoped. Refine it here, don't re-filter by user. |
| **`on_drop:` lambda** | `ConditionContext(view_context, record)` — gets the dragged `record` and delegates to `view_context` | **Yes** (e.g. `t.completed_by = current_user`). |
| **`columns do … end`** builder | the `Kanban::Context` over `view_context` | **Yes** — that's how tenant-driven columns load (`current_scoped_entity.stages`). |

- **Ordering of concerns:** authorization/tenancy filter the collection *first* (controller pipeline) → the Board *groups* the safe relation into columns → search/filters/scopes (§4.1) have already narrowed it.
- **The move action shares the binding** — `on_drop` and positioning run request-bound and policy-checked (§5), so a tenant-driven board mutates correctly and safely.

## 7. Testing strategy

Mirror the wizard branch's depth:

- **Unit** — DSL compilation (`Board`/`Column`/`Action` shape), positioning math (average-of-neighbors, ends, rebalance, on-create seed, backfill), query-feature composition (scope+filter+search feeding columns; `default_sort` overridden).
- **Policy** — `kanban_move?` false ⇒ read-only board (no drag handles, no quick-add); `kanban_move?` defaults to `update?`; a column action over `on: :all` only touches records the per-record bulk auth permits.
- **Integration** — lazy column frames load via `kanban_column`; move across columns updates only source+dest frames; `accepts:`/`locked:` rejection rolls back; reorder within a column; "+N more" overflow; `wip` rejection; a column action routing ids to `interactive_bulk_action`.
- **Realtime** — broadcast fires only when `realtime true`, scoped to tenant+board.
- Dummy-app fixtures: a `Task`-style resource with `status` + decimal `position`.

---

## 8. Out of scope (v1)

- Swimlanes (horizontal grouping).
- Per-column lazy loading / infinite scroll (using per-column cap instead).
- Real-time presence/cursors.
- A scaffold flag on `pu:res:scaffold` (authoring is additive to an existing definition; revisit later).
- **Scheduled auto-archive** for terminal columns (TTL sweep job) — deferred until there's concrete demand (§10).
- **Card selection UI** (`on: :selected` column actions, §3.5) — deferred; v1 ships `on: :all` / `on: :visible`.

---

## 9. Docs & skill

- A `docs/guides/kanban.md` guide + `docs/reference/kanban/*` reference (mirroring the wizard docs).
- A `.claude/skills/plutonium-kanban/SKILL.md` and a router entry in the `plutonium` skill (mirroring `plutonium-wizard`).

---

## 10. Terminal / completed column treatment (RESOLVED)

Formerly an open exploration; now settled and folded into the locked design. The "completed" feel is composed from existing + new locked pieces, not a special column type:

- **Styling + fold:** `role: :done` ⇒ `{ color: :green, collapsed: true }` (§3.3).
- **Stamp / archive on entry:** the column's `on_drop` (e.g. `t.completed_at = Time.current`, or the app's own archive method) — already expressible (§3.2.1).
- **"Clear / archive all":** a **column-scoped action** (§3.5) with `on: :all`, backed by an app interaction.

Deliberately **not** built: scheduled auto-archive (a TTL sweep job) and `on: :selected` card-selection — deferred per §8, to be revisited on demand.
