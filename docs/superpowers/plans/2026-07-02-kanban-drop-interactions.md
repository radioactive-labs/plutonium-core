# Kanban `drop_interaction` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a kanban column run an authorization-aware, input-collecting Interaction when a card is dropped into it — opening the interaction's modal form (e.g. "reason") and committing the move + interaction atomically — while leaving `on_drop` intact for membership + quick-add seeding.

**Architecture:** Add a new `drop_interaction:` column option that references an Interaction class. On a drop into such a column the Stimulus controller opens the interaction's modal (holding the card in a pending state) instead of firing the fire-and-forget move POST. The modal form submits back to `kanban_move`, which — in a single transaction — authorizes the interaction's own policy method, runs the interaction, then runs `on_drop` and repositions. Interaction failure rolls the transaction back and re-renders the modal with errors; cancel snaps the card back. `on_drop` keeps its existing role: membership write on plain columns and the quick-add seed source everywhere.

**Tech Stack:** Ruby / Rails (Plutonium engine), Phlex + ERB modal views, Hotwired Turbo Streams, Stimulus (`src/js/controllers/kanban_controller.js`), esbuild (`yarn build`), Minitest (`bundle exec appraisal rails-8.1 rake test`).

**User Verification:** NO — no user sign-off required; the original request is a feasibility-and-design question turned implementation. Verification is via automated tests + a manual dri(dummy app) smoke described in the final task.

---

## Design contract (read once before Task 0)

- **`drop_interaction:` takes an Interaction class**, e.g. `drop_interaction: MarkLostInteraction`. It is a **record action** (its interaction declares `attribute :resource`).
- **Registration:** at `kanban` compile time each column's `drop_interaction` is registered as a hidden interactive record action, keyed by the interaction's conventional name (`MarkLostInteraction → :mark_lost`). This reuses the existing action/policy/form machinery, so the authorization gate is the natural `def mark_lost?` on the policy — layered on top of the board-wide `kanban_move?`.
- **Two flows, split cleanly:**
  - **Move flow (drag):** `drop_interaction` opens the modal, then commits `on_drop` + interaction + reposition atomically.
  - **Seed flow (`+ Add` quick-add):** unchanged — always uses `on_drop`'s dry-run (`kanban_column_on_drop_seed`). The interaction is never dry-run.
- **Commit order inside the move transaction:** `on_drop` (assign + save membership) → `interaction.call` (sees the updated record; persists extras like `reason`; `deliver_later` side-effects only fire post-commit) → `reposition!`. Any failure raises `ActiveRecord::Rollback`.
- **Contract for authors:** the interaction owns the *extras* (reason, mail, audit); `on_drop` owns the *membership attribute* (status). If the interaction also sets the membership attribute it must be to the same value `on_drop` set (idempotent) — document, don't enforce.
- **Failure surfaces:** move-guard rejections (`accepts`/`locked`/`wip`/`kanban_move?`) keep the existing `render_kanban_rejection` snap-back-toast path and are checked *before* the modal opens. Interaction failures re-render the modal at 422 with `@interaction.errors`.

### File map

| File | Responsibility | Task |
|---|---|---|
| `lib/plutonium/kanban/column.rb` | Store + expose `drop_interaction`; derive its action key | 0 |
| `lib/plutonium/kanban/dsl.rb` | (no change — `**opts` already forwards; verify only) | 0 |
| `lib/plutonium/definition/index_views.rb` | Register each column's `drop_interaction` as a hidden record action at compile time | 1 |
| `lib/plutonium/action/base.rb` (+ factory) | Carry a `kanban_drop:` flag so drop actions don't render in toolbars | 1 |
| `lib/plutonium/routing/mapper_extensions.rb` | Add `GET kanban_move_form` member route | 2 |
| `lib/plutonium/resource/controllers/kanban_actions.rb` | `kanban_move_form` GET (render modal); `kanban_move` POST interaction branch | 3, 4 |
| `app/views/**/kanban_move_form` (ERB) | Modal wrapper rendering the interaction form, posting to `kanban_move` | 3 |
| `lib/plutonium/ui/kanban/column.rb` | Emit `data-kanban-drop-*` on drop-interaction columns | 5 |
| `src/js/controllers/kanban_controller.js` | On drop into a drop-interaction column, open the modal + pending/snap-back | 6 |
| `docs/guides/kanban.md`, `docs/reference/kanban/dsl.md`, `.claude/skills/plutonium-kanban/SKILL.md` | Document `drop_interaction` | 7 |
| `test/dummy/app/definitions/*` + system test | End-to-end drive | 8 |

---

### Task 0: `Column#drop_interaction` + derived action key

**Goal:** `Column` accepts and exposes `drop_interaction:`, derives its conventional action key, and rejects a non-interaction value.

**Files:**
- Modify: `lib/plutonium/kanban/column.rb:15-31`
- Verify (no edit): `lib/plutonium/kanban/dsl.rb:23-27`
- Test: `test/plutonium/kanban/column_test.rb`

**Acceptance Criteria:**
- [ ] `Column.new(:lost, drop_interaction: MarkLostInteraction).drop_interaction` returns the class.
- [ ] `#drop_interaction?` is true only when one is set.
- [ ] `#drop_interaction_key` returns `:mark_lost` for `MarkLostInteraction`.
- [ ] `Column.new(:x, drop_interaction: "nope")` raises `ArgumentError`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/column_test.rb` → all pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/kanban/column_test.rb (add these cases)
require "test_helper"

class DummyDropInteraction < Plutonium::Resource::Interaction
  attribute :resource
  def execute = succeed(resource)
end

class Plutonium::Kanban::ColumnDropInteractionTest < ActiveSupport::TestCase
  test "stores and exposes drop_interaction" do
    col = Plutonium::Kanban::Column.new(:lost, drop_interaction: DummyDropInteraction)
    assert_equal DummyDropInteraction, col.drop_interaction
    assert col.drop_interaction?
  end

  test "derives conventional action key from the interaction class name" do
    col = Plutonium::Kanban::Column.new(:lost, drop_interaction: DummyDropInteraction)
    assert_equal :dummy_drop, col.drop_interaction_key
  end

  test "no drop_interaction by default" do
    refute Plutonium::Kanban::Column.new(:todo).drop_interaction?
  end

  test "rejects a non-interaction drop_interaction" do
    assert_raises(ArgumentError) do
      Plutonium::Kanban::Column.new(:x, drop_interaction: "nope")
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/column_test.rb`
Expected: FAIL — `unknown keyword: :drop_interaction`.

- [ ] **Step 3: Implement in Column**

```ruby
# lib/plutonium/kanban/column.rb
attr_reader :key, :label, :color, :wip, :scope, :on_drop, :accepts, :actions, :drop_interaction

def initialize(key, label: nil, color: nil, wip: nil, scope: nil, on_drop: nil,
  collapsed: nil, add: nil, accepts: nil, locked: nil, role: nil, drop_interaction: nil)
  # ... existing assignments unchanged ...
  @on_drop = on_drop
  if drop_interaction && !(drop_interaction.is_a?(Class) && drop_interaction < Plutonium::Resource::Interaction)
    raise ArgumentError, "drop_interaction: must be a Plutonium::Resource::Interaction subclass, got #{drop_interaction.inspect}"
  end
  @drop_interaction = drop_interaction
  # ... rest unchanged ...
end

def drop_interaction? = !@drop_interaction.nil?

# MarkLostInteraction → :mark_lost (strip trailing "Interaction", underscore).
def drop_interaction_key
  return nil unless @drop_interaction
  @drop_interaction.name.demodulize.sub(/Interaction\z/, "").underscore.to_sym
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/kanban/column_test.rb`
Expected: PASS.

- [ ] **Step 5: Confirm DSL passthrough needs no change**

`lib/plutonium/kanban/dsl.rb:23` is `def column(key, **opts, &blk) = Column.new(key, **opts)` — `drop_interaction:` flows through `**opts` untouched. No edit; just confirm by reading.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/kanban/column.rb test/plutonium/kanban/column_test.rb
git commit -m "feat(kanban): add drop_interaction column option"
```

---

### Task 1: Register `drop_interaction` as a hidden record action at compile time

**Goal:** Each static column's `drop_interaction` is registered as an interactive **record** action (so its policy method + form + params machinery exist) but flagged `kanban_drop: true` so it never renders in a toolbar/row/show.

**Files:**
- Modify: `lib/plutonium/definition/index_views.rb:125-135`
- Modify: `lib/plutonium/action/base.rb` (add `kanban_drop?` reader + accept the option)
- Modify: `lib/plutonium/action/interactive/factory.rb` (pass `kanban_drop:` through) — confirm exact path first with `grep -rn "class Factory" lib/plutonium/action`
- Test: `test/plutonium/definition/index_views_test.rb` (or nearest existing kanban-registration test)

**Acceptance Criteria:**
- [ ] After a definition with `column :lost, drop_interaction: MarkLostInteraction` loads, `definition.defined_actions[:mark_lost]` is an `Action::Interactive` with `record_action? == true`.
- [ ] That action reports `kanban_drop? == true`.
- [ ] Actions the toolbar renders exclude `kanban_drop?` actions (assert the filter helper skips it).
- [ ] Dynamic `columns do…end` boards do **not** auto-register (documented constraint) — no crash, just nothing registered.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/definition/index_views_test.rb`

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/definition/index_views_test.rb (new case)
test "registers drop_interaction as a hidden record action" do
  klass = Class.new(Plutonium::Resource::Definition) do
    kanban do
      column :lost, scope: -> { all }, on_drop: ->(r) { r.status = "lost" },
        drop_interaction: MarkLostInteraction
    end
  end
  action = klass.new.defined_actions[:mark_lost]
  assert_kind_of Plutonium::Action::Interactive, action
  assert action.record_action?
  assert action.kanban_drop?
end
```

Ensure a `MarkLostInteraction` test fixture exists (define in the test or `test/dummy/app/interactions/mark_lost_interaction.rb` with `attribute :resource`, `attribute :reason, :string`, `input :reason`, `validates :reason, presence: true`, `execute { resource.update!(status: "lost", lost_reason: reason); succeed(resource) }`).

- [ ] **Step 2: Run test to verify it fails**

Run the file. Expected: FAIL — `:mark_lost` not registered / `kanban_drop?` undefined.

- [ ] **Step 3: Add the `kanban_drop` flag to the Action base**

```ruby
# lib/plutonium/action/base.rb — in initialize, accept and store the flag
# alongside record_action/collection_record_action:
@kanban_drop = opts.fetch(:kanban_drop, false)   # match the surrounding option-reading style
# and add the reader near record_action?:
def kanban_drop? = @kanban_drop
```

Thread `kanban_drop:` through `Action::Interactive::Factory.create` (it already splats `**opts` to the action — confirm and, if it whitelists keys, add `:kanban_drop`).

- [ ] **Step 4: Register drop_interactions in the kanban compile block**

```ruby
# lib/plutonium/definition/index_views.rb — inside kanban(&block),
# after the existing `board.columns.each { |col| col.actions.each … }` loop:
board.columns.each do |col|
  next unless col.drop_interaction?
  action(
    col.drop_interaction_key,
    interaction: col.drop_interaction,
    record_action: true,
    kanban_drop: true
  )
end
```

- [ ] **Step 5: Exclude `kanban_drop?` actions from toolbars**

Find where record/collection actions are filtered for display (grep `record_action?` / `collection_record_action?` in `lib/plutonium/ui/` and `lib/plutonium/resource/`). Add `&& !action.kanban_drop?` to those display filters. Add an assertion in the test that the show/row action set excludes `:mark_lost`.

- [ ] **Step 6: Run tests**

Run the index_views test + `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/action/base_test.rb` (if present). Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/plutonium/definition/index_views.rb lib/plutonium/action/ test/
git commit -m "feat(kanban): register drop_interaction as hidden record action"
```

---

### Task 2: Add the `GET kanban_move_form` member route

**Goal:** A member route that renders the drop interaction's modal form for a pending drop.

**Files:**
- Modify: `lib/plutonium/routing/mapper_extensions.rb:148-155`
- Test: `test/plutonium/routing/…` (nearest routing test) or assert via an integration test in Task 4.

**Acceptance Criteria:**
- [ ] `GET <member>/kanban_move_form` routes to `kanban_actions#kanban_move_form`, named `kanban_move_form`.
- [ ] Existing `POST kanban_move` unchanged.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/dummy_routes_test.rb` (or `rails routes | grep kanban` in the dummy app).

**Steps:**

- [ ] **Step 1: Add the route**

```ruby
# lib/plutonium/routing/mapper_extensions.rb — in define_member_interactive_actions,
# next to the existing kanban_move POST (line 154):
get "kanban_move_form", action: :kanban_move_form, as: :kanban_move_form
post "kanban_move", action: :kanban_move, as: :kanban_move
```

- [ ] **Step 2: Verify routing**

Run in the dummy app: `cd test/dummy && bin/rails routes | grep kanban_move`
Expected: both `kanban_move_form` (GET) and `kanban_move` (POST) present for kanban resources.

- [ ] **Step 3: Commit**

```bash
git add lib/plutonium/routing/mapper_extensions.rb
git commit -m "feat(kanban): add kanban_move_form member route"
```

---

### Task 3: `kanban_move_form` GET — render the interaction modal posting to `kanban_move`

**Goal:** Build the drop interaction as a record action and render its form inside the remote modal, with the form action set to `kanban_move` and the move params (`from_column`, `to_column`, `to_index`) as hidden fields.

**Files:**
- Modify: `lib/plutonium/resource/controllers/kanban_actions.rb` (add `kanban_move_form` public action + helpers)
- Create: `app/views/plutonium/resource/kanban_move_form.html.erb` (confirm the resource views dir with `find app -path '*resource*' -name 'interactive_record_action*'`; co-locate the new template there)
- Test: covered by Task 4 integration test (GET assertions).

**Acceptance Criteria:**
- [ ] `GET kanban_move_form?to_column=lost&from_column=doing&to_index=0` on a card renders a modal containing the interaction's inputs (e.g. a `reason` field).
- [ ] The rendered `<form>` posts to the `kanban_move` path and carries hidden `from_column`, `to_column`, `to_index`.
- [ ] A column with no `drop_interaction` → `head :unprocessable_content` (the client should never call it for such columns, but guard anyway).
- [ ] Authorization: the request runs `authorize_current! record, to: :<drop_interaction_key>?` and 403s when denied.

**Verify:** Task 4's integration test `test_kanban_move_form_renders_interaction_modal`.

**Steps:**

- [ ] **Step 1: Add `kanban_move_form` to KanbanActions**

```ruby
# lib/plutonium/resource/controllers/kanban_actions.rb
# GET <member>/kanban_move_form?from_column=&to_column=&to_index=
def kanban_move_form
  record = kanban_base_relation.find(params[:id])
  to = kanban_column_for(params[:to_column])
  unless to&.drop_interaction?
    head :unprocessable_content
    return
  end
  # Authorize the specific transition (layered on kanban_move? at commit time).
  authorize_current! record, to: :"#{to.drop_interaction_key}?"

  @interaction = to.drop_interaction.new(view_context:)
  @interaction.resource = record
  @kanban_move_params = {
    from_column: params[:from_column],
    to_column: params[:to_column],
    to_index: params[:to_index]
  }
  render :kanban_move_form, formats: [:html], **modal_render_options
end

private

# Resolve a column by key string against the current board (shared by
# kanban_move_form and kanban_move).
def kanban_column_for(key)
  columns = Plutonium::Kanban::Grouping.resolve_columns(current_kanban_board, kanban_context)
  columns.find { |c| c.key.to_s == key.to_s }
end
```

`modal_render_options` and `authorize_current!` are already available (the controller includes `InteractiveActions`). Confirm `KanbanActions` is included after `InteractiveActions`, or reference `Plutonium::REMOTE_MODAL_FRAME` chrome directly in the view.

- [ ] **Step 2: Create the modal view**

```erb
<%# app/views/plutonium/resource/kanban_move_form.html.erb %>
<%# Mirrors interactive_record_action.html.erb chrome, but posts to kanban_move
    and carries the move params so the commit is a single atomic request. %>
<%= turbo_frame_tag Plutonium::REMOTE_MODAL_FRAME do %>
  <%= render "plutonium/modal", title: @interaction.class.label do %>
    <%= form_with url: resource_url_for(resource_record!, action: :kanban_move),
                  method: :post,
                  data: { turbo_frame: "_top" } do |f| %>
      <% @kanban_move_params.each do |k, v| %>
        <%= f.hidden_field k, value: v %>
      <% end %>
      <%= render @interaction.build_form %>
      <%= f.submit @interaction.class.label %>
    <% end %>
  <% end %>
<% end %>
```

Confirm the exact modal partial + form component used by `interactive_record_action.html.erb` (read it first) and match it — reuse the same `@interaction.build_form` and submit styling so this modal is visually identical to a normal record-action modal. Confirm `resource_url_for(record, action: :kanban_move)` produces the member `kanban_move` path; if not, build it via the named route helper `resource_url_for` supports.

- [ ] **Step 3: Commit**

```bash
git add lib/plutonium/resource/controllers/kanban_actions.rb app/views/plutonium/resource/kanban_move_form.html.erb
git commit -m "feat(kanban): render drop interaction modal via kanban_move_form"
```

---

### Task 4: `kanban_move` POST — atomic interaction + on_drop + reposition

**Goal:** When the destination column has a `drop_interaction`, commit the interaction and the move in one transaction: authorize the transition, run `on_drop` (membership), run the interaction (extras), reposition. Interaction failure rolls back and re-renders the modal at 422; success returns column Turbo Streams (which also closes the modal).

**Files:**
- Modify: `lib/plutonium/resource/controllers/kanban_actions.rb:57-167`
- Test: `test/integration/**/kanban_drop_interaction_test.rb` (new)

**Acceptance Criteria:**
- [ ] Dropping onto a drop-interaction column with valid input persists `on_drop`'s membership change, the interaction's extras (e.g. `lost_reason`), and repositions — all committed together.
- [ ] Interaction validation failure (blank `reason`): nothing persists (membership unchanged), response is 422 re-rendering the modal with the error.
- [ ] Transition authorization: `authorize_current! record, to: :<key>?` runs; denial → 403 and no writes.
- [ ] Move guards (`accepts`/`locked`/`wip`) are checked before the interaction runs and still snap-back-toast via `render_kanban_rejection`.
- [ ] Plain columns (no `drop_interaction`) behave exactly as before (existing kanban_move tests still pass).
- [ ] Quick-add seed path (`kanban_column_on_drop_seed`) is unaffected — still uses `on_drop`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/**/kanban_drop_interaction_test.rb` and the existing kanban move test file both green.

**Steps:**

- [ ] **Step 1: Write the failing integration test**

```ruby
# test/integration/<portal>/kanban_drop_interaction_test.rb
require "test_helper"

class KanbanDropInteractionTest < ActionDispatch::IntegrationTest
  # setup: sign in, seed a card in the "doing" column of a resource whose
  # definition declares column :lost, drop_interaction: MarkLostInteraction.

  test "commits interaction extras + membership + position atomically" do
    post kanban_move_path(card),
      params: { from_column: "doing", to_column: "lost", to_index: 0,
                interaction: { reason: "budget cut" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    card.reload
    assert_equal "lost", card.status
    assert_equal "budget cut", card.lost_reason
  end

  test "blank reason rolls back and re-renders modal at 422" do
    post kanban_move_path(card),
      params: { from_column: "doing", to_column: "lost", to_index: 0,
                interaction: { reason: "" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :unprocessable_content
    card.reload
    assert_equal "doing", card.status          # membership NOT changed
    assert_nil card.lost_reason
    assert_match "can't be blank", @response.body
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — the interaction never runs (current `kanban_move` ignores `drop_interaction`); reason not persisted, no 422 modal.

- [ ] **Step 3: Branch `kanban_move` on `drop_interaction`**

Refactor the existing transaction (`kanban_actions.rb:111-144`) so the interaction runs inside it. After the existing guard checks (accepts/locked/wip stay unchanged and BEFORE this block), add:

```ruby
outcome = nil
ActiveRecord::Base.transaction do
  # 1. Membership write (unchanged on_drop dispatch).
  if to.on_drop.is_a?(Symbol)
    record.public_send(to.on_drop)
  elsif to.on_drop
    kanban_context.instance_exec(record, &to.on_drop)
  end
  record.save! if record.changed?

  # 2. Drop interaction (input + authz + errors), same record instance.
  if to.drop_interaction?
    authorize_current! record, to: :"#{to.drop_interaction_key}?"
    interaction = to.drop_interaction.new(view_context:)
    interaction.attributes = kanban_interaction_params(to).merge(resource: record)
    outcome = interaction.call
    if outcome.failure?
      @interaction = interaction
      @kanban_move_params = params.slice(:from_column, :to_column, :to_index).to_unsafe_h
      raise ActiveRecord::Rollback
    end
  end

  # 3. Reposition (unchanged).
  board.position_config.reposition!(
    record:, column: to.key, prev_record:, next_record:, index: to_index
  )
  record.save! if record.changed?
end

# Interaction failed → re-render the modal with errors (transaction rolled back).
if to.drop_interaction? && outcome&.failure?
  return render :kanban_move_form, formats: [:html], **modal_render_options,
    status: :unprocessable_content
end
```

Add the params helper (reuses the interactive-action extraction so structured inputs / choices work identically):

```ruby
# Extract the submitted interaction params for a drop interaction. Mirrors
# InteractiveActions#interaction_params but keyed off the column's interaction.
def kanban_interaction_params(column)
  action_key = column.drop_interaction_key
  params[:interaction] ? params.require(:interaction).permit!.to_h : {}
  # If structured inputs are used, swap this for the shared extract_input
  # pipeline keyed on column.drop_interaction (see submitted_interaction_params).
end
```

> Prefer routing through the existing `submitted_interaction_params` machinery if the interaction uses `structured_input`/`choices:` — read `interactive_actions.rb:244-280` and reuse `build_form(instance).extract_input(...)` rather than a naive `permit!`. Keep the naive form only if the drop interactions in scope use plain scalar inputs.

- [ ] **Step 4: Keep the success response as-is**

The existing `respond_to { format.turbo_stream { … column updates … } }` block already re-renders the from/to column frames. Because the modal form posts with `data-turbo-frame="_top"`, the returned Turbo Streams replace the columns and the modal frame is left empty/closed by the stream. Confirm the modal actually dismisses on success in Task 8's manual drive; if it lingers, append `turbo_stream.update(Plutonium::REMOTE_MODAL_FRAME, "")` to the success streams.

- [ ] **Step 5: Run tests**

Run the new integration test AND the existing kanban move test file. Expected: both PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/resource/controllers/kanban_actions.rb test/integration/
git commit -m "feat(kanban): commit drop interaction + move atomically in kanban_move"
```

---

### Task 5: Emit `data-kanban-drop-*` on drop-interaction columns

**Goal:** The column component advertises, in the DOM, that a column requires the interaction modal on drop, and provides the form URL template.

**Files:**
- Modify: `lib/plutonium/ui/kanban/column.rb`
- Modify: `lib/plutonium/resource/controllers/kanban_actions.rb` `render_kanban_column_html` (pass the form URL template into the component)
- Test: `test/integration/**/kanban_dom_contract_test.rb` (the file the user has open — extend it)

**Acceptance Criteria:**
- [ ] A column with `drop_interaction` renders `data-kanban-drop-interaction="true"` on its `[data-kanban-col]` wrapper.
- [ ] It also renders `data-kanban-drop-form-url-template` = the `kanban_move_form` path with an `__ID__` placeholder (mirroring the existing `move-url-template`).
- [ ] Plain columns render neither attribute.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/integration/**/kanban_dom_contract_test.rb`

**Steps:**

- [ ] **Step 1: Extend the DOM-contract test**

```ruby
test "drop-interaction column advertises the modal drop contract" do
  # render a board whose :lost column has drop_interaction
  assert_select "[data-kanban-col='lost'][data-kanban-drop-interaction='true']"
  assert_select "[data-kanban-col='lost'][data-kanban-drop-form-url-template*='__ID__']"
  assert_select "[data-kanban-col='todo']:not([data-kanban-drop-interaction])"
end
```

- [ ] **Step 2: Pass the form URL template into the component**

In `render_kanban_column_html` (`kanban_actions.rb:301-313`), compute and pass:

```ruby
drop_form_url_template: (column.drop_interaction? ?
  resource_url_for(resource_class, action: :kanban_move_form).sub("kanban_move_form", "__ID__/kanban_move_form") :
  nil),
```

Verify the exact shape of the member form URL and build the `__ID__` template the same way the board builds `move-url-template` (grep `move_url_template` / `__ID__` in `lib/plutonium/ui/kanban/`).

- [ ] **Step 3: Render the attributes in the column component**

```ruby
# lib/plutonium/ui/kanban/column.rb — on the [data-kanban-col] wrapper div,
# add to its attribute hash:
data: {
  kanban_col: column.key,
  # ...existing accepts/locked/default-collapsed...
  **(column.drop_interaction? ? {
    kanban_drop_interaction: "true",
    kanban_drop_form_url_template: @drop_form_url_template
  } : {})
}
```

Add the `drop_form_url_template:` keyword to the component's `initialize` and store `@drop_form_url_template`.

- [ ] **Step 4: Run the test**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/ui/kanban/column.rb lib/plutonium/resource/controllers/kanban_actions.rb test/
git commit -m "feat(kanban): advertise drop interaction contract in column DOM"
```

---

### Task 6: Stimulus — open the modal on drop, hold pending, snap back on cancel

**Goal:** On a drop into a `data-kanban-drop-interaction` column, the controller navigates the remote-modal frame to the `kanban_move_form` URL (carrying the move params) instead of firing the move POST; the card stays visually pending; canceling/closing the modal without success snaps it back.

**Files:**
- Modify: `src/js/controllers/kanban_controller.js:430-487` (`#onDrop`)
- Build: `yarn build` → regenerates `app/assets/plutonium*.js`
- Test: system test in Task 8 (JS behavior is driven there).

**Acceptance Criteria:**
- [ ] Dropping into a drop-interaction column opens the modal (frame `src` set to the form URL with `from_column`/`to_column`/`to_index` in the query), no move POST fires yet.
- [ ] Successful modal submit → columns re-render via the returned streams (existing path), pending state cleared.
- [ ] Modal dismissed without success → source column reloaded (snap-back), pending state cleared.
- [ ] Plain columns keep the existing direct-POST behavior byte-for-byte.

**Verify:** `yarn build` succeeds; Task 8 system test drives it.

**Steps:**

- [ ] **Step 1: Branch `#onDrop` on the drop-interaction contract**

```js
// src/js/controllers/kanban_controller.js — inside #onDrop, after computing
// recordId / fromColumn / toColumn / toIndex, before the fetch():
const colWrapper = column.closest("[data-kanban-col]")
if (colWrapper?.dataset.kanbanDropInteraction === "true") {
  return this.#openDropInteraction(colWrapper, { recordId, fromColumn, toColumn, toIndex })
}
// ...existing direct fetch(url, POST { from_column, to_column, to_index }) unchanged...
```

- [ ] **Step 2: Add the modal-opening + pending/snap-back handler**

```js
// Opens the drop interaction's modal by pointing the remote-modal frame at the
// kanban_move_form URL. The card is left where the user dropped it (pending);
// the modal's Turbo-Stream response re-renders the columns on success. If the
// modal closes without a successful commit, reload the source column to snap
// the card back.
#openDropInteraction(colWrapper, { recordId, fromColumn, toColumn, toIndex }) {
  const tmpl = colWrapper.dataset.kanbanDropFormUrlTemplate
  const params = new URLSearchParams({ from_column: fromColumn, to_column: toColumn, to_index: toIndex })
  const src = `${tmpl.replace("__ID__", recordId)}?${params.toString()}`

  const frame = document.getElementById("remote_modal")   // confirm Plutonium::REMOTE_MODAL_FRAME id
  if (!frame) return
  this.pendingSnapBackColumn = fromColumn

  // If the modal frame empties (closed) without a move stream having landed,
  // snap the source column back.
  const onFrameLoad = () => {
    if (!frame.innerHTML.trim() && this.pendingSnapBackColumn) this.#reloadColumn(this.pendingSnapBackColumn)
  }
  frame.addEventListener("turbo:frame-load", onFrameLoad, { once: true })
  frame.src = src
}

#reloadColumn(key) {
  const frame = this.element.querySelector(`turbo-frame[data-kanban-col-frame='${key}']`)
  if (frame) frame.src = this.#columnFrameSrc(key)
  this.pendingSnapBackColumn = null
}
```

Clear `pendingSnapBackColumn` in `#onBeforeStreamRender` (a successful move stream landed → no snap-back needed). Confirm the actual remote-modal frame id/selector from `Plutonium::REMOTE_MODAL_FRAME` and the layout; adjust `getElementById` accordingly. Keep this handler minimal — the server owns all state; the controller only decides *reload source column* vs *let the move stream render*.

- [ ] **Step 3: Build assets**

Run: `yarn build`
Expected: `app/assets/plutonium.js` (+ min + map) regenerated, no build errors.

- [ ] **Step 4: Commit**

```bash
git add src/js/controllers/kanban_controller.js app/assets/plutonium*.js app/assets/plutonium*.map
git commit -m "feat(kanban): open drop interaction modal with pending/snap-back"
```

---

### Task 7: Documentation + skill

**Goal:** Document `drop_interaction` in the guide, DSL reference, and the plutonium-kanban skill, including the two-flow model and the author contract.

**Files:**
- Modify: `docs/guides/kanban.md`
- Modify: `docs/reference/kanban/dsl.md`
- Modify: `.claude/skills/plutonium-kanban/SKILL.md`

**Acceptance Criteria:**
- [ ] Guide has a "Interaction on drop" section with a `column :lost, on_drop:…, drop_interaction: MarkLostInteraction` example and the `MarkLostInteraction` body.
- [ ] The `on_drop:` vs `drop_interaction:` split (move flow vs seed flow), the author contract (interaction owns extras; on_drop owns membership), and the `def mark_lost?` authorization gate are all stated.
- [ ] DSL reference table lists `drop_interaction:` under Column options.
- [ ] Skill `Column options` block + Authorization section mention it.
- [ ] `yarn docs:build` passes (no broken links).

**Verify:** `yarn docs:build`

**Steps:**

- [ ] **Step 1: Write the guide section, DSL row, and skill edits** (prose — mirror the Design contract above). Include the worked example and the `MarkLostInteraction` class.
- [ ] **Step 2: Build docs** — `yarn docs:build`, fix any broken links.
- [ ] **Step 3: Commit**

```bash
git add docs/ .claude/skills/plutonium-kanban/SKILL.md
git commit -m "docs(kanban): document drop_interaction"
```

---

### Task 8: End-to-end drive in the dummy app + system test

**Goal:** Prove the whole flow (drag → modal → reason → atomic commit; blank reason → 422 modal; cancel → snap-back) in the real dummy app and lock it with a system test.

**Files:**
- Modify (via generators only — see memory `feedback_always_use_generators`): a dummy resource + interaction, OR reuse `test/dummy/app/definitions/task_definition.rb` by adding a `:lost` column with `drop_interaction`. Add `lost_reason` via a migration (inline index per CLAUDE.md).
- Create: `test/system/**/kanban_drop_interaction_test.rb`

**Acceptance Criteria:**
- [ ] System test: drag a card to `:lost`, modal opens, submit with reason → card lands in `:lost`, `lost_reason` persisted, modal closed.
- [ ] System test: submit with blank reason → modal shows error, card not moved.
- [ ] System test: open modal, cancel → card snaps back to source column.
- [ ] Manual drive (see memory `reference_driving_dummy_app_browser`): confirm the same three flows in a browser against `test/dummy`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/system/**/kanban_drop_interaction_test.rb` (headless), plus a manual browser drive.

**Steps:**

- [ ] **Step 1: Add the dummy fixture** — migration for `lost_reason` (inline any index in `create_table`/`change_table`), a `MarkLostInteraction`, and the `:lost` column with `drop_interaction:` on the task definition. Add `def mark_lost? = update?` to the task policy.
- [ ] **Step 2: Write the system test** covering the three flows above.
- [ ] **Step 3: Run it headless.** Expected: PASS.
- [ ] **Step 4: Manual browser drive** per the memory note (seed test DB, login alice/password123), confirm modal open/commit/cancel visually.
- [ ] **Step 5: Commit**

```bash
git add test/ test/dummy/
git commit -m "test(kanban): system + dummy coverage for drop_interaction"
```

---

## Self-Review notes

- **Spec coverage:** DSL option (T0), registration/authz (T1), routing (T2), modal GET (T3), atomic commit + failure 422 (T4), DOM contract (T5), Stimulus pending/snap-back (T6), docs (T7), e2e (T8). All design-contract points map to a task.
- **Type consistency:** `drop_interaction_key` derives `:mark_lost`; used identically in T1 registration, T3/T4 authorization (`:"#{key}?"`), and the policy method `def mark_lost?`. `data-kanban-drop-interaction` / `data-kanban-drop-form-url-template` names match between T5 (emit) and T6 (read).
- **Open confirmations flagged inline** (not placeholders — real "verify exact path" steps): the interactive-action view/modal partial to mirror (T3), the `Action::Interactive::Factory` signature (T1), the remote-modal frame id (T6), and whether to route params through `submitted_interaction_params` for structured inputs (T4).
- **Verification requirement scan:** the original prompt requires NO user sign-off → no `requiresUserVerification` task needed.
