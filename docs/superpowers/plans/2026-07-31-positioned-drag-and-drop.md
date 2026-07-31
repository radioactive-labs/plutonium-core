# Positioned Drag-and-Drop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give any Plutonium resource whose model is positioned native drag-to-reorder on its index table, nested association tables, and grid/card views — reusing kanban's positioning strategy machine and drag mechanics rather than duplicating them.

**Architecture:** `Plutonium::Kanban::Positioning::Config` is promoted to `Plutonium::Positioning::Config` so kanban's `position_on` and a new definition-level `position_on` DSL build the same three-mode strategy (delegate / block / disabled). A new `hidden: true` action flag generalises the existing one-off `kanban_drop?`, giving the reposition endpoint a route and policy predicate without rendering a button. Drag mechanics are extracted from `kanban_controller.js` into a shared `src/js/drag/sortable.js` consumed by both kanban and a new `positioned_controller.js`.

**Tech Stack:** Ruby/Rails (Rails 7, 8.0, 8.1 via Appraisal), Minitest, Phlex components, Stimulus, native HTML5 drag-and-drop, Turbo Streams, TailwindCSS 4.

**User Verification:** NO — no user verification required. The spec asks for a framework feature; verification is by automated test plus a system test driving a real drag.

**Spec:** `docs/superpowers/specs/2026-07-31-positioned-drag-and-drop-design.md`

---

## File Structure

**Created**

| File | Responsibility |
|---|---|
| `lib/plutonium/positioning/config.rb` | The three-mode strategy machine + `Move` value object. Framework-wide. |
| `lib/plutonium/definition/positioning.rb` | The `position_on` definition DSL and its expansion. |
| `lib/plutonium/resource/controllers/position_actions.rb` | The `reposition` endpoint. |
| `lib/plutonium/ui/table/components/drag_handle.rb` | The grip Phlex component (table + grid). |
| `src/js/drag/sortable.js` | Shared native-DnD mechanics, no framework knowledge. |
| `src/js/controllers/positioned_controller.js` | Stimulus controller for tables/grids. |
| `test/plutonium/positioning/config_test.rb` | Config modes. |
| `test/plutonium/definition/positioning_test.rb` | `position_on` DSL expansion. |
| `test/plutonium/action/hidden_action_test.rb` | Hidden-action render exclusion. |
| `test/plutonium/resource/controllers/position_actions_test.rb` | Endpoint behaviour. |
| `test/system/positioned_drag_test.rb` | Real drag + keyboard reorder. |

**Modified**

| File | Change |
|---|---|
| `lib/plutonium/positioning.rb` | `reposition!` returns a result carrying `rebalanced?`; requires the new config file. |
| `lib/plutonium/kanban/positioning.rb` | Becomes a thin alias to the promoted constants. |
| `lib/plutonium/action/base.rb:26,84,145` | `kanban_drop` → `hidden`. |
| `lib/plutonium/definition/index_views.rb:148` | Passes `hidden: true`. |
| `lib/plutonium/definition/base.rb:28-40` | `include Positioning`. |
| `lib/plutonium/ui/page/index.rb:36`, `page/show.rb:18`, `table/resource.rb:163`, `grid/card.rb:303` | `kanban_drop?` → `hidden?`. |
| `lib/plutonium/ui/table/resource.rb:189`, `grid/resource.rb:95` | Add the missing `!a.hidden?` filter. |
| `lib/plutonium/ui/table/resource.rb:~152` | Wrap the first column's block to emit the grip. |
| `lib/plutonium/resource/policy.rb` | Add `reposition?`. |
| `lib/plutonium/routing/mapper_extensions.rb:~155` | Add the `reposition` member route. |
| `src/js/controllers/kanban_controller.js` | Consumes `sortable.js`. |
| `src/js/controllers/register_controllers.js` | Register `positioned`. |

---

## Task Ordering Rationale

Tasks 1–2 (Config promotion, rebalance signal) are pure refactors of existing tested code and land first so everything downstream builds on the final shapes. Task 3 (hidden actions) is independent and could run in parallel. Tasks 4–6 build the server feature. Tasks 7–10 build the client. Task 11 verifies end-to-end.

**Kanban is touched in Tasks 1, 4, and 6.** All three are behaviour-preserving, and kanban's existing suite is the gate for each:

| Task | Kanban change | Risk |
|---|---|---|
| 1 | `Positioning::Config` moves namespace, aliased back | Low — pure namespace move |
| 4 | `position_config` resolution becomes lazy via `position_config_for` | Low — mechanical, 5 call sites |
| 6 | Drag mechanics extracted to a shared module | **Highest** — touches drag behaviour itself |

Task 6 is the one to abandon first if it proves invasive; Tasks 1–5 stand without it (see spec Risks).

---

### Task 1: Promote `Positioning::Config` out of the kanban namespace

**Goal:** One strategy machine, in `Plutonium::Positioning`, with kanban's public surface unchanged.

**Files:**
- Create: `lib/plutonium/positioning/config.rb`
- Modify: `lib/plutonium/kanban/positioning.rb` (becomes an alias)
- Modify: `lib/plutonium/positioning.rb` (require the new file)
- Test: `test/plutonium/positioning/config_test.rb` (new)
- Test: `test/plutonium/kanban/positioning_test.rb` (must pass unchanged)

**Acceptance Criteria:**
- [ ] `Plutonium::Positioning::Config` and `Plutonium::Positioning::Move` exist with the three modes
- [ ] `Plutonium::Kanban::Positioning::Config` still resolves, to the same object
- [ ] `Move` accepts `column:` and defaults it to `nil`
- [ ] `test/plutonium/kanban/positioning_test.rb` passes **unmodified**

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/positioning_test.rb` → all pass, 0 failures

**Steps:**

- [ ] **Step 1: Write the failing test for the promoted constants**

Create `test/plutonium/positioning/config_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Positioning
    class ConfigTest < Minitest::Test
      def test_kanban_namespace_still_resolves_to_the_promoted_class
        assert_same Plutonium::Positioning::Config, Plutonium::Kanban::Positioning::Config
        assert_same Plutonium::Positioning::Move, Plutonium::Kanban::Positioning::Move
      end

      def test_move_column_defaults_to_nil_off_board
        move = Plutonium::Positioning::Move.new(
          record: :rec, prev: nil, next: nil, index: 0
        )
        assert_nil move.column
      end

      def test_disabled_mode_leaves_the_relation_untouched
        relation = Object.new
        config = Plutonium::Positioning::Config.disabled
        assert config.disabled?
        assert_same relation, config.order(relation)
      end
    end
  end
end
```

- [ ] **Step 2: Run it and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning/config_test.rb`
Expected: FAIL — `NameError: uninitialized constant Plutonium::Positioning::Config`

- [ ] **Step 3: Move the code**

Create `lib/plutonium/positioning/config.rb` containing the `Config` class and `Move` currently in `lib/plutonium/kanban/positioning.rb`, namespaced under `Plutonium::Positioning`. Two changes from the original:

```ruby
# frozen_string_literal: true

module Plutonium
  module Positioning
    # Value object passed to Mode B blocks, carrying the full drop context.
    # `column` is the kanban column key on a board, and nil on every other
    # surface (index tables, nested tables, grids) — those have no columns.
    Move = Data.define(:record, :column, :prev, :next, :index) do
      def initialize(record:, prev:, next:, index:, column: nil)
        super
      end
    end

    # ... Config class verbatim from lib/plutonium/kanban/positioning.rb,
    # including .default / .attribute / .with_block / .disabled,
    # #disabled? / #order / #reposition!
  end
end
```

Keep every comment from the original — they document the three modes and are the reason this class is comprehensible.

- [ ] **Step 4: Turn the kanban file into an alias**

Replace the body of `lib/plutonium/kanban/positioning.rb`:

```ruby
# frozen_string_literal: true

require "plutonium/positioning"

module Plutonium
  module Kanban
    # Kanban's positioning strategy is the framework-wide one — see
    # Plutonium::Positioning::Config. This alias preserves the original
    # namespace so `position_on` and every existing reference keep working.
    module Positioning
      Config = Plutonium::Positioning::Config
      Move = Plutonium::Positioning::Move
    end
  end
end
```

- [ ] **Step 5: Require the config from the positioning concern**

At the top of `lib/plutonium/positioning.rb`, after the `frozen_string_literal` comment:

```ruby
require "plutonium/positioning/config"
```

- [ ] **Step 6: Run both suites**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning/config_test.rb`
Expected: PASS

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/positioning_test.rb`
Expected: PASS, **with the file unmodified** — this is what proves the move is behaviour-preserving.

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/dsl_test.rb`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add lib/plutonium/positioning/config.rb lib/plutonium/positioning.rb \
        lib/plutonium/kanban/positioning.rb test/plutonium/positioning/config_test.rb
git commit -m "refactor(positioning): promote Config out of the kanban namespace"
```

---

### Task 2: `reposition!` reports whether it rebalanced

**Goal:** The controller can tell a clean drop from one that renumbered the group, without re-deriving it.

**Files:**
- Modify: `lib/plutonium/positioning.rb:84-94` (`reposition!`)
- Modify: `lib/plutonium/positioning/config.rb` (`#reposition!` return value)
- Test: `test/plutonium/positioning_test.rb`
- Test: `test/plutonium/positioning/config_test.rb`

**Acceptance Criteria:**
- [ ] `reposition!` returns an object responding to `rebalanced?`
- [ ] `rebalanced?` is `true` only when the gap was exhausted and the group was renumbered
- [ ] `Config#reposition!` returns `rebalanced?` in Mode A, `true` in Mode B, `false` in Mode C
- [ ] Existing positioning tests still pass

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning_test.rb` → all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

Append to `test/plutonium/positioning_test.rb`, inside the existing class (it already builds `@item_class` on `positioning_test_items` with `positioned_on :position, scope: :status`):

```ruby
def test_reposition_reports_no_rebalance_on_a_normal_move
  a = @item_class.create!(status: "todo")
  b = @item_class.create!(status: "todo")
  c = @item_class.create!(status: "todo")

  result = c.reposition!(prev_record: a, next_record: b)

  refute result.rebalanced?
end

def test_reposition_reports_a_rebalance_when_the_gap_is_exhausted
  a = @item_class.create!(status: "todo")
  b = @item_class.create!(status: "todo")
  c = @item_class.create!(status: "todo")

  # Collapse the gap below EPSILON (1e-6) so the midpoint would collide.
  a.update_column(:position, 1.0)
  b.update_column(:position, 1.0 + 1e-9)

  result = c.reposition!(prev_record: a.reload, next_record: b.reload)

  assert result.rebalanced?
end
```

And in `test/plutonium/positioning/config_test.rb`:

```ruby
def test_block_mode_always_reports_rebalanced
  # A Mode B block is an opaque write — the framework cannot know what it did,
  # so it always forces reconciliation. See spec §3.1.
  config = Plutonium::Positioning::Config.with_block(:position, ->(_move) { :ignored })
  result = config.reposition!(
    record: Object.new, column: nil, prev_record: nil, next_record: nil, index: 0
  )
  assert result
end

def test_disabled_mode_never_reports_rebalanced
  config = Plutonium::Positioning::Config.disabled
  result = config.reposition!(
    record: Object.new, column: nil, prev_record: nil, next_record: nil, index: 0
  )
  refute result
end
```

- [ ] **Step 2: Run and watch them fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning_test.rb -n /rebalance/`
Expected: FAIL — `NoMethodError: undefined method 'rebalanced?'`

- [ ] **Step 3: Return a result from `reposition!`**

In `lib/plutonium/positioning.rb`, add the result type inside `module Positioning`:

```ruby
    # Outcome of a #reposition! call. `rebalanced?` is true when the gap
    # between the neighbours was exhausted and the whole scope group had to
    # be renumbered — the caller needs to know because every other row's
    # position changed, so any cached client-side view of the list is stale.
    Result = Data.define(:rebalanced) do
      def rebalanced? = rebalanced
    end
```

Then rewrite `reposition!` (currently lines 84-94) to track and return it:

```ruby
    def reposition!(prev_record:, next_record:)
      col = self.class.positioning_column
      prev_val = prev_record&.public_send(col)
      next_val = next_record&.public_send(col)
      rebalanced = false
      if Plutonium::Positioning.gap_exhausted?(prev_val, next_val)
        rebalance_scope_group!
        rebalanced = true
        prev_val = prev_record&.reload&.public_send(col)
        next_val = next_record&.reload&.public_send(col)
      end
      update!(col => Plutonium::Positioning.position_between(prev_val, next_val))
      Result.new(rebalanced:)
    end
```

- [ ] **Step 4: Surface it from `Config#reposition!`**

In `lib/plutonium/positioning/config.rb`, change `#reposition!` to return a boolean meaning "the caller must reconcile":

```ruby
        # Persist the new position for a dropped record. Returns true when the
        # caller must reconcile its view of the list because positions other
        # than this record's may have changed.
        #
        # Mode A: whether reposition! had to rebalance the scope group.
        # Mode B: always true — the block is an opaque write and gems in this
        #         space routinely renumber the whole group (acts_as_list does).
        # Mode C: always false — nothing was written.
        def reposition!(record:, column:, prev_record:, next_record:, index:)
          case @mode
          when :delegate
            record.reposition!(prev_record:, next_record:).rebalanced?
          when :block
            @block.call(Move.new(record:, column:, prev: prev_record, next: next_record, index:))
            true
          when :disabled
            false
          end
        end
```

- [ ] **Step 5: Run the tests**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning_test.rb`
Expected: PASS

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning/config_test.rb`
Expected: PASS

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/positioning_test.rb`
Expected: PASS — kanban ignores the return value, so this must be unaffected.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/positioning.rb lib/plutonium/positioning/config.rb \
        test/plutonium/positioning_test.rb test/plutonium/positioning/config_test.rb
git commit -m "feat(positioning): report whether reposition! rebalanced the group"
```

---

### Task 3: Hidden actions

**Goal:** `hidden: true` is a general action flag; `kanban_drop` disappears; both bulk-action selectors stop leaking hidden actions.

**Files:**
- Modify: `lib/plutonium/action/base.rb:26,84,145`
- Modify: `lib/plutonium/definition/index_views.rb:148`
- Modify: `lib/plutonium/ui/page/index.rb:36`, `lib/plutonium/ui/page/show.rb:18`
- Modify: `lib/plutonium/ui/table/resource.rb:163` and `:189`
- Modify: `lib/plutonium/ui/grid/card.rb:303`, `lib/plutonium/ui/grid/resource.rb:95`
- Modify: `lib/plutonium/kanban/column.rb:32-40` (comment only)
- Test: `test/plutonium/action/hidden_action_test.rb` (new)

**Acceptance Criteria:**
- [ ] `Action::Base#hidden?` exists; `#kanban_drop?` is gone
- [ ] `hidden` round-trips through `#with` (it is in `to_options`)
- [ ] All six render-site selectors filter `!a.hidden?`
- [ ] Both bulk-action selectors filter it — the gap this closes
- [ ] Kanban's suite passes

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/action/hidden_action_test.rb` → all pass

**Steps:**

- [ ] **Step 1: Write the failing test**

Create `test/plutonium/action/hidden_action_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Action
    class HiddenActionTest < Minitest::Test
      def test_actions_are_visible_by_default
        refute Plutonium::Action::Simple.new(:archive).hidden?
      end

      def test_hidden_flag_is_readable
        assert Plutonium::Action::Simple.new(:reposition, hidden: true).hidden?
      end

      # `with` reconstructs an action from to_options — anything missing there
      # is silently dropped on round-trip, which would un-hide the action.
      def test_hidden_survives_a_with_round_trip
        action = Plutonium::Action::Simple.new(:reposition, hidden: true)
        assert action.with(label: "Move").hidden?
      end

      def test_hidden_can_be_turned_off_via_with
        action = Plutonium::Action::Simple.new(:reposition, hidden: true)
        refute action.with(hidden: false).hidden?
      end
    end
  end
end
```

- [ ] **Step 2: Run and watch it fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/action/hidden_action_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'hidden?'`

- [ ] **Step 3: Rename the flag in `Action::Base`**

`lib/plutonium/action/base.rb` — line 26:

```ruby
        @hidden = options[:hidden] || false
```

Line 84, replacing `kanban_drop?` and its comment:

```ruby
      # True when this action must never render. It still has a live route,
      # policy predicate, and (if interactive) form + params machinery — it is
      # simply reachable only by something other than a button: a kanban drop,
      # a drag-reorder, a custom Stimulus controller.
      #
      # Display-only, like #condition_met? — NOT an authorization boundary.
      # Keep authorization in the policy.
      def hidden? = @hidden
```

Line 145, in `to_options`:

```ruby
          hidden: @hidden,
```

- [ ] **Step 4: Update the producer**

`lib/plutonium/definition/index_views.rb:148` — change `kanban_drop: true` to `hidden: true`, and update the comment on lines 138-139 from "It is flagged `kanban_drop: true`" to "It is flagged `hidden: true`".

- [ ] **Step 5: Update the four existing filter sites**

Replace `!a.kanban_drop?` with `!a.hidden?` in:
- `lib/plutonium/ui/page/index.rb:36`
- `lib/plutonium/ui/page/show.rb:18`
- `lib/plutonium/ui/table/resource.rb:163`
- `lib/plutonium/ui/grid/card.rb:303`

- [ ] **Step 6: Close the two bulk-action gaps**

`lib/plutonium/ui/grid/resource.rb:95`:

```ruby
            .select { |k, a| a.bulk_action? && !a.hidden? }
```

`lib/plutonium/ui/table/resource.rb:189`:

```ruby
            .select { |k, a| a.bulk_action? && !a.hidden? && a.condition_met?(view_context) }
```

- [ ] **Step 7: Downgrade the kanban guard comment**

In `lib/plutonium/kanban/column.rb`, the comment ending "...or (b) get auto-classified by Action::Interactive::Factory as a bulk action and leak into the bulk-actions bar (which does not filter kanban_drop actions)" is now stale — the bulk bar does filter. Replace that final clause with:

```ruby
        # by Action::Interactive::Factory as a bulk action. The bulk bars now
        # filter hidden actions, so this is defence in depth rather than the
        # only guard — but a mis-shaped interaction would still fail confusingly
        # at drop time, so reject it here where the error can name the cause.
```

- [ ] **Step 8: Verify no references remain**

Run: `rg -n "kanban_drop\b" lib app test`
Expected: **no output.** Any hit is a missed site — fix before continuing. (Note `kanban_drop_interaction` / `kanban_drop_immediate` / `kanban_drop_confirm` in `lib/plutonium/ui/kanban/column.rb` are unrelated *data attribute* names, not this flag — the `\b` in the pattern excludes them.)

- [ ] **Step 9: Run the tests**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/action/hidden_action_test.rb`
Expected: PASS

Run: `bundle exec appraisal rails-8.1 rake test`
Expected: PASS — the full suite, because this task touched six render paths.

- [ ] **Step 10: Commit**

```bash
git add lib/plutonium/action/base.rb lib/plutonium/definition/index_views.rb \
        lib/plutonium/ui/page/index.rb lib/plutonium/ui/page/show.rb \
        lib/plutonium/ui/table/resource.rb lib/plutonium/ui/grid/card.rb \
        lib/plutonium/ui/grid/resource.rb lib/plutonium/kanban/column.rb \
        test/plutonium/action/hidden_action_test.rb
git commit -m "feat(actions): generalise kanban_drop into a hidden action flag"
```

---

### Task 4: The `position_on` definition DSL

**Goal:** `position_on` in a definition declares the resource drag-orderable and expands to sort + default_sort + a hidden reposition action.

**Files:**
- Create: `lib/plutonium/definition/positioning.rb`
- Modify: `lib/plutonium/definition/base.rb:28-40` (add `include Positioning`)
- Modify: `lib/plutonium/kanban/dsl.rb:18` (stop seeding a default)
- Modify: `lib/plutonium/kanban/board.rb:~37` (add `position_config_for`)
- Modify: `lib/plutonium/resource/controllers/kanban_actions.rb:136,259,581,733,784`
- Test: `test/plutonium/definition/positioning_test.rb` (new)

**Acceptance Criteria:**
- [ ] A kanban board inherits the definition's `position_on`; its own block overrides
- [ ] A board on a definition with no `position_on` still gets `Config.default`
- [ ] Resolution is lazy — declaration order in the class body does not matter
- [ ] `position_on` / `position_on :attr` / `position_on(:attr) { |move| }` / `position_on false` build the right Config
- [ ] Mode A raises at class-load time if the model lacks `Plutonium::Positioning`
- [ ] Mode B does **not** require the concern
- [ ] Modes A and B register `sort <attr>`, `default_sort <attr>, :asc`, and a hidden `:reposition` action
- [ ] Mode C registers none of them
- [ ] `defined_position_config` is readable from an instance

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/positioning_test.rb` → all pass

**Steps:**

- [ ] **Step 1: Write the failing tests**

Create `test/plutonium/definition/positioning_test.rb`. `Task` in the dummy app is already `positioned_on :position, scope: :status`, so it is the Mode A subject; `Comment` is not positioned, so it is the negative case.

```ruby
# frozen_string_literal: true

require "test_helper"

module Plutonium
  module Definition
    class PositioningTest < Minitest::Test
      def build_definition(model, &block)
        Class.new(Plutonium::Resource::Definition) do
          define_singleton_method(:model_class) { model }
          class_eval(&block) if block
        end
      end

      def test_bare_positioned_defaults_to_the_position_attribute
        definition = build_definition(::Task) { position_on }
        config = definition.new.defined_position_config

        assert_equal :position, config.attribute
        refute config.disabled?
      end

      def test_custom_attribute
        definition = build_definition(::Task) { position_on :sort_order }
        assert_equal :sort_order, definition.new.defined_position_config.attribute
      end

      def test_positioned_sets_the_default_sort_and_registers_the_sort
        definition = build_definition(::Task) { position_on }

        assert_equal [:position, :asc], definition._default_sort
        assert_includes definition.defined_sorts.keys, :position
      end

      def test_positioned_registers_a_hidden_reposition_action
        definition = build_definition(::Task) { position_on }
        action = definition.defined_actions[:reposition]

        refute_nil action
        assert action.hidden?
      end

      # Mode A delegates to record.reposition!, which only exists on models that
      # include the concern. Failing at class-load time beats a 500 on first drag.
      def test_mode_a_requires_the_model_to_include_the_concern
        error = assert_raises(ArgumentError) do
          build_definition(::Comment) { position_on }
        end
        assert_match(/Plutonium::Positioning/, error.message)
      end

      # Mode B never calls reposition!, so the concern is irrelevant.
      def test_mode_b_does_not_require_the_concern
        definition = build_definition(::Comment) do
          position_on(:rank) { |move| move.record.insert_at(move.index + 1) }
        end
        assert_equal :rank, definition.new.defined_position_config.attribute
      end

      def test_mode_c_registers_nothing
        definition = build_definition(::Task) { position_on false }

        assert definition.new.defined_position_config.disabled?
        assert_nil definition.defined_actions[:reposition]
        refute_equal [:position, :asc], definition._default_sort
      end

      def test_default_sort_can_be_overridden_after_positioned
        definition = build_definition(::Task) do
          position_on
          default_sort :name, :asc
        end
        assert_equal [:name, :asc], definition._default_sort
      end
    end
  end
end
```

- [ ] **Step 2: Run and watch them fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/positioning_test.rb`
Expected: FAIL — `NoMethodError: undefined method `position_on``

- [ ] **Step 3: Write the concern**

Create `lib/plutonium/definition/positioning.rb`:

```ruby
# frozen_string_literal: true

require "plutonium/positioning/config"

module Plutonium
  module Definition
    # Declares a resource drag-orderable. The MODEL owns how positions are
    # stored (`positioned_on :position, scope: :project_id`); this only says
    # "this UI can be reordered", and never restates the column or the scope.
    #
    #   position_on                      # Mode A, attribute :position
    #   position_on :sort_order          # Mode A, custom attribute
    #   position_on(:rank) { |move| … }  # Mode B, another gem owns the write
    #   position_on false                # Mode C, ordering off
    #
    # Mirrors kanban's `position_on` (lib/plutonium/kanban/dsl.rb:46) exactly,
    # and builds the same Plutonium::Positioning::Config.
    module Positioning
      extend ActiveSupport::Concern

      included do
        class_attribute :defined_position_config, instance_writer: false,
          instance_predicate: false, default: nil

        def self.position_on(attribute = :position, &block)
          config =
            if attribute == false
              Plutonium::Positioning::Config.disabled
            elsif block
              Plutonium::Positioning::Config.with_block(attribute, block)
            else
              validate_model_is_positioned!(attribute)
              Plutonium::Positioning::Config.attribute(attribute)
            end

          self.defined_position_config = config
          return config if config.disabled?

          # Registering the sort is load-bearing: dragging is only permitted
          # when the collection is ordered by this attribute, so without a
          # permitted sort there is no way back out of the disabled state.
          sort config.attribute
          default_sort config.attribute, :asc

          # Hidden: it has a route and a `reposition?` policy predicate, but is
          # reachable only by dragging — never rendered as a button.
          action :reposition, hidden: true

          config
        end

        # Mode A calls record.reposition!, which only exists on models that
        # include the concern. Fail at class-load time rather than on first drag.
        def self.validate_model_is_positioned!(attribute)
          return if model_class.include?(Plutonium::Positioning)

          raise ArgumentError,
            "#{name || "definition"}: `position_on #{attribute.inspect}` requires " \
            "#{model_class} to `include Plutonium::Positioning` and declare " \
            "`positioned_on`. If another gem owns positioning for this model, " \
            "use the block form instead: position_on(#{attribute.inspect}) { |move| … }"
        end
      end

      def defined_position_config = self.class.defined_position_config
    end
  end
end
```

- [ ] **Step 4: Include it in the definition base**

In `lib/plutonium/definition/base.rb`, add to the include list (lines 28-40). It must come **after** `Actions` and `Sorting`, because `position_on` calls `action`, `sort`, and `default_sort`:

```ruby
      include Actions
      include Wizards
      include Sorting
      include Positioning
      include Scoping
```

- [ ] **Step 5: Write the failing board-inheritance test**

A board must inherit the definition's `position_on`, with its own block overriding. Append to `test/plutonium/definition/positioning_test.rb`:

```ruby
      def test_board_inherits_the_definitions_position_on
        definition = build_definition(::Task) do
          position_on :sort_order
          kanban { columns :todo, :done }
        end

        board = definition.defined_kanban_board
        config = board.position_config_for(definition.new)

        assert_equal :sort_order, config.attribute
      end

      def test_a_board_block_overrides_the_definition
        definition = build_definition(::Task) do
          position_on :sort_order
          kanban do
            columns :todo, :done
            position_on :board_rank
          end
        end

        board = definition.defined_kanban_board
        assert_equal :board_rank, board.position_config_for(definition.new).attribute
      end

      # A board on a definition with no position_on keeps the historic default.
      def test_board_falls_back_to_the_default_when_nothing_is_declared
        definition = build_definition(::Task) { kanban { columns :todo, :done } }
        config = definition.defined_kanban_board.position_config_for(definition.new)

        assert_equal :position, config.attribute
        refute config.disabled?
      end
```

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/positioning_test.rb -n /board/`
Expected: FAIL — `NoMethodError: undefined method 'position_config_for'`

- [ ] **Step 6: Stop the DSL seeding a default**

`lib/plutonium/kanban/dsl.rb:18` currently reads `@position_config = Positioning::Config.default`, which makes "not declared" indistinguishable from "declared as the default" — inheritance is impossible while that holds. Change it to:

```ruby
        # nil means "not declared" so the board can inherit the definition's
        # position_on. Resolution — including the historic Config.default
        # fallback — moves to Board#position_config_for.
        @position_config = nil
```

- [ ] **Step 7: Resolve lazily on the Board**

In `lib/plutonium/kanban/board.rb`, beside `show_in_for` (line 37), which this deliberately mirrors:

```ruby
      # The board's positioning strategy: its own `position_on` if the block
      # declared one, else the definition's, else the historic default.
      #
      # Resolved LAZILY, not at build time: `kanban` eagerly compiles the board
      # at class-load (definition/index_views.rb:121), so a board built before a
      # later `position_on` line would silently miss it — making the declaration
      # order-dependent.
      def position_config_for(definition)
        @position_config || definition.defined_position_config ||
          Plutonium::Positioning::Config.default
      end
```

Keep `attr_reader :position_config` (line 6) — it is the "did this block declare one" accessor that `position_config_for` reads.

- [ ] **Step 8: Update the five kanban call sites**

In `lib/plutonium/resource/controllers/kanban_actions.rb`, replace `board.position_config` with `board.position_config_for(current_definition)` at lines 136, 259, 581, 733, and 784.

Verify none were missed:

Run: `rg -n "position_config\b" lib/plutonium/resource/controllers/kanban_actions.rb`
Expected: every hit is `position_config_for(current_definition)` — a bare `board.position_config` remaining is a bug.

- [ ] **Step 9: Run the tests**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/positioning_test.rb`
Expected: PASS

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/base_test.rb`
Expected: PASS

Run: `bundle exec appraisal rails-8.1 rake test`
Expected: PASS — the kanban suite is the gate for the Board change.

- [ ] **Step 10: Commit**

```bash
git add lib/plutonium/definition/positioning.rb lib/plutonium/definition/base.rb \
        lib/plutonium/kanban/dsl.rb lib/plutonium/kanban/board.rb \
        lib/plutonium/resource/controllers/kanban_actions.rb \
        test/plutonium/definition/positioning_test.rb
git commit -m "feat(definition): add the position_on DSL, inherited by kanban boards"
```

---

### Task 5: The reposition endpoint

**Goal:** `POST <member>/reposition` moves a record between two neighbours, authorized and scoped, responding per the reconciliation rules.

**Files:**
- Create: `lib/plutonium/resource/controllers/position_actions.rb`
- Modify: `lib/plutonium/routing/mapper_extensions.rb:~155`
- Modify: `lib/plutonium/resource/policy.rb` (add `reposition?`)
- Modify: `lib/plutonium/resource/controller.rb` (include the concern)
- Test: `test/plutonium/resource/controllers/position_actions_test.rb` (new)

**Acceptance Criteria:**
- [ ] `POST <member>/reposition` with `{prev_id, next_id}` repositions the record
- [ ] `reposition?` defaults to `update?`
- [ ] Neighbours resolve within `current_authorized_scope` only
- [ ] Clean Mode A drop → `204`; rebalance or unresolvable neighbour → turbo-stream tbody
- [ ] Mode B → always turbo-stream
- [ ] Denial → `403` + tbody + toast; `RecordNotFound` / `RecordInvalid` → `422` + tbody + toast
- [ ] A resource without `position_on` returns `404`

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/controllers/position_actions_test.rb` → all pass

**Steps:**

- [ ] **Step 1: Add the policy predicate**

In `lib/plutonium/resource/policy.rb`, next to `kanban_move?` (line 185):

```ruby
      # Authorizes a drag-reorder. Delegates to update? by default — override to
      # allow reordering without granting full edit-form access.
      #
      # @return [Boolean] Delegates to update?.
      def reposition?
        update?
      end
```

- [ ] **Step 2: Add the route**

In `lib/plutonium/routing/mapper_extensions.rb`, inside `define_member_interactive_actions`, after the kanban lines (155):

```ruby
          post "reposition", action: :reposition, as: :reposition
```

- [ ] **Step 3: Write the failing tests**

Create `test/plutonium/resource/controllers/position_actions_test.rb`. Follow the existing controller-test conventions in `test/plutonium/resource/` — read a neighbouring controller test first and match its setup (portal mounting, sign-in helper, `Task` fixtures).

Cover, at minimum:

```ruby
def test_reposition_moves_the_record_between_its_neighbours
  a, b, c = three_tasks_in_position_order

  post reposition_task_path(c), params: {prev_id: a.id, next_id: b.id}

  assert_response :no_content
  assert_operator a.reload.position, :<, c.reload.position
  assert_operator c.reload.position, :<, b.reload.position
end

def test_clean_drop_returns_204_with_no_body
  a, b, c = three_tasks_in_position_order
  post reposition_task_path(c), params: {prev_id: a.id, next_id: b.id}

  assert_response :no_content
  assert_empty response.body
end

def test_a_rebalance_streams_the_tbody
  a, b, c = three_tasks_in_position_order
  a.update_column(:position, 1.0)
  b.update_column(:position, 1.0 + 1e-9)

  post reposition_task_path(c), params: {prev_id: a.id, next_id: b.id}

  assert_response :success
  assert_match "turbo-stream", response.body
end

# A neighbour id outside the authorized scope must NOT silently become nil —
# that would mean "drop at the end", a different and wrong outcome.
def test_a_neighbour_outside_the_authorized_scope_reconciles_instead_of_appending
  c = task_in_scope
  foreign = task_outside_scope

  post reposition_task_path(c), params: {prev_id: foreign.id, next_id: nil}

  assert_response :success
  assert_match "turbo-stream", response.body
end

def test_denied_reposition_returns_403_and_snaps_back
  # policy stubbed so reposition? is false
  assert_response :forbidden
  assert_match "turbo-stream", response.body
end

def test_a_resource_without_positioned_returns_404
  post reposition_comment_path(comment), params: {prev_id: nil, next_id: nil}
  assert_response :not_found
end
```

- [ ] **Step 4: Run and watch them fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/controllers/position_actions_test.rb`
Expected: FAIL — no `reposition` action

- [ ] **Step 5: Write the concern**

Create `lib/plutonium/resource/controllers/position_actions.rb`. The rescue clauses mirror `KanbanActions` (`kanban_actions.rb:331-372`) and each encodes a real lesson — keep the comments.

```ruby
# frozen_string_literal: true

module Plutonium
  module Resource
    module Controllers
      # Drag-reorder endpoint for resources whose definition declares `position_on`.
      #
      # POST <member>/reposition with {prev_id:, next_id:} — the ids of the
      # dropped row's visible neighbours, either nullable for a drop at an end.
      #
      # The client has already moved the row optimistically, so a clean drop
      # answers 204. The tbody is streamed back only when the client's view is
      # or may be stale: a rebalance renumbered the group, a neighbour did not
      # resolve, or the write was a Mode B block (opaque — see spec §3.1).
      module PositionActions
        extend ActiveSupport::Concern

        def reposition
          config = current_definition.defined_position_config

          if config.nil? || config.disabled?
            # Not a reorderable resource — a 404, not an authorization failure.
            skip_verify_authorize_current!
            head :not_found
            return
          end

          record = current_authorized_scope.find(params[:id])
          authorize_current! record, to: :reposition?

          # Resolve neighbours WITHIN the authorized scope. A nil here would mean
          # "drop at the end", so an id that does not resolve must be treated as
          # drift and reconciled — never silently coerced to nil.
          prev_record, prev_ok = resolve_position_neighbour(params[:prev_id])
          next_record, next_ok = resolve_position_neighbour(params[:next_id])

          rebalanced = config.reposition!(
            record:,
            column: nil,
            prev_record:,
            next_record:,
            index: params[:to_index].to_i
          )

          if rebalanced || !prev_ok || !next_ok
            render_position_reconciliation
          else
            head :no_content
          end
        rescue ::ActionPolicy::Unauthorized
          # NOTE: the leading :: is required — Plutonium::ActionPolicy exists, so a
          # bare ActionPolicy resolves to that namespace and never matches, letting
          # the exception reach the global rescue_from, which re-raises for
          # turbo_stream requests → an HTML error page morphed into the table.
          #
          # authorize_count only bumps after a SUCCESSFUL authorize, so a denial
          # leaves the verifier unsatisfied; we handled authorization by rejecting.
          skip_verify_authorize_current!
          render_position_reconciliation(
            reason: "You are not authorized to reorder this.",
            status: :forbidden
          )
        rescue ActiveRecord::RecordNotFound
          # The row was destroyed between render and drop. `find` raised before
          # authorize_current!, so satisfy that verifier explicitly.
          skip_verify_authorize_current!
          render_position_reconciliation(reason: "This record no longer exists.")
        rescue ActiveRecord::RecordInvalid => e
          reason = e.record.errors.full_messages.to_sentence.presence ||
            "This record could not be moved."
          render_position_reconciliation(reason:)
        end

        private

        # Returns [record, resolved?]. A blank id is a legitimate end-of-list
        # drop → [nil, true]. An id that does not resolve in the authorized
        # scope is drift → [nil, false], which forces reconciliation.
        def resolve_position_neighbour(id)
          return [nil, true] if id.blank?
          record = current_authorized_scope.find_by(id: id)
          [record, !record.nil?]
        end

        # Re-renders the collection so the client's optimistic DOM is replaced by
        # the server's truth — the row snaps back on rejection, or settles into
        # its true place after a rebalance.
        def render_position_reconciliation(reason: nil, status: :ok)
          streams = [turbo_stream.update(position_collection_frame_id, render_position_collection_html)]

          if reason
            streams << turbo_stream.append(
              "position-flash",
              partial: "plutonium/toast",
              locals: {type: :warning, msg: reason}
            )
          end

          render turbo_stream: streams, status:
        end
      end
    end
  end
end
```

**Note for the implementer:** `position_collection_frame_id` and `render_position_collection_html` are the two methods that must bind this concern to the actual table rendering. Locate how `CrudActions#index` builds the collection component (`lib/plutonium/resource/controllers/crud_actions.rb`) and reuse that path — do **not** invent a parallel rendering route. Model them on `KanbanActions#render_kanban_column_html` (`kanban_actions.rb:568`), which resolves the same query pipeline and renders one component to an HTML-safe string.

- [ ] **Step 6: Include the concern**

In `lib/plutonium/resource/controller.rb`, include `PositionActions` alongside the other controller concerns. Match the existing include order and style — check where `KanbanActions` is included and put this next to it.

- [ ] **Step 7: Run the tests**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/controllers/position_actions_test.rb`
Expected: PASS

Run: `bundle exec appraisal rails-8.1 rake test`
Expected: PASS

- [ ] **Step 8: Commit**

```bash
git add lib/plutonium/resource/controllers/position_actions.rb \
        lib/plutonium/routing/mapper_extensions.rb lib/plutonium/resource/policy.rb \
        lib/plutonium/resource/controller.rb \
        test/plutonium/resource/controllers/position_actions_test.rb
git commit -m "feat(positioning): add the reposition endpoint"
```

---

### Task 6: Extract the shared drag core

**Goal:** One native-DnD implementation, in `src/js/drag/sortable.js`, with kanban's behaviour unchanged.

**Files:**
- Create: `src/js/drag/sortable.js`
- Modify: `src/js/controllers/kanban_controller.js:433-523, 700-706`

**Acceptance Criteria:**
- [ ] `sortable.js` exports the drag mechanics with no kanban/board/column knowledge
- [ ] `kanban_controller.js` consumes it; its drag behaviour is byte-for-byte equivalent
- [ ] Kanban's suite passes unchanged
- [ ] `yarn build` succeeds

**Verify:** `bundle exec appraisal rails-8.1 rake test` and manual kanban drag in the dummy app

**Steps:**

- [ ] **Step 1: Create the shared module**

Create `src/js/drag/sortable.js`. Extract only what is genuinely generic — the parts of `kanban_controller.js` that reference no board concept:

```javascript
// Shared native HTML5 drag-and-drop mechanics.
//
// Deliberately knows nothing about kanban columns, tables, WIP limits, or
// Turbo. Consumers wire it to their own DOM contract and own the transport.
//
// Consumers: kanban_controller.js, positioned_controller.js

// Returns the 0-based insertion index for a drop at `clientY` among `items`,
// by finding the first item whose vertical midpoint is below the cursor.
// Extracted verbatim from kanban_controller.js#computeDropIndex.
export function computeDropIndex(clientY, items) {
  for (let i = 0; i < items.length; i++) {
    const rect = items[i].getBoundingClientRect()
    if (clientY < rect.top + rect.height / 2) return i
  }
  return items.length
}

// Horizontal variant, for grid/card layouts that flow in rows.
export function computeDropIndexHorizontal(clientX, items) {
  for (let i = 0; i < items.length; i++) {
    const rect = items[i].getBoundingClientRect()
    if (clientX < rect.left + rect.width / 2) return i
  }
  return items.length
}

// Applies the drag ghost + dragging class. Deferred by one frame so the
// browser captures the ghost image BEFORE the opacity change — otherwise the
// dragged element's ghost is rendered already-faded.
export function beginDrag(event, element, { draggingClass, payload }) {
  event.dataTransfer.effectAllowed = "move"
  event.dataTransfer.setData("text/plain", payload)
  requestAnimationFrame(() => element.classList.add(draggingClass))
}

export function endDrag(element, { draggingClass }) {
  element?.classList.remove(draggingClass)
}
```

- [ ] **Step 2: Consume it from kanban**

In `src/js/controllers/kanban_controller.js`:

Add at the top, with the other imports:

```javascript
import { computeDropIndex, beginDrag, endDrag } from "../drag/sortable.js"
```

Delete the private `#computeDropIndex` method (lines 700-706) and change its call site (line 497) to the import:

```javascript
    const toIndex = computeDropIndex(event.clientY, existingCards)
```

In `#onDragStart` (lines 433-448), replace the `dataTransfer` + `requestAnimationFrame` block with `beginDrag`, keeping the kanban-specific `#applyDropHints` call:

```javascript
  #onDragStart(event) {
    const card = event.target.closest("[data-kanban-record-id]")
    if (!card) return

    this.draggedCard = card
    beginDrag(event, card, {
      draggingClass: "pu-kanban-dragging",
      payload: card.dataset.kanbanRecordId,
    })

    // Mark columns that would reject a drop from this card's source column.
    this.#applyDropHints(card.dataset.kanbanColumnKey)
  }
```

Use `endDrag` in the existing `#onDragEnd` cleanup, leaving the highlight and hint clearing (both board-specific) in place.

**Do not move** `#applyDropHints`, `#highlightColumn`, `#clearHighlights`, `#openDropInteraction`, or `#submitMove` — all are board-specific and stay in the kanban controller.

- [ ] **Step 3: Build and verify**

Run: `yarn build`
Expected: completes with no errors

Run: `bundle exec appraisal rails-8.1 rake test`
Expected: PASS

- [ ] **Step 4: Manually verify kanban still drags**

Boot the dummy app and drag a card within a column, across columns, into a WIP-limited column, and into a locked column. All four must behave exactly as before. This is a refactor — any behaviour change is a bug.

- [ ] **Step 5: Commit**

```bash
git add src/js/drag/sortable.js src/js/controllers/kanban_controller.js app/assets
git commit -m "refactor(js): extract shared drag mechanics from the kanban controller"
```

---

### Task 7: The `positioned` Stimulus controller and table grip

**Goal:** A hover grip in each row's first cell drags to reorder, disabled and offering a sort when the table is not in position order.

**Files:**
- Create: `src/js/controllers/positioned_controller.js`
- Create: `lib/plutonium/ui/table/components/drag_handle.rb`
- Modify: `src/js/controllers/register_controllers.js:39,82`
- Modify: `lib/plutonium/ui/table/resource.rb:~152` (wrap the first column's block)

**Acceptance Criteria:**
- [ ] Only the grip carries `draggable="true"` — never the `<tr>`
- [ ] Grip is hidden until row hover, and visible on keyboard focus
- [ ] Grip is a `<button>`
- [ ] When the effective sort is not the position attribute, the grip is disabled and applies the position sort on click
- [ ] Dropping posts `{prev_id, next_id, to_index}` and applies the turbo-stream response
- [ ] No grip renders when the definition has no `position_on` or is Mode C
- [ ] **Nested tables work too**: the reposition URL is the *nested* member route, and neighbours resolve within the parent-scoped `current_authorized_scope`

**Verify:** `yarn build` succeeds; manual drag in the dummy app on `/tasks`

**Steps:**

- [ ] **Step 1: Write the grip component**

Create `lib/plutonium/ui/table/components/drag_handle.rb`:

```ruby
# frozen_string_literal: true

module Plutonium
  module UI
    module Table
      module Components
        # The drag affordance for a positioned row.
        #
        # Lives INSIDE the first cell, not in a column of its own — a permanent
        # grip column costs horizontal space on every row for a feature used
        # occasionally.
        #
        # Only this element is draggable, never the <tr>. draggable="true"
        # disables text selection within the element in every major browser, so
        # a draggable row would silently remove the ability to select and copy a
        # cell value — and would fight row_click_controller.js, which already
        # makes the whole row the Show affordance.
        #
        # When `sort_url` is present the table is NOT in position order, so the
        # grip renders disabled and doubles as the control that restores it.
        class DragHandle < Phlexi::Table::HTML
          def initialize(record_id:, sort_url: nil)
            @record_id = record_id
            @sort_url = sort_url
          end

          def view_template
            @sort_url ? render_sort_affordance : render_grip
          end

          private

          def render_grip
            # The handle carries NO record id — the row it lives in owns that
            # (data-positioned-row-id). One source of truth; the controller
            # always reads the id from the row.
            button(
              type: :button,
              draggable: "true",
              class: themed(:drag_handle),
              aria_label: "Drag to reorder. Use arrow keys to move up or down.",
              data: {
                positioned_target: "handle",
                action: "keydown->positioned#onHandleKeydown"
              }
            ) { render_grip_icon }
          end

          # Disabled state: the table is sorted by another column, so the visible
          # neighbours are not position-adjacent and a drop would be meaningless.
          # Clicking restores position order rather than explaining where to find
          # the control.
          def render_sort_affordance
            a(
              href: @sort_url,
              class: themed(:drag_handle_disabled),
              title: "Sort by position to reorder",
              data: {turbo_frame: "_top"}
            ) { render_grip_icon }
          end

          def render_grip_icon
            render Phlex::TablerIcons::GripVertical.new(class: "size-4")
          end
        end
      end
    end
  end
end
```

Add `drag_handle` and `drag_handle_disabled` to `lib/plutonium/ui/table/theme.rb`. The grip must be invisible until hover but visible on focus:

```ruby
        drag_handle: "opacity-0 group-hover/row:opacity-100 focus:opacity-100 " \
                     "cursor-grab active:cursor-grabbing text-[var(--pu-text-subtle)] " \
                     "hover:text-[var(--pu-text)] transition-opacity",
        drag_handle_disabled: "opacity-0 group-hover/row:opacity-40 focus:opacity-100 " \
                              "cursor-pointer text-[var(--pu-text-subtle)] transition-opacity",
```

This requires `group/row` on the `<tr>` — check `lib/plutonium/ui/table/base.rb` for where row attributes are set and add it there if absent.

- [ ] **Step 2: Render the grip in the first cell**

In `lib/plutonium/ui/table/resource.rb`, inside the `@resource_fields.each` loop (around line 152), wrap the first field's `tag_block` so the grip precedes the cell content. Add before the loop:

```ruby
            position_config = resource_definition.defined_position_config
            positioned = position_config && !position_config.disabled?
            first_field = @resource_fields.first
            # nil when the table IS in position order (grip is live); a URL when
            # it is not (grip is disabled and links back to position order).
            position_sort_url = if positioned && !ordered_by_position?(position_config)
              current_query_object.sort_params_for(position_config.attribute)[:url]
            end
```

Then, where `tag_block` is assigned, wrap it for the first field only:

```ruby
              if positioned && name == first_field
                inner_block = tag_block
                tag_block = ->(wrapped_object, key) {
                  div(class: "flex items-center gap-2") do
                    render DragHandle.new(
                      record_id: wrapped_object.unwrapped.id,
                      sort_url: position_sort_url
                    )
                    render inner_block.call(wrapped_object, key)
                  end
                }
              end
```

Add a private `ordered_by_position?(config)` that compares the query object's active sort field to `config.attribute`. Read `lib/plutonium/resource/query_object.rb` for the exact accessor — do not guess it.

- [ ] **Step 3: Write the Stimulus controller**

Create `src/js/controllers/positioned_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"
import { computeDropIndex, beginDrag, endDrag } from "../drag/sortable.js"

// Connects to data-controller="positioned"
//
// Drag-to-reorder for tables, nested tables, and grids backed by a `position_on`
// definition. Only the grip is draggable (see DragHandle for why).
//
// The client moves the row optimistically. A clean drop answers 204 and nothing
// more happens; when the server needs to reconcile it streams the collection
// back, which replaces whatever the client did.
export default class extends Controller {
  static values = { url: String }
  static targets = ["handle", "row"]

  connect() {
    this.onDragStart = this.#onDragStart.bind(this)
    this.onDragOver = this.#onDragOver.bind(this)
    this.onDrop = this.#onDrop.bind(this)
    this.onDragEnd = this.#onDragEnd.bind(this)

    this.element.addEventListener("dragstart", this.onDragStart)
    this.element.addEventListener("dragover", this.onDragOver)
    this.element.addEventListener("drop", this.onDrop)
    this.element.addEventListener("dragend", this.onDragEnd)
  }

  disconnect() {
    this.element.removeEventListener("dragstart", this.onDragStart)
    this.element.removeEventListener("dragover", this.onDragOver)
    this.element.removeEventListener("drop", this.onDrop)
    this.element.removeEventListener("dragend", this.onDragEnd)
  }

  #onDragStart(event) {
    const handle = event.target.closest("[data-positioned-target='handle']")
    if (!handle) return

    this.draggedRow = handle.closest("[data-positioned-target='row']")
    if (!this.draggedRow) return

    beginDrag(event, this.draggedRow, {
      draggingClass: "pu-positioned-dragging",
      payload: this.draggedRow.dataset.positionedRowId,
    })
  }

  #onDragOver(event) {
    if (!this.draggedRow) return
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  #onDrop(event) {
    event.preventDefault()
    if (!this.draggedRow) return

    const others = this.rowTargets.filter(r => r !== this.draggedRow)
    const toIndex = computeDropIndex(event.clientY, others)

    // Optimistic move: insert before the row now at toIndex, or append.
    const anchor = others[toIndex]
    if (anchor) {
      anchor.parentNode.insertBefore(this.draggedRow, anchor)
    } else if (others.length) {
      const last = others[others.length - 1]
      last.parentNode.insertBefore(this.draggedRow, last.nextSibling)
    }

    this.#submit(this.draggedRow, {
      prevId: others[toIndex - 1]?.dataset.positionedRowId ?? "",
      nextId: others[toIndex]?.dataset.positionedRowId ?? "",
      toIndex,
    })
  }

  #onDragEnd() {
    endDrag(this.draggedRow, { draggingClass: "pu-positioned-dragging" })
    this.draggedRow = null
  }

  // Keyboard reorder: native HTML5 DnD is mouse-only, so without this the
  // feature is unusable by keyboard. Moves one slot per keypress, reusing the
  // same endpoint and neighbour computation as a drag.
  onHandleKeydown(event) {
    if (event.key !== "ArrowUp" && event.key !== "ArrowDown") return
    event.preventDefault()

    const row = event.target.closest("[data-positioned-target='row']")
    if (!row) return

    const rows = this.rowTargets
    const from = rows.indexOf(row)
    const to = event.key === "ArrowUp" ? from - 1 : from + 1
    if (to < 0 || to >= rows.length) return

    const anchor = event.key === "ArrowUp" ? rows[to] : rows[to].nextSibling
    row.parentNode.insertBefore(row, anchor)
    event.target.focus()

    const others = this.rowTargets.filter(r => r !== row)
    this.#submit(row, {
      prevId: others[to - 1]?.dataset.positionedRowId ?? "",
      nextId: others[to]?.dataset.positionedRowId ?? "",
      toIndex: to,
    })
  }

  async #submit(row, { prevId, nextId, toIndex }) {
    const url = this.urlValue.replace("__ID__", row.dataset.positionedRowId)
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content ?? ""

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": csrfToken,
      },
      body: new URLSearchParams({ prev_id: prevId, next_id: nextId, to_index: toIndex }),
      credentials: "same-origin",
    })

    // 204 means the optimistic DOM is already correct — nothing to apply.
    if (response.status === 204) return

    const html = await response.text()
    if (html) window.Turbo.renderStreamMessage(html)
  }
}
```

- [ ] **Step 4: Register the controller**

In `src/js/controllers/register_controllers.js`, add the import beside the others (near line 39):

```javascript
import PositionedController from "./positioned_controller.js"
```

and the registration (near line 82):

```javascript
  application.register("positioned", PositionedController)
```

- [ ] **Step 5: Wire the controller onto the table**

The table wrapper needs `data-controller="positioned"` and `data-positioned-url-value` (the member reposition path with `__ID__`), each row needs `data-positioned-target="row"` and `data-positioned-row-id`, and there must be a `#position-flash` region for reconciliation toasts. Add these in `lib/plutonium/ui/table/resource.rb` where the table wrapper is built — mirror how the kanban board supplies `moveUrlTemplateValue` (`Kanban::Resource#kanban_move_url_template`).

- [ ] **Step 6: Verify the nested-table URL**

Nested association tables render through this same `Table::Resource` component, so the grip comes for free — but the reposition URL must be the **nested** member route (`/posts/1/comments/5/reposition`), not the top-level one. If Step 5 builds the URL from `resource_url_for(resource_class)`, that resolves correctly in a nested context already; verify it rather than assume.

`KanbanActions#render_kanban_column_html` (`kanban_actions.rb:616`) documents why the URL is derived from `resource_url_for` and not `request.path` — the same reasoning applies here, because the reposition POST's own `request.path` is the member route, not the collection path.

Confirm in the dummy app on a parent's show page that a nested positioned collection drags and persists, and that its POST goes to the nested path.

- [ ] **Step 7: Build and verify manually**

Run: `yarn build`
Expected: no errors

Boot the dummy app, visit the Tasks index, and confirm: grip appears on hover; dragging reorders and persists across reload; sorting by another column greys the grip; clicking the greyed grip restores position order; tabbing to a grip and pressing ArrowUp/ArrowDown moves the row.

- [ ] **Step 8: Commit**

```bash
git add src/js/controllers/positioned_controller.js src/js/controllers/register_controllers.js \
        lib/plutonium/ui/table/components/drag_handle.rb lib/plutonium/ui/table/resource.rb \
        lib/plutonium/ui/table/theme.rb lib/plutonium/ui/table/base.rb app/assets
git commit -m "feat(ui): drag-to-reorder for positioned index tables"
```

---

### Task 8: Grid/card surface

**Goal:** The same grip and controller on grid/card index views.

**Files:**
- Modify: `lib/plutonium/ui/grid/card.rb`
- Modify: `lib/plutonium/ui/grid/resource.rb`

**Acceptance Criteria:**
- [ ] Cards render the grip when the definition is positioned
- [ ] Grid uses `computeDropIndexHorizontal` where cards flow in rows
- [ ] The grid wrapper carries the same `positioned` controller wiring as the table

**Verify:** `yarn build`; manual drag on a grid index in the dummy app

**Steps:**

- [ ] **Step 1: Render the grip on the card**

In `lib/plutonium/ui/grid/card.rb`, render `Plutonium::UI::Table::Components::DragHandle` in the card header when `resource_definition.defined_position_config` is present and not disabled. Reuse the component rather than writing a second one — the affordance and its rationale are identical.

- [ ] **Step 2: Wire the grid wrapper**

In `lib/plutonium/ui/grid/resource.rb`, add the same `data-controller="positioned"`, `data-positioned-url-value`, per-card `data-positioned-target="row"` / `data-positioned-row-id`, and `#position-flash` region as the table (Task 7 Step 5).

- [ ] **Step 3: Select the horizontal index computation**

Add a `data-positioned-axis-value` of `"horizontal"` on the grid wrapper, and in `positioned_controller.js` branch on it:

```javascript
  static values = { url: String, axis: { type: String, default: "vertical" } }

  #dropIndex(event, items) {
    return this.axisValue === "horizontal"
      ? computeDropIndexHorizontal(event.clientX, items)
      : computeDropIndex(event.clientY, items)
  }
```

Replace both `computeDropIndex(event.clientY, others)` call sites with `this.#dropIndex(event, others)`.

- [ ] **Step 4: Build and verify**

Run: `yarn build`
Expected: no errors

Manually drag a card on a grid index and confirm it reorders and persists.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/ui/grid/card.rb lib/plutonium/ui/grid/resource.rb \
        src/js/controllers/positioned_controller.js app/assets
git commit -m "feat(ui): drag-to-reorder for positioned grid views"
```

---

### Task 9: System test

**Goal:** An end-to-end test that a real drag and a real keyboard reorder both persist.

**Files:**
- Create: `test/system/positioned_drag_test.rb`
- Modify: `test/dummy/app/definitions/task_definition.rb` (add `position_on`)

**Acceptance Criteria:**
- [ ] A drag on the Tasks index reorders and survives a reload
- [ ] ArrowDown on a focused grip reorders and survives a reload
- [ ] Sorting by another column disables the grip

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/system/positioned_drag_test.rb` → all pass

**Steps:**

- [ ] **Step 1: Declare `position_on` on the dummy Task definition**

`Task` already has `positioned_on :position, scope: :status` (`test/dummy/app/models/task.rb:10`). Add to `test/dummy/app/definitions/task_definition.rb`:

```ruby
  position_on
```

**Important:** `test/dummy` is git-cleaned by the generator tests. Stage this change before running the suite, or it will be reverted mid-run.

- [ ] **Step 2: Write the system test**

Create `test/system/positioned_drag_test.rb`, following the conventions of the existing tests in `test/system/` (read one first for the driver setup and sign-in helper).

```ruby
# frozen_string_literal: true

require "application_system_test_case"

class PositionedDragTest < ApplicationSystemTestCase
  def test_dragging_a_row_reorders_it_and_persists
    visit_tasks_index

    first_row_id = page.all("[data-positioned-target='row']").first["data-positioned-row-id"]
    drag_row(first_row_id, to_index: 2)

    visit current_path
    refute_equal first_row_id,
      page.all("[data-positioned-target='row']").first["data-positioned-row-id"]
  end

  def test_keyboard_reorder_persists
    visit_tasks_index

    first_row_id = page.all("[data-positioned-target='row']").first["data-positioned-row-id"]
    find("[data-positioned-row-id='#{first_row_id}'] [data-positioned-target='handle']")
      .send_keys(:arrow_down)

    visit current_path
    refute_equal first_row_id,
      page.all("[data-positioned-target='row']").first["data-positioned-row-id"]
  end

  def test_sorting_by_another_column_disables_the_grip
    visit_tasks_index
    click_on "Name"

    assert_selector "[title='Sort by position to reorder']"
    assert_no_selector "[data-positioned-target='handle']"
  end
end
```

- [ ] **Step 3: Run**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/system/positioned_drag_test.rb`
Expected: PASS

- [ ] **Step 4: Run the full suite across Rails versions**

Run: `bundle exec appraisal rake test`
Expected: PASS on rails-7, rails-8.0, rails-8.1

- [ ] **Step 5: Commit**

```bash
git add test/system/positioned_drag_test.rb test/dummy/app/definitions/task_definition.rb
git commit -m "test(positioning): system tests for drag and keyboard reorder"
```

---

### Task 10: Documentation and skills

**Goal:** The feature is discoverable, and the Mode B escape hatch is documented with a worked third-party example.

**Files:**
- Create: `docs/reference/positioning.md`
- Modify: `docs/reference/actions.md` (hidden actions)
- Modify: `.claude/skills/plutonium-resource/SKILL.md`
- Modify: `.claude/skills/plutonium-ui/SKILL.md`
- Modify: `docs/.vitepress/config.*` (sidebar entry)

**Acceptance Criteria:**
- [ ] The model/definition split is explained: `positioned_on` vs `position_on`
- [ ] All three modes documented, with a worked `acts_as_list` example
- [ ] The nested-scope contract from spec §2.1 is stated
- [ ] The implicit `default_sort` override is called out prominently
- [ ] The deliberate table-vs-kanban affordance difference is explained
- [ ] Hidden actions documented, including that they are NOT an authorization boundary
- [ ] `yarn docs:build` succeeds with no broken links

**Verify:** `yarn docs:build` → completes, no broken links

**Steps:**

- [ ] **Step 1: Write `docs/reference/positioning.md`**

Cover, in order: the model layer (`include Plutonium::Positioning`, `positioned_on`, the `t.position` migration helper); the definition layer (`position_on` and its four forms); what `position_on` expands to, with the `default_sort` override called out in a warning callout; when dragging is enabled and how the disabled grip restores position order; the nested-scope contract; and a worked Mode B example:

```ruby
# Using acts_as_list instead of Plutonium::Positioning
class TaskDefinition < Plutonium::Resource::Definition
  position_on :position do |move|
    move.record.insert_at(move.index + 1)
  end
end
```

Note that Mode B always reconciles, and why (`acts_as_list` renumbers the whole group).

- [ ] **Step 2: Document hidden actions**

In `docs/reference/actions.md`, add a section on `hidden: true`: what it gives you (route, policy predicate, form/params machinery), what it withholds (every render surface), and the warning that it is a display gate, not an authorization boundary — authorization belongs in the policy.

- [ ] **Step 3: Update the skills**

`plutonium-resource`: `position_on` in the definition DSL reference, alongside `sort` and `default_sort`.
`plutonium-ui`: the drag affordance, the table-vs-kanban difference and why (text selection + `row_click`).

Both skills require a gem release to take effect — note that in the commit message, not in the docs.

- [ ] **Step 4: Add the sidebar entry**

Add `positioning.md` to the reference section of the VitePress sidebar.

- [ ] **Step 5: Build the docs**

Run: `yarn docs:build`
Expected: completes, no broken links

- [ ] **Step 6: Commit**

```bash
git add docs .claude/skills
git commit -m "docs(positioning): document position_on, hidden actions, and the block escape hatch"
```

---

## Verification Summary

| Task | Command |
|---|---|
| 1 | `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/positioning_test.rb` (unmodified) |
| 2 | `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/positioning_test.rb` |
| 3 | `rg -n "kanban_drop\b" lib app test` → no output; then `bundle exec appraisal rails-8.1 rake test` |
| 4 | `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/positioning_test.rb` |
| 5 | `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/controllers/position_actions_test.rb` |
| 6 | `yarn build` + `bundle exec appraisal rails-8.1 rake test` + manual kanban drag |
| 7 | `yarn build` + manual drag on `/tasks` |
| 8 | `yarn build` + manual drag on a grid index |
| 9 | `bundle exec appraisal rake test` (all Rails versions) |
| 10 | `yarn docs:build` |

## Known Open Points

These are places where the plan deliberately says "locate the integration point" rather than inventing an API, because the exact seam was not verified during planning. The implementer must read the named file first:

1. **Task 5 Step 5** — `position_collection_frame_id` and `render_position_collection_html` must reuse `CrudActions`' existing collection-rendering path (`lib/plutonium/resource/controllers/crud_actions.rb`), modelled on `KanbanActions#render_kanban_column_html` (`kanban_actions.rb:568`).
2. **Task 7 Step 2** — the active-sort accessor on `lib/plutonium/resource/query_object.rb`, for `ordered_by_position?`.
3. **Task 7 Step 5** — where the table wrapper's attributes are built in `lib/plutonium/ui/table/resource.rb`.
4. **Task 7 Step 1** — whether `<tr>` already carries a `group/row` class in `lib/plutonium/ui/table/base.rb`.
