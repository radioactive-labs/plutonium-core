# Kanban DSL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a declarative `kanban` board as a first-class index view for Plutonium resources — authored in the resource Definition, rendered as lazy per-column turbo frames, with drag-to-move (a direct action), pluggable decimal positioning, column behaviours/archetypes, column-scoped bulk actions, and opt-in real-time.

**Architecture:** The `kanban do…end` DSL compiles to a `Plutonium::Kanban::Board` config object. `:kanban` joins the existing `IndexViews` system, so the board rides the view switcher, `?view=`/cookie resolution, and the index query pipeline (search/filters/scopes). The board consumes the **un-paginated, authorized** relation, groups it into columns, orders each by a decimal `position`, and renders a shell of lazy `<turbo-frame>` columns. A move is a **direct, non-form action** (`kanban_move?` → `update?`); its response re-renders the source+dest frames authoritatively (rollback needs no real-time). Column actions reuse the existing `interactive_bulk_action`. Positioning ships as a standalone `Plutonium::Positioning` model concern.

**Tech Stack:** Ruby/Rails (Appraisal: rails-7/8.0/8.1), Phlex view components, Stimulus + SortableJS-style drag, Turbo Streams/Frames, ActionPolicy, TailwindCSS 4, esbuild (`yarn build`/`yarn dev`).

**User Verification:** NO — no user feedback/sign-off required by the spec. Verification is automated tests + the maintainer running the dummy app.

**Spec:** `docs/superpowers/specs/2026-06-26-kanban-dsl-design.md` (read it before starting; section refs like §5.1 point there).

---

## Conventions for every task

- **TDD:** write the failing test first, watch it fail, implement minimally, watch it pass, commit.
- **Test command:** `bundle exec appraisal rails-8.1 ruby -Itest <file>` for a single file; `bundle exec appraisal rails-8.1 rake test` for the suite. The plain `bundle exec ruby` won't load rodauth — always go through appraisal.
- **Frontend:** after editing anything in `src/js` or `src/css`, run `yarn build` (writes `app/assets/*`) before integration/system tests; keep `yarn dev` running while iterating.
- **Commit** at the end of each task with the message shown.
- **Do NOT** commit unless the task's final step says to (the repo owner's standing rule is "don't commit unless asked" — this plan explicitly asks, per task).

---

## File Structure (created/modified)

**New — core (`lib/plutonium/`):**
- `lib/plutonium/positioning.rb` — standalone decimal-ordering model concern (Task 1)
- `lib/plutonium/kanban.rb` — namespace requires (Task 2)
- `lib/plutonium/kanban/dsl.rb` — the `kanban do…end` builder (Task 2)
- `lib/plutonium/kanban/board.rb` — compiled board config (Task 2)
- `lib/plutonium/kanban/column.rb` — one column (options, scope, on_drop, actions, behaviours) (Task 2)
- `lib/plutonium/kanban/action.rb` — compiled column-scoped action (Task 2)
- `lib/plutonium/kanban/positioning.rb` — Mode A/B/C strategy resolver behind `position_on` (Task 3)
- `lib/plutonium/kanban/context.rb` — request-bound context for builder/on_drop blocks (Task 4)
- `lib/plutonium/kanban/grouping.rb` — groups an authorized relation into ordered, capped columns (Task 4)
- `lib/plutonium/kanban/broadcaster.rb` — opt-in realtime mirror (Task 14)

**New — controllers (`lib/plutonium/resource/controllers/`):**
- `kanban_actions.rb` — move action handler + `kanban_column` frame endpoint + column-action routing (Tasks 6–8)

**New — UI (`lib/plutonium/ui/kanban/`):**
- `resource.rb` — board shell (lazy column frames) (Task 9)
- `column.rb` — one column's frame body (cards, header, +N more, wip badge) (Task 9, 13)
- `card.rb` — board card (reuses grid card) (Task 9)

**New — assets (`src/`):**
- `src/js/controllers/kanban_controller.js` — drag/move Stimulus controller (Task 11)

**New — tests:** mirrored under `test/plutonium/...` and `test/integration/...` per task.

**Modified:**
- `lib/plutonium/definition/index_views.rb` — add `:kanban` to `KNOWN_VIEWS` + `kanban do…end` DSL entrypoint (Task 0)
- `lib/plutonium/resource/policy.rb` — `kanban_move?` → `update?` (Task 5)
- `lib/plutonium/resource/controller.rb` — include `KanbanActions` (Task 7)
- `lib/plutonium/ui/page/index.rb` — `when :kanban` render branch (Task 10)
- `lib/plutonium/ui/table/components/view_switcher.rb` — `kanban` segment (Task 10)
- `lib/plutonium.rb` — require `positioning` + `kanban` (Tasks 1–2)
- `src/js/controllers/register_controllers.js` — register `kanban` (Task 11)
- `test/dummy/` — fixtures, a board definition, routes (Task 15)
- `docs/` + `.claude/skills/` — guide, reference, skill (Tasks 16–17)

---

## Task 0: Register the `:kanban` index view + `kanban do…end` entrypoint

**Goal:** A definition can declare `kanban do … end`; doing so adds `:kanban` to the resource's enabled index views (mirroring how `grid_fields` auto-enables `:grid`). No rendering yet — just registration + a stored board builder block.

**Files:**
- Modify: `lib/plutonium/definition/index_views.rb`
- Test: `test/plutonium/definition/kanban_index_view_test.rb`

**Acceptance Criteria:**
- [ ] `KNOWN_VIEWS` includes `:kanban`.
- [ ] `kanban { … }` stores the block and appends `:kanban` to `defined_index_views`.
- [ ] Declaring `kanban` does not remove `:table` (it appends, like `grid_fields`).
- [ ] `index_views :kanban` still validates `:kanban` as known.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/kanban_index_view_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test**

```ruby
# test/plutonium/definition/kanban_index_view_test.rb
require "test_helper"

class KanbanIndexViewTest < ActiveSupport::TestCase
  def def_class(&blk)
    Class.new(Plutonium::Resource::Definition) do
      class_eval(&blk) if blk
    end
  end

  test "declaring kanban enables the :kanban view alongside :table" do
    klass = def_class { kanban { } }
    assert_includes klass.defined_index_views, :kanban
    assert_includes klass.defined_index_views, :table
  end

  test "kanban stores the builder block" do
    klass = def_class { kanban { } }
    assert_kind_of Proc, klass.defined_kanban_block
  end

  test ":kanban is a known view" do
    assert_includes Plutonium::Definition::IndexViews::KNOWN_VIEWS, :kanban
  end
end
```

- [ ] **Step 2: Run → FAIL** (`NoMethodError: undefined method 'kanban'`).

- [ ] **Step 3: Implement** in `lib/plutonium/definition/index_views.rb`:

```ruby
KNOWN_VIEWS = %i[table grid kanban].freeze
```

Add a class_attribute in the `included do` block:

```ruby
class_attribute :defined_kanban_block, default: nil, instance_accessor: false
```

Add the class method (next to `grid_fields`):

```ruby
# Declares a kanban board for this resource and enables the :kanban
# index view (mirrors how grid_fields enables :grid). The block is the
# `kanban do…end` DSL, compiled lazily into a Plutonium::Kanban::Board.
def kanban(&block)
  self.defined_kanban_block = block
  self.defined_index_views = defined_index_views + [:kanban] unless defined_index_views.include?(:kanban)
end
```

Add the instance reader near the others:

```ruby
def defined_kanban_block = self.class.defined_kanban_block
```

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/definition/index_views.rb test/plutonium/definition/kanban_index_view_test.rb
git commit -m "feat(kanban): register :kanban index view + kanban DSL entrypoint"
```

```json:metadata
{"files": ["lib/plutonium/definition/index_views.rb", "test/plutonium/definition/kanban_index_view_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/kanban_index_view_test.rb", "acceptanceCriteria": ["KNOWN_VIEWS includes :kanban", "kanban{} appends :kanban and stores block", "table not removed"], "requiresUserVerification": false}
```

---

## Task 1: `Plutonium::Positioning` — standalone decimal ordering concern

**Goal:** A model concern providing fractional position: read/order by a decimal column, insert between two neighbors (average; ±1 at ends), column-local rebalance on precision exhaustion, seed on create, and a one-shot backfill. Kanban-independent (§5.1).

**Files:**
- Create: `lib/plutonium/positioning.rb`
- Modify: `lib/plutonium.rb` (require it)
- Test: `test/plutonium/positioning_test.rb`

**Acceptance Criteria:**
- [ ] `position_between(prev_val, next_val)` returns the midpoint; `nil` prev → `next - 1`; `nil` next → `prev + 1`; both nil → `0`.
- [ ] When the gap `(next - prev).abs < EPSILON`, `reposition!` triggers a column-local renumber and still lands the row in order.
- [ ] Including the concern with `positioned_on :position, scope: :status` sets a `position` on create (append to end of the row's scope group).
- [ ] `Model.backfill_positions!(order: :created_at)` numbers existing rows per scope group, 1.0, 2.0, ….

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test** — exercises the pure math + the AR integration using a throwaway table.

```ruby
# test/plutonium/positioning_test.rb
require "test_helper"

class PositioningTest < ActiveSupport::TestCase
  # Pure midpoint math (no DB)
  test "position_between midpoint and ends" do
    calc = Plutonium::Positioning
    assert_equal 1.5, calc.position_between(1.0, 2.0)
    assert_equal 1.0, calc.position_between(2.0, nil)   # after last -> +1 ... see note
    assert_equal(-1.0, calc.position_between(nil, 0.0)) # before first -> -1
    assert_equal 0.0, calc.position_between(nil, nil)
  end
end
```

> Implementation note: define ends as `prev + 1` / `next - 1`. Adjust the test literals to match the exact convention you implement; keep them concrete.

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement** `lib/plutonium/positioning.rb`:

```ruby
# frozen_string_literal: true

module Plutonium
  # Standalone decimal/fractional ordering. Kanban-independent.
  module Positioning
    extend ActiveSupport::Concern

    EPSILON = 1e-6

    # Pure midpoint helpers (module functions, no DB).
    module_function

    def position_between(prev_val, next_val)
      return 0.0 if prev_val.nil? && next_val.nil?
      return next_val - 1 if prev_val.nil?
      return prev_val + 1 if next_val.nil?
      (prev_val + next_val) / 2.0
    end

    def gap_exhausted?(prev_val, next_val)
      return false if prev_val.nil? || next_val.nil?
      (next_val - prev_val).abs < EPSILON
    end

    included do
      class_attribute :positioning_column, instance_accessor: false, default: :position
      class_attribute :positioning_scope_attr, instance_accessor: false, default: nil
    end

    class_methods do
      # @param column [Symbol] decimal attribute holding order
      # @param scope [Symbol, nil] attribute that partitions ordering (e.g. :status)
      def positioned_on(column = :position, scope: nil)
        self.positioning_column = column
        self.positioning_scope_attr = scope
        before_create :assign_initial_position
      end

      # One-shot: number existing rows per scope group by `order`.
      def backfill_positions!(order: :created_at)
        groups = positioning_scope_attr ? all.group_by(&positioning_scope_attr) : {nil => all.to_a}
        groups.each_value do |rows|
          rows.sort_by { |r| r.public_send(order) }.each_with_index do |row, i|
            row.update_column(positioning_column, (i + 1).to_f)
          end
        end
      end
    end

    # Place this record between two neighbor records (either may be nil) and persist.
    def reposition!(prev_record:, next_record:)
      col = self.class.positioning_column
      prev_val = prev_record&.public_send(col)
      next_val = next_record&.public_send(col)
      if Plutonium::Positioning.gap_exhausted?(prev_val, next_val)
        rebalance_scope_group!
        prev_val = prev_record&.reload&.public_send(col)
        next_val = next_record&.reload&.public_send(col)
      end
      update!(col => Plutonium::Positioning.position_between(prev_val, next_val))
    end

    private

    def assign_initial_position
      col = self.class.positioning_column
      return if public_send(col).present?
      max = positioning_group_relation.maximum(col) || 0.0
      public_send("#{col}=", max + 1)
    end

    def positioning_group_relation
      rel = self.class.all
      attr = self.class.positioning_scope_attr
      attr ? rel.where(attr => public_send(attr)) : rel
    end

    def rebalance_scope_group!
      col = self.class.positioning_column
      positioning_group_relation.order(col).each_with_index do |row, i|
        row.update_column(col, (i + 1).to_f)
      end
    end
  end
end
```

Add to `lib/plutonium.rb` (with the other `require`s):

```ruby
require "plutonium/positioning"
```

- [ ] **Step 4:** Add DB-backed tests (throwaway table via a migration in the test, or reuse an existing dummy model with a `position` column — prefer the dummy `Task` fixture introduced in Task 15 if ordering of tasks allows; otherwise create an ad-hoc table in setup). Cover: create assigns position; reposition between two rows; rebalance on exhausted gap; backfill. Run → PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/positioning.rb lib/plutonium.rb test/plutonium/positioning_test.rb
git commit -m "feat(positioning): standalone decimal ordering concern"
```

```json:metadata
{"files": ["lib/plutonium/positioning.rb", "lib/plutonium.rb", "test/plutonium/positioning_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning_test.rb", "acceptanceCriteria": ["midpoint + ends math", "rebalance on exhausted gap", "seed on create", "backfill_positions!"], "requiresUserVerification": false}
```

---

## Task 2: Kanban DSL → Board / Column / Action compilation

**Goal:** The `kanban do…end` builder compiles to immutable config: a `Board` (ordered columns, card config, per_column, realtime, positioning config, lazy flag), `Column`s (key/label/color/wip/scope/on_drop/behaviours/actions), and `Action`s (key/interaction/on/label/icon/confirmation). Pure data — no request, no DB.

**Files:**
- Create: `lib/plutonium/kanban.rb`, `lib/plutonium/kanban/dsl.rb`, `lib/plutonium/kanban/board.rb`, `lib/plutonium/kanban/column.rb`, `lib/plutonium/kanban/action.rb`
- Modify: `lib/plutonium.rb`
- Test: `test/plutonium/kanban/dsl_test.rb`

**Acceptance Criteria:**
- [ ] `Plutonium::Kanban::DSL.build(&block)` returns a `Board`.
- [ ] `column :k, label:, color:, wip:, scope:, on_drop:` + behaviour opts (`collapsed:`, `add:`, `accepts:`, `locked:`, `role:`) compile to a `Column`; columns keep declaration order.
- [ ] A column block declaring `action :k, interaction:, on:` compiles to an `Action` on that column.
- [ ] `role: :backlog` ⇒ `add: true`; `role: :done` ⇒ `color: :green, collapsed: true` (explicit opts override the role).
- [ ] `scope:`/`on_drop:` accept a Proc **or** a Symbol; stored verbatim (resolution happens at request time).
- [ ] `card_fields(**slots)`, `per_column n`, `realtime true`, `position_on …` stored on the Board.
- [ ] `columns do … end` stores a dynamic builder block (mutually exclusive with static `column`s at render time — validated in Task 4).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/dsl_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test**

```ruby
# test/plutonium/kanban/dsl_test.rb
require "test_helper"

class KanbanDslTest < ActiveSupport::TestCase
  def build(&blk) = Plutonium::Kanban::DSL.build(&blk)

  test "static columns compile in order with options" do
    board = build do
      column :todo, label: "To Do", scope: -> { where(status: :todo) }, on_drop: ->(t) { t.status = :todo }
      column :doing, label: "Doing", wip: 3, scope: :in_progress, on_drop: :start!
    end
    assert_equal %i[todo doing], board.columns.map(&:key)
    assert_equal 3, board.columns[1].wip
    assert_equal :in_progress, board.columns[1].scope   # symbol stored verbatim
  end

  test "role presets apply but are overridable" do
    board = build do
      column :backlog, role: :backlog, scope: -> {}, on_drop: ->(_) {}
      column :done, role: :done, collapsed: false, scope: -> {}, on_drop: ->(_) {}
    end
    assert board.columns[0].add?            # from role
    assert_equal :green, board.columns[1].color
    refute board.columns[1].collapsed?      # explicit override wins
  end

  test "column action compiles" do
    board = build do
      column :done, scope: -> {}, on_drop: ->(_) {} do
        action :archive, interaction: :archive_int, on: :all, label: "Archive"
      end
    end
    act = board.columns[0].actions.first
    assert_equal :archive, act.key
    assert_equal :all, act.on
  end

  test "board-level config" do
    board = build do
      per_column 25
      realtime true
      card_fields(header: :name)
    end
    assert_equal 25, board.per_column
    assert board.realtime?
    assert_equal({header: :name}, board.card_fields)
  end
end
```

- [ ] **Step 2: Run → FAIL.**

- [ ] **Step 3: Implement.** `Action` (Struct-like), `Column` (with `role` expansion + behaviour predicates + an `action` collector used when its block runs), `Board`, and `DSL` (an instance_eval target collecting columns + board config). Key code:

`lib/plutonium/kanban/action.rb`:

```ruby
# frozen_string_literal: true
module Plutonium
  module Kanban
    Action = Data.define(:key, :interaction, :on, :label, :icon, :confirmation) do
      def initialize(key:, interaction:, on: :all, label: nil, icon: nil, confirmation: nil)
        super
      end
    end
  end
end
```

`lib/plutonium/kanban/column.rb`:

```ruby
# frozen_string_literal: true
module Plutonium
  module Kanban
    class Column
      ROLE_PRESETS = {
        backlog: {add: true},
        done: {color: :green, collapsed: true}
      }.freeze

      attr_reader :key, :label, :color, :wip, :scope, :on_drop, :accepts, :actions

      def initialize(key, label: nil, color: nil, wip: nil, scope: nil, on_drop: nil,
        collapsed: nil, add: nil, accepts: nil, locked: nil, role: nil)
        preset = role ? ROLE_PRESETS.fetch(role, {}) : {}
        @key = key.to_sym
        @label = label || key.to_s.titleize
        @color = color.nil? ? preset[:color] : color
        @wip = wip
        @scope = scope
        @on_drop = on_drop
        @collapsed = collapsed.nil? ? preset[:collapsed] : collapsed
        @add = add.nil? ? preset[:add] : add
        @accepts = accepts.nil? ? true : accepts
        @locked = locked || false
        @actions = []
      end

      # Collected when the column's block runs (see DSL#column).
      def action(key, interaction:, on: :all, label: nil, icon: nil, confirmation: nil)
        @actions << Action.new(key: key.to_sym, interaction:, on:, label:, icon:, confirmation:)
      end

      def collapsed? = !!@collapsed
      def add? = !!@add
      def locked? = @locked

      # Does this column accept a card dragged from `source_key`?
      # (used by the move action, Task 7). Proc form is evaluated per-card
      # at move time, so here it permits and the handler applies the predicate.
      def accepts?(source_key)
        case @accepts
        when Array then @accepts.include?(source_key)
        when true, false then @accepts
        else true
        end
      end
    end
  end
end
```

`lib/plutonium/kanban/board.rb`:

```ruby
# frozen_string_literal: true
module Plutonium
  module Kanban
    class Board
      attr_reader :columns, :columns_block, :card_fields, :per_column,
        :position_config, :lazy

      def initialize(columns:, columns_block:, card_fields:, per_column:, realtime:, position_config:, lazy:)
        @columns = columns
        @columns_block = columns_block
        @card_fields = card_fields
        @per_column = per_column
        @realtime = realtime
        @position_config = position_config   # see Task 3
        @lazy = lazy
        freeze
      end

      def realtime? = !!@realtime
      def dynamic? = !@columns_block.nil?
    end
  end
end
```

`lib/plutonium/kanban/dsl.rb`:

```ruby
# frozen_string_literal: true
module Plutonium
  module Kanban
    class DSL
      def self.build(&block)
        dsl = new
        dsl.instance_eval(&block) if block
        dsl.to_board
      end

      def initialize
        @columns = []
        @columns_block = nil
        @card_fields = nil
        @per_column = nil
        @realtime = false
        @position_config = Positioning::Config.default   # Task 3
        @lazy = true
      end

      def column(key, **opts, &blk)
        col = Column.new(key, **opts)
        col.instance_eval(&blk) if blk   # collects `action ...`
        @columns << col
      end

      def columns(&blk) = @columns_block = blk
      def card_fields(**slots) = @card_fields = slots
      def per_column(n) = @per_column = n
      def realtime(v = true) = @realtime = v
      def lazy(v = true) = @lazy = v
      def position_on(attr = :position, &blk) = @position_config = Positioning::Config.new(attr, false, blk)
      # `position_on false` disables:
      def disable_positioning! = @position_config = Positioning::Config.disabled

      def to_board
        Board.new(columns: @columns, columns_block: @columns_block, card_fields: @card_fields,
          per_column: @per_column, realtime: @realtime, position_config: @position_config, lazy: @lazy)
      end
    end
  end
end
```

> Handle `position_on false`: in `position_on`, if the first arg is `false`, set disabled config. Keep the signature `position_on(attr = :position, &blk)` and branch on `attr == false`.

`lib/plutonium/kanban.rb`:

```ruby
# frozen_string_literal: true
require "plutonium/kanban/positioning"
require "plutonium/kanban/action"
require "plutonium/kanban/column"
require "plutonium/kanban/board"
require "plutonium/kanban/dsl"
```

Add `require "plutonium/kanban"` to `lib/plutonium.rb` (after positioning).

- [ ] **Step 4: Run → PASS.**

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/kanban.rb lib/plutonium/kanban/ lib/plutonium.rb test/plutonium/kanban/dsl_test.rb
git commit -m "feat(kanban): compile kanban DSL into Board/Column/Action config"
```

```json:metadata
{"files": ["lib/plutonium/kanban/dsl.rb", "lib/plutonium/kanban/board.rb", "lib/plutonium/kanban/column.rb", "lib/plutonium/kanban/action.rb", "lib/plutonium/kanban.rb", "lib/plutonium.rb", "test/plutonium/kanban/dsl_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/dsl_test.rb", "acceptanceCriteria": ["columns compile in order", "role presets overridable", "actions compile", "board config stored", "scope/on_drop accept proc or symbol"], "requiresUserVerification": false}
```

---

## Task 3: Positioning strategy resolver (`position_on` Mode A/B/C)

**Goal:** Resolve the board's `position_config` to a strategy: Mode A (delegate to `Plutonium::Positioning`), Mode B (author block does the write), Mode C (disabled). Provide `Config` (used in Task 2) and a `Strategy#reposition!(record, prev:, next:, index:, column:)`.

**Files:**
- Create: `lib/plutonium/kanban/positioning.rb`
- Test: `test/plutonium/kanban/positioning_test.rb`

**Acceptance Criteria:**
- [ ] `Config.default` → Mode A on `:position`; `Config.new(:rank, …)` → Mode A on `:rank`; with a block → Mode B; `Config.disabled` → Mode C.
- [ ] Mode A `reposition!` calls the record's `Plutonium::Positioning#reposition!` with neighbor records.
- [ ] Mode B `reposition!` calls the author block with a `move` carrying `record, column, prev, next, index`.
- [ ] Mode C `reposition!` is a no-op (and the board orders by column scope, asserted in Task 4).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/positioning_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test** with a fake record capturing calls (Mode A/B) and a no-op assertion (Mode C). Use a `Struct` double exposing `reposition!`.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** `Plutonium::Kanban::Positioning` with `Config` (Data) + `Strategy` resolving on mode. `move` is a `Data.define(:record, :column, :prev, :next, :index)`.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/kanban/positioning.rb test/plutonium/kanban/positioning_test.rb
git commit -m "feat(kanban): position_on strategy resolver (Mode A/B/C)"
```

```json:metadata
{"files": ["lib/plutonium/kanban/positioning.rb", "test/plutonium/kanban/positioning_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/positioning_test.rb", "acceptanceCriteria": ["Config default/attr/block/disabled", "Mode A delegates", "Mode B yields move", "Mode C no-op"], "requiresUserVerification": false}
```

---

## Task 4: Request binding — `Context` + `Grouping`

**Goal:** Bind a `Board` to a request: build the column set (static, or via `columns do…end` in a `Context` exposing `current_user`/`current_scoped_entity`/`params`/helpers), then group the **authorized, un-paginated** relation into ordered, `per_column`-capped buckets — ordering each column by the positioning attribute (overriding any `default_sort`).

**Files:**
- Create: `lib/plutonium/kanban/context.rb`, `lib/plutonium/kanban/grouping.rb`
- Test: `test/plutonium/kanban/grouping_test.rb`

**Acceptance Criteria:**
- [ ] `Context` is a `SimpleDelegator` over `view_context` exposing `current_user`, `current_scoped_entity`, `params` (mirrors `Plutonium::Action::ConditionContext`).
- [ ] `Grouping.call(board:, relation:, context:)` returns ordered `[{column:, cards:, total:}]`.
- [ ] A column's `scope:` Proc is evaluated **against the relation** (`relation.instance_exec(&scope)`); a Symbol calls `relation.public_send(sym)`.
- [ ] Cards are ordered by the positioning attr (Mode A/B) — overriding `default_sort`; Mode C uses the column scope's own order.
- [ ] `per_column` caps `cards` and reports `total` (for "+N more").
- [ ] Dynamic boards (`columns do…end`) build columns from the context.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/grouping_test.rb` → PASS

**Steps:**

- [ ] **Step 1: Failing test** using a dummy model (use the `Task` fixture from Task 15 if available; otherwise an ad-hoc table). Assert ordering-by-position overrides a `default_sort`, scope Proc vs Symbol both work, and `per_column` caps with correct `total`.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement.** `Context` mirrors `ConditionContext` (`SimpleDelegator.new(view_context)`). `Grouping`:

```ruby
# frozen_string_literal: true
module Plutonium
  module Kanban
    module Grouping
      module_function

      def call(board:, relation:, context:)
        columns = resolve_columns(board, context)
        pos = board.position_config
        columns.map do |col|
          scoped = apply_scope(relation, col.scope, context)
          ordered = pos.order(scoped)            # by position attr, or scope order in Mode C
          total = ordered.count
          cards = board.per_column ? ordered.limit(board.per_column).to_a : ordered.to_a
          {column: col, cards:, total:}
        end
      end

      def resolve_columns(board, context)
        return board.columns unless board.dynamic?
        Array(context.instance_exec(&board.columns_block)).flatten
      end

      def apply_scope(relation, scope, context)
        case scope
        when Symbol then relation.public_send(scope)
        when Proc   then relation.instance_exec(&scope)
        when nil    then relation
        else relation.merge(scope)
        end
      end
    end
  end
end
```

> `pos.order(scoped)` lives on the positioning `Strategy` (Task 3): Mode A/B → `scoped.reorder(attr)`; Mode C → `scoped` unchanged. `reorder` (not `order`) is what overrides `default_sort`.

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/kanban/context.rb lib/plutonium/kanban/grouping.rb test/plutonium/kanban/grouping_test.rb
git commit -m "feat(kanban): request context + relation grouping into ordered columns"
```

```json:metadata
{"files": ["lib/plutonium/kanban/context.rb", "lib/plutonium/kanban/grouping.rb", "test/plutonium/kanban/grouping_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/grouping_test.rb", "acceptanceCriteria": ["context exposes current_user/entity", "scope proc+symbol", "order overrides default_sort", "per_column caps + total", "dynamic columns"], "requiresUserVerification": false}
```

---

## Task 5: Policy hook `kanban_move?` → `update?`

**Goal:** Add a single delegating policy predicate so a move authorizes like an update, and the board is read-only when it returns false.

**Files:**
- Modify: `lib/plutonium/resource/policy.rb`
- Test: `test/plutonium/resource/kanban_policy_test.rb`

**Acceptance Criteria:**
- [ ] `kanban_move?` returns the same as `update?` by default.
- [ ] Overriding `update?` to false makes `kanban_move?` false; a subclass can override `kanban_move?` independently.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/kanban_policy_test.rb` → PASS

**Steps:**
- [ ] **Step 1: Failing test** (two policy subclasses: one default, one overriding `update?` false; one overriding `kanban_move?` true while `update?` false).
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** near `update?` in `policy.rb`:

```ruby
# Authorizes a kanban move. Delegates to update? by default — override to
# allow board drags without granting full edit-form access.
def kanban_move? = update?
```

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/resource/policy.rb test/plutonium/resource/kanban_policy_test.rb
git commit -m "feat(kanban): kanban_move? policy predicate delegating to update?"
```

```json:metadata
{"files": ["lib/plutonium/resource/policy.rb", "test/plutonium/resource/kanban_policy_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/kanban_policy_test.rb", "acceptanceCriteria": ["kanban_move? defaults to update?", "independently overridable"], "requiresUserVerification": false}
```

---

## Task 6: `kanban_column` frame endpoint

**Goal:** A lightweight controller action rendering ONE column's cards (the frame `src`): resolve the board, build the authorized + query-applied relation (reuse the existing index query pipeline), group, and render just the requested column's body.

**Files:**
- Create: `lib/plutonium/resource/controllers/kanban_actions.rb` (start it here; extended in Tasks 7–8)
- Modify: `lib/plutonium/resource/controller.rb` (include concern)
- Test: `test/integration/admin_portal/kanban_column_test.rb`

**Acceptance Criteria:**
- [ ] `GET …?view=kanban&column=<key>` renders that column's cards (turbo-frame body), ordered by position, capped at `per_column`.
- [ ] The relation is the **authorized + query-applied** scope (search/filters/scopes honored), **not paginated**.
- [ ] Unknown `column` → 404/empty frame (no crash).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_column_test.rb` → PASS (after Task 15 fixtures exist; if running earlier, stub a board in the dummy).

> **Dependency note:** integration tests here rely on the dummy `Task` board from Task 15. If executing strictly in order, write the endpoint + a controller unit test now and add the integration assertions when Task 15 lands. Prefer reordering Task 15 earlier if convenient.

**Steps:**
- [ ] **Step 1: Failing test.**
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the concern with a `current_kanban_board` memo (compiles `current_definition.defined_kanban_block` via `Kanban::DSL.build`), a `kanban_base_relation` (reuse `current_query_object.apply(authorized_scope(resource_class.all), params)` minus pagination — see `Queryable`), and `kanban_column` rendering `Plutonium::UI::Kanban::Column` (Task 9) for the one column.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/resource/controllers/kanban_actions.rb lib/plutonium/resource/controller.rb test/integration/admin_portal/kanban_column_test.rb
git commit -m "feat(kanban): lazy per-column frame endpoint"
```

```json:metadata
{"files": ["lib/plutonium/resource/controllers/kanban_actions.rb", "lib/plutonium/resource/controller.rb", "test/integration/admin_portal/kanban_column_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_column_test.rb", "acceptanceCriteria": ["renders one column's cards", "authorized+query-applied unpaginated relation", "unknown column safe"], "requiresUserVerification": false}
```

---

## Task 7: The move action (direct, non-form)

**Goal:** Register and handle the move: authorize `kanban_move?`, enforce `accepts:`/`locked:`, apply `on_drop`, compute fractional position, enforce `wip`, save in a transaction, and respond with frame-scoped Turbo Streams re-rendering source + destination columns (snap-back on failure).

**Files:**
- Modify: `lib/plutonium/resource/controllers/kanban_actions.rb`, the resource routing (member route for the move)
- Test: `test/integration/admin_portal/kanban_move_test.rb`

**Acceptance Criteria:**
- [ ] `POST …/<id>/kanban_move` with `{from_column,to_column,to_index}` moves the card: `on_drop` applied, `position` set between neighbors at `to_index`.
- [ ] `kanban_move?` false → 403, no mutation.
- [ ] Destination `accepts:` excluding `from_column` → 422, no mutation, response re-renders the **unchanged** source frame.
- [ ] `wip` exceeded → 422, no mutation.
- [ ] Success → Turbo Stream replacing `kanban-col-<from>` and `kanban-col-<to>` frames.
- [ ] `on_drop` symbol form (`record.public_send(:sym)`) works.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_move_test.rb` → PASS

**Steps:**
- [ ] **Step 1: Failing test** covering all six criteria.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** `kanban_move`:

```ruby
def kanban_move
  board = current_kanban_board
  record = authorized_resource_scope.find(params[:id])
  authorize! record, to: :kanban_move?

  # Resolve columns via the context so dynamic (columns do…end) boards work too.
  cols = Plutonium::Kanban::Grouping.resolve_columns(board, kanban_context)
  from = cols.find { |c| c.key == params[:from_column].to_sym }
  to   = cols.find { |c| c.key == params[:to_column].to_sym }
  raise Plutonium::Kanban::DropRejected unless to.accepts?(from.key) && !from.locked?

  resource_record_transaction do
    apply_on_drop(to, record)                    # Proc -> instance_exec(record); Symbol -> record.public_send
    reposition(board, to, record, params[:to_index].to_i)
    enforce_wip!(to, record)
    record.save!
  end

  render_kanban_frames(from, to)
rescue Plutonium::Kanban::DropRejected, ActiveRecord::RecordInvalid
  render_kanban_frames(from, to, status: :unprocessable_content)  # unchanged source snaps card back
end
```

Wire the route: register `kanban_move` as a member action (extend the resource route registration the way `wizard_registration`/`mapper_extensions` add custom member routes; or add `member { post :kanban_move }` in the resource route helper). Mark it a direct action excluded from rendered toolbars.

- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/resource/controllers/kanban_actions.rb test/integration/admin_portal/kanban_move_test.rb
git commit -m "feat(kanban): move action — drop policy, on_drop, positioning, wip, frame response"
```

```json:metadata
{"files": ["lib/plutonium/resource/controllers/kanban_actions.rb", "test/integration/admin_portal/kanban_move_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_move_test.rb", "acceptanceCriteria": ["move applies on_drop+position", "kanban_move? false -> 403", "accepts/locked -> 422 unchanged", "wip -> 422", "success replaces from+to frames", "symbol on_drop"], "requiresUserVerification": false}
```

---

## Task 8: Column-scoped actions via `interactive_bulk_action`

**Goal:** Render a column's actions in its header and route them to the existing `interactive_bulk_action` with the column's card ids (resolved by `on:`).

**Files:**
- Modify: `lib/plutonium/resource/controllers/kanban_actions.rb` (id resolution helper), `lib/plutonium/ui/kanban/column.rb` (header buttons — coordinate with Task 9)
- Test: `test/integration/admin_portal/kanban_column_action_test.rb`

**Acceptance Criteria:**
- [ ] A column `action … on: :all` resolves ids = column scope ∩ current query (all, beyond `per_column`).
- [ ] `on: :visible` resolves only the rendered, capped ids.
- [ ] The action links to `…/bulk_actions/:interaction?ids[]=…` (reuses the existing bulk flow + per-record auth).
- [ ] Header renders only actions whose policy permits them.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_column_action_test.rb` → PASS

**Steps:**
- [ ] **Step 1: Failing test** asserting id resolution for `:all` vs `:visible` and the generated bulk URL.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** `column_action_ids(board, column, on:)` and the header rendering (delegating to existing bulk-action URL helpers).
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/resource/controllers/kanban_actions.rb lib/plutonium/ui/kanban/column.rb test/integration/admin_portal/kanban_column_action_test.rb
git commit -m "feat(kanban): column-scoped actions via interactive_bulk_action"
```

```json:metadata
{"files": ["lib/plutonium/resource/controllers/kanban_actions.rb", "lib/plutonium/ui/kanban/column.rb", "test/integration/admin_portal/kanban_column_action_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_column_action_test.rb", "acceptanceCriteria": ["on: :all ids beyond per_column", "on: :visible capped", "links to bulk_actions", "policy-gated header"], "requiresUserVerification": false}
```

---

## Task 9: Kanban view components (shell + column + card)

**Goal:** Phlex components: `Kanban::Resource` renders the board shell — a row of lazy `<turbo-frame id="kanban-col-<key>" loading="lazy" src=…>` per column (header + lazy body); `Kanban::Column` renders a column's body (cards via `Kanban::Card`, "+N more", wip badge, action header); `Kanban::Card` wraps the existing grid `Card` with `card_fields` slots.

**Files:**
- Create: `lib/plutonium/ui/kanban/resource.rb`, `lib/plutonium/ui/kanban/column.rb`, `lib/plutonium/ui/kanban/card.rb`
- Test: `test/plutonium/ui/kanban/resource_test.rb`, `test/plutonium/ui/kanban/column_test.rb`

**Acceptance Criteria:**
- [ ] `Resource` renders N lazy turbo-frames with correct `id`/`src`, column headers, and the board's drag controller data attributes.
- [ ] `Column` renders cards ordered as grouped, a "+N more" when `total > per_column`, and a wip badge `count/limit` when `wip` set.
- [ ] `Card` reuses `Plutonium::UI::Grid::Components::Card` with `card_fields` (falls back to `grid_fields`).
- [ ] Collapsed columns render the count-strip variant.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/kanban/resource_test.rb test/plutonium/ui/kanban/column_test.rb` → PASS

**Steps:**
- [ ] **Step 1: Failing tests** rendering the components against a built `Board` + grouped data (Phlex `.call`), asserting frame ids/src, "+N more", wip badge, collapsed variant. Mirror existing Phlex component tests under `test/plutonium/ui/`.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the three components, mirroring `lib/plutonium/ui/grid/resource.rb` / `grid/components/card.rb` structure and `.pu-*`/token classes. Use `turbo_scoped_dom_id` for frame ids.
- [ ] **Step 4:** `yarn build` not needed (no JS yet). Run → PASS.
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/ui/kanban/ test/plutonium/ui/kanban/
git commit -m "feat(kanban): Phlex board shell, column, and card components"
```

```json:metadata
{"files": ["lib/plutonium/ui/kanban/resource.rb", "lib/plutonium/ui/kanban/column.rb", "lib/plutonium/ui/kanban/card.rb", "test/plutonium/ui/kanban/resource_test.rb", "test/plutonium/ui/kanban/column_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/kanban/resource_test.rb", "acceptanceCriteria": ["lazy frames with id/src", "+N more", "wip badge", "card reuses grid card", "collapsed variant"], "requiresUserVerification": false}
```

---

## Task 10: Wire into the index page + view switcher

**Goal:** Render the board when `selected_view == :kanban`, and add a `kanban` segment to the view switcher.

**Files:**
- Modify: `lib/plutonium/ui/page/index.rb`, `lib/plutonium/ui/table/components/view_switcher.rb`
- Test: `test/integration/admin_portal/kanban_index_view_test.rb`

**Acceptance Criteria:**
- [ ] `?view=kanban` renders the board shell (lazy frames), not the table.
- [ ] The switcher shows a `Kanban` segment (icon + label) when `:kanban` is enabled; clicking sets the cookie and reloads.
- [ ] Cookie stickiness works (existing mechanism).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_index_view_test.rb` → PASS

**Steps:**
- [ ] **Step 1: Failing test.**
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement.** In `index.rb#render_default_content`: `when :kanban then render partial("resource_kanban")` (and add the `resource_kanban` partial method building `Plutonium::UI::Kanban::Resource`). In `view_switcher.rb` add to `SEGMENT_LABELS`: `kanban: {label: "Board", icon: Phlex::TablerIcons::LayoutKanban}`.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/ui/page/index.rb lib/plutonium/ui/table/components/view_switcher.rb test/integration/admin_portal/kanban_index_view_test.rb
git commit -m "feat(kanban): render board on index + view-switcher segment"
```

```json:metadata
{"files": ["lib/plutonium/ui/page/index.rb", "lib/plutonium/ui/table/components/view_switcher.rb", "test/integration/admin_portal/kanban_index_view_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_index_view_test.rb", "acceptanceCriteria": ["?view=kanban renders board", "switcher segment", "cookie sticky"], "requiresUserVerification": false}
```

---

## Task 11: Stimulus `kanban_controller.js` — drag + move + reconcile

**Goal:** A Stimulus controller wiring cross-frame drag (SortableJS-style), posting the move on drop, and letting the frame-scoped response reconcile (failure re-renders unchanged source = snap-back). Registered + built.

**Files:**
- Create: `src/js/controllers/kanban_controller.js`
- Modify: `src/js/controllers/register_controllers.js`
- Test: `test/system/kanban_test.rb` (system/browser test) — or an integration assertion that the controller + data attributes are present if system tests are heavy.

**Acceptance Criteria:**
- [ ] Dragging a card to another column POSTs `{from_column,to_column,to_index}` to the move route.
- [ ] On success the target/source frames update; on a 4xx the card returns to origin (driven by the response, not client bookkeeping).
- [ ] Controller registered in `register_controllers.js`; `yarn build` produces updated `app/assets/plutonium.js`.

**Verify:** `yarn build` then `bundle exec appraisal rails-8.1 ruby -Itest test/system/kanban_test.rb` → PASS (system tests require the JS bundle built).

**Steps:**
- [ ] **Step 1: Failing system test** (drag a card, assert it lands in the new column and persists across reload). Mirror existing `test/system/` setup.
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** the controller (use the project's existing drag dependency if present; otherwise add a lightweight HTML5 drag handler — check `package.json` before adding deps). Register it. `yarn build`.
- [ ] **Step 4: Run → PASS.**
- [ ] **Step 5: Commit**

```bash
git add src/js/controllers/kanban_controller.js src/js/controllers/register_controllers.js app/assets/ test/system/kanban_test.rb
git commit -m "feat(kanban): drag-to-move Stimulus controller + build"
```

```json:metadata
{"files": ["src/js/controllers/kanban_controller.js", "src/js/controllers/register_controllers.js", "test/system/kanban_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/system/kanban_test.rb", "acceptanceCriteria": ["drag posts move", "response reconciles + snap-back", "registered + built"], "requiresUserVerification": false}
```

---

## Task 12: Quick-add (`add: true`)

**Goal:** Render an inline "+ Add" on columns with `add: true` that creates a record seeded into the column (apply the column's `on_drop` to a new instance), via the resource's create path; authorized with `create?`.

**Files:**
- Modify: `lib/plutonium/ui/kanban/column.rb`, `lib/plutonium/resource/controllers/kanban_actions.rb`
- Test: `test/integration/admin_portal/kanban_quick_add_test.rb`

**Acceptance Criteria:**
- [ ] Columns with `add: true` render a "+ Add"; others don't.
- [ ] Submitting creates a record with the column's `on_drop` applied (e.g. `status: :todo`) and a position at the column end.
- [ ] `create?` false → no "+ Add", endpoint 403.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_quick_add_test.rb` → PASS

**Steps:** TDD as above. Reuse the resource new/create form (`turbo_frame` modal) seeded with the column placement, or a minimal inline create. Commit:

```bash
git commit -m "feat(kanban): per-column quick-add seeded via on_drop"
```

```json:metadata
{"files": ["lib/plutonium/ui/kanban/column.rb", "lib/plutonium/resource/controllers/kanban_actions.rb", "test/integration/admin_portal/kanban_quick_add_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_quick_add_test.rb", "acceptanceCriteria": ["add:true renders +Add", "create seeds on_drop + end position", "create? false gates"], "requiresUserVerification": false}
```

---

## Task 13: Column behaviour UI — collapse, drop policy, wip badge

**Goal:** Finish the column behaviours in the UI/controller: collapsible toggle (initial `collapsed:`), `accepts:`/`locked:` reflected as drag constraints (client) AND enforced server-side (already in Task 7), and the wip badge/over-limit styling.

**Files:**
- Modify: `lib/plutonium/ui/kanban/column.rb`, `src/js/controllers/kanban_controller.js`
- Test: `test/plutonium/ui/kanban/behaviours_test.rb` + a system assertion for collapse

**Acceptance Criteria:**
- [ ] `collapsed: true` renders folded; a toggle expands (persists per-column via cookie/localStorage — pick one, document it).
- [ ] `accepts:`/`locked:` set data attributes the controller uses to block disallowed drops client-side (server still enforces).
- [ ] `wip` badge shows `count/limit`; over-limit gets a warning class.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/kanban/behaviours_test.rb` → PASS

**Steps:** TDD. `yarn build` after JS edits. Commit:

```bash
git commit -m "feat(kanban): column collapse, drop-policy constraints, wip badge"
```

```json:metadata
{"files": ["lib/plutonium/ui/kanban/column.rb", "src/js/controllers/kanban_controller.js", "test/plutonium/ui/kanban/behaviours_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/kanban/behaviours_test.rb", "acceptanceCriteria": ["collapse toggle", "accepts/locked client constraints", "wip badge + over-limit"], "requiresUserVerification": false}
```

---

## Task 14: Opt-in real-time broadcaster

**Goal:** When `realtime true`, mirror a successful move's frame updates to other viewers via Turbo Streams, scoped to tenant + board. Off by default; no effect on the mover's own rollback.

**Files:**
- Create: `lib/plutonium/kanban/broadcaster.rb`
- Modify: `lib/plutonium/resource/controllers/kanban_actions.rb` (broadcast after a successful move), `lib/plutonium/ui/kanban/resource.rb` (subscribe via `turbo_stream_from` when realtime)
- Test: `test/plutonium/kanban/broadcaster_test.rb`

**Acceptance Criteria:**
- [ ] Stream name includes `current_scoped_entity` + resource class (no cross-tenant leakage).
- [ ] Broadcast fires only when `board.realtime?`.
- [ ] The board subscribes (`turbo_stream_from`) only when realtime.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/broadcaster_test.rb` → PASS

**Steps:** TDD; assert broadcast presence/absence and stream-name scoping (use Turbo test helpers / capture). Commit:

```bash
git commit -m "feat(kanban): opt-in tenant-scoped realtime move broadcasting"
```

```json:metadata
{"files": ["lib/plutonium/kanban/broadcaster.rb", "lib/plutonium/resource/controllers/kanban_actions.rb", "lib/plutonium/ui/kanban/resource.rb", "test/plutonium/kanban/broadcaster_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/broadcaster_test.rb", "acceptanceCriteria": ["tenant+board scoped stream", "fires only when realtime", "subscribes only when realtime"], "requiresUserVerification": false}
```

---

## Task 15: Dummy-app fixtures + end-to-end board

**Goal:** A real board in the dummy app to drive integration/system tests: a `Task`-style resource with `status` + decimal `position`, a definition with a `kanban do…end` (static columns, a wip, a backlog role, a done role + column action), connected to a portal. **Use Plutonium generators** (`pu:res:scaffold`, `pu:res:conn`) — do not hand-write app files.

**Files:**
- Generated under `test/dummy/` (model, migration, definition, policy, controller, routes); then edit the definition to add `kanban do…end`
- Test: a small `test/integration/admin_portal/kanban_smoke_test.rb`

**Acceptance Criteria:**
- [ ] `rails g pu:res:scaffold Task title:string status:string position:decimal --dest=…` runs; migration applied; `position` is decimal.
- [ ] Definition has a working `kanban` board (static columns + one column action backed by a dummy interaction).
- [ ] Smoke test: board renders, a move persists, a column action runs.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_smoke_test.rb` → PASS

**Steps:**
- [ ] **Step 1:** Generate the resource + connect to the admin portal (quote types; pass `--dest=`, `--force` as needed). Edit the migration to confirm `position` is `decimal` and add `Plutonium::Positioning` (`positioned_on :position, scope: :status`) to the model. `rails db:prepare`.
- [ ] **Step 2:** Add the `kanban do…end` block to `TaskDefinition` (mirror the spec's §3 example, scaled down). Add a trivial `ArchiveTasks` interaction for the column action.
- [ ] **Step 3:** Write + run the smoke test → PASS.
- [ ] **Step 4: Commit**

```bash
git add test/dummy/ test/integration/admin_portal/kanban_smoke_test.rb
git commit -m "test(kanban): dummy Task board fixture + smoke test"
```

> **Reorder note:** Tasks 6–13 integration tests depend on this fixture. If using subagent-driven execution, consider running Task 15 right after Task 5 (before the controller/UI tasks). Listed last only to keep the core/lib tasks contiguous.

```json:metadata
{"files": ["test/dummy/app/models/task.rb", "test/dummy/app/definitions/task_definition.rb", "test/integration/admin_portal/kanban_smoke_test.rb"], "verifyCommand": "bundle exec appraisal rails-8.1 ruby -Itest test/integration/admin_portal/kanban_smoke_test.rb", "acceptanceCriteria": ["scaffolded Task w/ decimal position", "kanban board in definition", "smoke: render+move+action"], "requiresUserVerification": false}
```

---

## Task 16: Documentation (guide + reference)

**Goal:** A `docs/guides/kanban.md` guide and `docs/reference/kanban/*` reference mirroring the wizard docs, plus nav wiring in `docs/.vitepress/config.ts` and `docs/guides/index.md`/`docs/reference/index.md`.

**Files:**
- Create: `docs/guides/kanban.md`, `docs/reference/kanban/index.md`, `docs/reference/kanban/dsl.md`, `docs/reference/kanban/positioning.md`, `docs/reference/kanban/authorization.md`
- Modify: `docs/.vitepress/config.ts`, `docs/guides/index.md`, `docs/reference/index.md`

**Acceptance Criteria:**
- [ ] Guide covers: enabling the board, static vs dynamic columns, positioning modes, behaviours/archetypes, column actions, authorization, realtime.
- [ ] `yarn docs:build` succeeds (no broken links).

**Verify:** `yarn docs:build` → exits 0

**Steps:** Write docs from the spec (DSL examples are already validated). Run `yarn docs:build`. Commit:

```bash
git commit -m "docs(kanban): guide + reference"
```

```json:metadata
{"files": ["docs/guides/kanban.md", "docs/reference/kanban/index.md", "docs/reference/kanban/dsl.md", "docs/.vitepress/config.ts"], "verifyCommand": "yarn docs:build", "acceptanceCriteria": ["guide covers all features", "docs build clean"], "requiresUserVerification": false}
```

---

## Task 17: `plutonium-kanban` skill + router entry

**Goal:** A `.claude/skills/plutonium-kanban/SKILL.md` (mirroring `plutonium-wizard`) and a router entry + table row in `.claude/skills/plutonium/SKILL.md`.

**Files:**
- Create: `.claude/skills/plutonium-kanban/SKILL.md`
- Modify: `.claude/skills/plutonium/SKILL.md`
- Test: none (docs); verify by review.

**Acceptance Criteria:**
- [ ] Skill describes when to use it, the DSL surface, and links to docs/spec.
- [ ] Router table in `plutonium/SKILL.md` has a "build a kanban board" → `plutonium-kanban` row.

**Verify:** Manual review; `git grep -n "plutonium-kanban" .claude/skills/plutonium/SKILL.md` shows the entry.

**Steps:** Write the skill mirroring the wizard skill's structure. Commit:

```bash
git commit -m "docs(kanban): plutonium-kanban skill + router entry"
```

```json:metadata
{"files": [".claude/skills/plutonium-kanban/SKILL.md", ".claude/skills/plutonium/SKILL.md"], "verifyCommand": "git grep -n plutonium-kanban .claude/skills/plutonium/SKILL.md", "acceptanceCriteria": ["skill written", "router entry added"], "requiresUserVerification": false}
```

---

## Final verification (after all tasks)

- [ ] `bundle exec appraisal rails-8.1 rake test` → all green
- [ ] `bundle exec appraisal rails-7 rake test` and `rails-8.0` → green (version parity)
- [ ] `yarn build` clean; `yarn docs:build` clean
- [ ] Manually drive the dummy board (see `memory/reference_driving_dummy_app_browser.md`): load `?view=kanban`, drag a card, run a column action, quick-add, toggle collapse.
- [ ] Re-read the spec §2 decisions; confirm each has a landing task.
