# UI Layout Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the UI layout overhaul per `docs/superpowers/specs/2026-05-07-ui-layout-overhaul-design.md` — icon rail + topbar shell, Stripe-style PageHeader, redesigned index/show/form pages, balanced density tokens, and centered + slideover modals.

**Architecture:** Five phases delivered top-down: density tokens & PageHeader first (foundational), then the new shell, then per-page redesigns, then modals. Each task ends in a committable, working state. Phlex components are the primary unit of work; CSS changes flow through `src/css/components.css` + `tokens.css`. Existing `.pu-*` class names are preserved; values shift.

**Tech Stack:** Ruby 3+, Rails 7/8, Phlex, Tailwind v4, Stimulus, Turbo. Test framework: Minitest with Capybara for system tests.

**User Verification:** NO — the design was validated via brainstorming. Implementation executes against the spec; no in-loop user verification needed during build.

---

## Reference Files (read before starting)

- Spec: `docs/superpowers/specs/2026-05-07-ui-layout-overhaul-design.md`
- Existing layout: `lib/plutonium/ui/layout/{base,sidebar,header,resource_layout}.rb`
- Existing pages: `lib/plutonium/ui/page/{base,index,show,new,edit,interactive_action}.rb`
- Existing PageHeader: `lib/plutonium/ui/page_header.rb`
- Existing breadcrumbs: `lib/plutonium/ui/breadcrumbs.rb`
- Existing CSS: `src/css/{components,tokens}.css`
- Sort logic: `lib/plutonium/resource/query_object.rb:126` (`sort_params_for`)
- Resource definition: `lib/plutonium/resource/definition.rb` (for `modal` DSL addition)
- Interaction: `lib/plutonium/resource/interaction.rb` and `lib/plutonium/interaction/base.rb` (for `modal:` option)

---

## Pre-flight: Asset Build

Every task that edits `src/css/*.css` or `src/js/**/*.js` requires `yarn dev` to be running OR `yarn build` to be run after the change. The dummy app at `test/dummy/` reads from `src/build/` in dev. Mention this once per task that requires it.

---

# Phase 1 — Foundation

### Task 0: Density tokens

**Goal:** Codify the balanced density scale (§6 of spec) so subsequent tasks reference one source of truth.

**Files:**
- Modify: `src/css/tokens.css`
- Modify: `src/css/components.css` (button, input, card sizes)
- Modify: `lib/plutonium/ui/component/tokens.rb` (Phlex-side mirror if used)

**Acceptance Criteria:**
- [ ] `--pu-row-height: 32px`, `--pu-section-gap: 16px`, `--pu-field-gap: 12px`, `--pu-page-padding: 24px` defined in `:root` and `.dark`
- [ ] `.pu-input` height = 36px in forms, 32px in toolbars (introduce `.pu-input-toolbar` modifier)
- [ ] `.pu-btn-md` = 32px height, 14px text; `.pu-btn-sm` = 28px, 13px
- [ ] `.pu-card` padding = 16px
- [ ] No regressions: `bundle exec appraisal rails-8.1 rake test` passes
- [ ] `yarn build` succeeds

**Verify:** `cd test/dummy && yarn build && bundle exec appraisal rails-8.1 ruby -Itest test/system -e ""`

**Steps:**

- [ ] **Step 1:** Add density variables to `src/css/tokens.css` `:root`:

```css
:root {
  /* ... existing tokens ... */
  --pu-row-height: 32px;
  --pu-section-gap: 16px;
  --pu-field-gap: 12px;
  --pu-page-padding: 24px;
}
```

- [ ] **Step 2:** Update `.pu-btn-md` and `.pu-btn-sm` in `src/css/components.css`:

```css
.pu-btn-md { @apply px-3 h-8 text-sm; }
.pu-btn-sm { @apply px-2.5 h-7 text-[13px]; }
.pu-btn-xs { @apply px-2 h-6 text-xs; }
```

- [ ] **Step 3:** Update `.pu-input` and add `.pu-input-toolbar`:

```css
.pu-input {
  /* existing background/border/color */
  @apply w-full px-3 h-9 text-sm focus:outline-none;
}
.pu-input-toolbar { @apply h-8 text-sm; }
```

- [ ] **Step 4:** Update `.pu-card-body` padding to 16px (down from `var(--pu-space-lg)` if larger).
- [ ] **Step 5:** Run `yarn build` and `bundle exec appraisal rails-8.1 rake test`. Expect pass.
- [ ] **Step 6:** Commit:

```bash
git add src/css/tokens.css src/css/components.css lib/plutonium/ui/component/tokens.rb
git commit -m "feat(ui): codify balanced density tokens"
```

---

### Task 1: PageHeader redesign (Stripe-style)

**Goal:** Replace the current `PageHeader` with a tighter, Stripe-style header — title + description + right-aligned actions on one row, tabs strip rendered underneath.

**Files:**
- Modify: `lib/plutonium/ui/page_header.rb`
- Modify: `lib/plutonium/ui/page/base.rb` (call site stays; rendering logic shifts)
- Test: `test/plutonium/ui/page_header_test.rb` (create if missing)

**Acceptance Criteria:**
- [ ] Title is 18-20px (`text-xl font-semibold`), description is 13px (`text-sm`) muted
- [ ] Actions render right-aligned at title vertical level
- [ ] Tabs (when present) render directly below the header as a connected strip
- [ ] No 8px margin-bottom gap between header and tabs
- [ ] `actions: nil` and `description: nil` render gracefully

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/page_header_test.rb -v` → all pass

**Steps:**

- [ ] **Step 1:** Update `lib/plutonium/ui/page_header.rb` `view_template` markup to:

```ruby
def view_template
  div(class: "flex items-start justify-between gap-4 mb-4") do
    div(class: "min-w-0 flex-1") do
      render_title @title if @title
      render_description @description if @description.present?
    end
    render_actions if @actions.any?
  end
end

def render_title(title)
  h1(class: "text-xl font-semibold leading-tight text-[var(--pu-text)] truncate") { title }
end

def render_description(description)
  p(class: "mt-1 text-sm text-[var(--pu-text-muted)]") { description }
end
```

- [ ] **Step 2:** Update `lib/plutonium/ui/page/base.rb` `render_header` so the tab strip renders directly after `PageHeader` with no gap (drop the `mb-8` from header; let tabs sit flush against a `border-b` baseline).
- [ ] **Step 3:** Add/update test cases:
  - title-only renders correctly
  - title + description renders correctly
  - title + description + 2 actions: actions are right-aligned
  - dropdown actions render when secondary actions exist
- [ ] **Step 4:** Run `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/page_header_test.rb -v`. Expect pass.
- [ ] **Step 5:** Manual: boot dummy app (`cd test/dummy && bundle exec rails s`), navigate to `/admin/users` (or any index), confirm header layout. Then `/admin/users/1` confirm tabs render flush below.
- [ ] **Step 6:** Commit: `feat(ui): redesign PageHeader Stripe-style`

---

# Phase 2 — App Shell

### Task 2: IconRail component

**Goal:** New `Plutonium::UI::Layout::IconRail` Phlex component — 56px icon-only nav with tooltips on hover, replacing the expanded `SidebarMenu` for the new shell.

**Files:**
- Create: `lib/plutonium/ui/layout/icon_rail.rb`
- Create: `test/plutonium/ui/layout/icon_rail_test.rb`
- Modify: `src/css/components.css` (add `.pu-icon-rail`, `.pu-icon-rail-item` if needed)

**Acceptance Criteria:**
- [ ] Renders fixed-position aside, `width: 56px`, full-height, `var(--pu-surface)` background, right border
- [ ] Item slots: brand (top), nav items (middle, grouped with dividers), settings/theme (bottom)
- [ ] Each nav item is icon-only with a Tailwind tooltip (group-hover) showing the label
- [ ] Active item: filled primary tone background, primary text
- [ ] Mobile (`<lg`): rail hidden, drawer toggled by topbar hamburger (controller wiring deferred to Task 4)
- [ ] Compatible with `phlexi-menu` items (accepts an Items tree like `SidebarMenu`)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/layout/icon_rail_test.rb -v` → all pass

**Steps:**

- [ ] **Step 1:** Sketch the component structure:

```ruby
module Plutonium
  module UI
    module Layout
      class IconRail < Plutonium::UI::Component::Base
        include Phlexi::Menu::Component

        def view_template
          aside(
            id: "sidebar-navigation",
            data: {controller: "sidebar"},
            class: "fixed top-0 left-0 z-40 h-screen w-14 bg-[var(--pu-surface)] " \
                   "border-r border-[var(--pu-border)] transition-transform " \
                   "-translate-x-full lg:translate-x-0 flex flex-col"
          ) do
            div(class: "py-3 flex flex-col items-center gap-1", data: {sidebar_target: "scroll"}) do
              render_brand
              render_items(@menu.items) if @menu&.items
            end
            div(class: "mt-auto py-3 flex flex-col items-center gap-1") do
              render_footer_items
            end
          end
        end
        # ...
      end
    end
  end
end
```

- [ ] **Step 2:** Implement `render_item_link` to render a single icon (Tabler icon) with a tooltip via:

```ruby
def render_item_link(item, depth)
  a(href: item.url, class: rail_link_classes(item),
    title: item.label,
    aria: {label: item.label}) do
    render item.icon if item.icon
  end
end

def rail_link_classes(item)
  base = "flex items-center justify-center w-10 h-10 rounded-md " \
         "text-[var(--pu-text-muted)] hover:text-[var(--pu-text)] " \
         "hover:bg-[var(--pu-surface-alt)] transition-colors"
  active?(item) ? "#{base} bg-primary-100 text-primary-700 dark:bg-primary-900/40 dark:text-primary-300" : base
end
```

- [ ] **Step 3:** Add `.pu-icon-rail` and `.pu-icon-rail-item` helper classes to `src/css/components.css` if extracting markup is clearer. Otherwise, leave Tailwind-utility-only.
- [ ] **Step 4:** Write tests covering:
  - aside renders at expected width
  - item with `active: true` gets active classes
  - item without icon still renders (label fallback as initials)
- [ ] **Step 5:** `yarn build && bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/layout/icon_rail_test.rb -v`. Expect pass.
- [ ] **Step 6:** Commit: `feat(ui): add IconRail layout component`

---

### Task 3: Topbar component

**Goal:** New `Plutonium::UI::Layout::Topbar` — sticky 48px topbar with breadcrumbs (left), global search (center), user/notif (right). Replaces the legacy `Layout::Header`.

**Files:**
- Create: `lib/plutonium/ui/layout/topbar.rb`
- Modify: `lib/plutonium/ui/breadcrumbs.rb` (slim down for topbar context — no large title)
- Modify: `app/assets` if a new Stimulus controller is needed for the search omnibox (defer if not)
- Test: `test/plutonium/ui/layout/topbar_test.rb`

**Acceptance Criteria:**
- [ ] `nav` element, fixed top, height 48px, full width minus left rail (`left-14` on lg)
- [ ] Slots: `breadcrumbs` (left), `search` (center, max ~360px), `actions` (right — color mode toggle, user menu)
- [ ] Mobile: hamburger button replaces breadcrumbs/center area (toggles `#sidebar-navigation`)
- [ ] Renders nothing or a sensible fallback if breadcrumbs slot empty

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/layout/topbar_test.rb -v`

**Steps:**

- [ ] **Step 1:** Implement Topbar:

```ruby
class Topbar < Plutonium::UI::Component::Base
  include Phlex::Slotable
  slot :breadcrumbs
  slot :search
  slot :action, collection: true

  def view_template
    nav(
      class: "fixed top-0 right-0 left-0 lg:left-14 z-30 h-12 " \
             "bg-[var(--pu-surface)] border-b border-[var(--pu-border)] " \
             "flex items-center gap-3 px-4",
      data: {controller: "resource-header",
             resource_header_sidebar_outlet: "#sidebar-navigation"}
    ) do
      render_hamburger
      render_breadcrumbs_section
      render_search_section
      render_actions_section
    end
  end
  # ...
end
```

- [ ] **Step 2:** Slim `Breadcrumbs` for topbar use — drop large-title duplication; render as compact ` › `-separated path with last segment as the current page label (no link).
- [ ] **Step 3:** Tests:
  - renders nav with expected classes
  - breadcrumb slot renders into left position
  - search slot renders centered with max-width
  - hamburger button toggles correctly (assert `data-action` present)
- [ ] **Step 4:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/layout/topbar_test.rb -v`. Expect pass.
- [ ] **Step 5:** Commit: `feat(ui): add Topbar layout component`

---

### Task 4: Wire ResourceLayout to new shell

**Goal:** Replace `ResourceLayout`'s Rails partials (`resource_header`, `resource_sidebar`) with the Phlex `IconRail` + `Topbar`. Drop the old `Layout::Header` and `Layout::Sidebar` once nothing references them.

**Files:**
- Modify: `lib/plutonium/ui/layout/resource_layout.rb`
- Delete (or deprecate): `lib/plutonium/ui/layout/header.rb`, `lib/plutonium/ui/layout/sidebar.rb`
- Modify: `lib/plutonium/ui/layout/base.rb` (`main_attributes` padding adjusted for 56px rail + 48px topbar)
- Delete (or replace): partial templates `_resource_header.*`, `_resource_sidebar.*` if Phlex-only path
- Update: `test/dummy/` portal config if it references old layouts

**Acceptance Criteria:**
- [ ] `ResourceLayout#render_before_main` renders `IconRail` + `Topbar` Phlex components instead of partials
- [ ] `main_attributes` padding: `pt-12 lg:pl-14 px-6`
- [ ] Booting dummy app and visiting any portal URL shows: 56px rail, 48px topbar, content offset correctly
- [ ] No references to `Layout::Header` or `Layout::Sidebar` remain (or they're deprecated with a notice)
- [ ] System test: at least one existing portal-page system test passes

**Verify:** `bundle exec appraisal rails-8.1 rake test` and manual smoke test in dummy

**Steps:**

- [ ] **Step 1:** Replace `render partial("resource_header")` and `render partial("resource_sidebar")` calls in `resource_layout.rb` with `render IconRail.new(menu: ...)` and `render Topbar.new { |t| ... }`.
- [ ] **Step 2:** Update `main_attributes`:

```ruby
def main_attributes = mix(super, {class: "pt-12 lg:pl-14 px-6 min-h-screen"})
```

- [ ] **Step 3:** Move portal logo/brand/menu data sources from old partials into the new components. Likely a portal-level helper or initializer change.
- [ ] **Step 4:** Delete `lib/plutonium/ui/layout/header.rb` and `lib/plutonium/ui/layout/sidebar.rb` if no callers remain. Otherwise add a deprecation warning and a TODO.
- [ ] **Step 5:** Delete `_resource_header.*` and `_resource_sidebar.*` partials if no longer rendered.
- [ ] **Step 6:** Run full test suite: `bundle exec appraisal rails-8.1 rake test`. Fix breakages.
- [ ] **Step 7:** Manual smoke: `cd test/dummy && bundle exec rails s`, navigate every portal type. Confirm layout renders.
- [ ] **Step 8:** Commit: `refactor(ui): wire ResourceLayout to icon-rail + topbar shell`

---

# Phase 3 — Index Page

### Task 5: Index toolbar

**Goal:** New `Plutonium::UI::Table::Toolbar` Phlex component — view switcher (Grid only initially, Cards/Kanban as placeholders), Filter button (popover), Group button (popover), visible search input, column-config + overflow icon buttons.

**Files:**
- Create: `lib/plutonium/ui/table/components/toolbar.rb`
- Create: `lib/plutonium/ui/table/components/view_switcher.rb`
- Modify: `lib/plutonium/ui/table/resource.rb` (render Toolbar above the table)
- Test: `test/plutonium/ui/table/components/toolbar_test.rb`

**Acceptance Criteria:**
- [ ] Toolbar order (left → right): view switcher, divider, Filter button, Group button, spacer (`flex-grow`), search input, divider, column-config icon, overflow icon
- [ ] Search input shows current `params[:search]` value, submits on enter
- [ ] Filter button click opens existing filter panel as a popover (anchored under button), not a slideout
- [ ] Group button is a placeholder dropdown stub if grouping isn't implemented yet (greyed-out menu items "Group by …")
- [ ] View switcher: Grid is active by default; Cards/Kanban are visible but disabled (with `title="Coming soon"`)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/table/components/toolbar_test.rb -v`

**Steps:**

- [ ] **Step 1:** Implement `ViewSwitcher` as a 3-segment control:

```ruby
class ViewSwitcher < Plutonium::UI::Component::Base
  def initialize(active: :grid)
    @active = active
  end

  def view_template
    div(class: "inline-flex h-8 rounded-md border border-[var(--pu-border)] bg-[var(--pu-surface)] overflow-hidden text-sm") do
      segment(:grid, "Grid")
      segment(:cards, "Cards", disabled: true)
      segment(:kanban, "Kanban", disabled: true)
    end
  end
  # ...
end
```

- [ ] **Step 2:** Implement `Toolbar`:

```ruby
class Toolbar < Plutonium::UI::Component::Base
  def initialize(query:, filters_present:)
    @query = query
    @filters_present = filters_present
  end

  def view_template
    div(class: "flex items-center gap-2 px-4 py-2 border-b border-[var(--pu-border)] bg-[var(--pu-surface-alt)]") do
      render ViewSwitcher.new
      divider
      filter_button
      group_button
      div(class: "flex-1")
      search_input
      divider
      column_config_button
      overflow_button
    end
  end
  # ...
end
```

- [ ] **Step 3:** In `lib/plutonium/ui/table/resource.rb`, render the Toolbar above the existing table markup. Confirm filter-panel-controller still hooks correctly when clicked.
- [ ] **Step 4:** Tests:
  - toolbar renders all elements in expected order
  - search input echoes current search param
  - disabled segments have `disabled` attribute and tooltip
- [ ] **Step 5:** Manual: dummy app index page shows new toolbar; clicking Filter opens existing filter UI as a popover.
- [ ] **Step 6:** Commit: `feat(ui): add index toolbar with view switcher`

---

### Task 6: Active filter pills + result count

**Goal:** Below the toolbar, render a strip showing active filters as removable pills, a `+ Filter` dashed pill, and a right-aligned result count.

**Files:**
- Create: `lib/plutonium/ui/table/components/filter_pills.rb`
- Modify: `lib/plutonium/ui/table/resource.rb` (render pills strip after toolbar)
- Modify: `lib/plutonium/resource/query_object.rb` if a helper for "active filters list" is needed
- Test: `test/plutonium/ui/table/components/filter_pills_test.rb`

**Acceptance Criteria:**
- [ ] Each active filter renders as `<field> <op> <value>` pill with `✕` (links to URL with that filter cleared)
- [ ] `+ Filter` dashed pill opens the same popover as the toolbar Filter button
- [ ] Right-aligned: total record count from pagination ("147 results")
- [ ] Strip is hidden entirely when no filters active and result count is 0 (or render only count)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/table/components/filter_pills_test.rb -v`

**Steps:**

- [ ] **Step 1:** Add `query_object#active_filter_descriptions` returning `[{name:, label:, op:, value:, clear_url:}]`.
- [ ] **Step 2:** Implement `FilterPills`:

```ruby
class FilterPills < Plutonium::UI::Component::Base
  def initialize(query:, total_count:)
    @query = query
    @total_count = total_count
  end

  def view_template
    return if @query.active_filter_descriptions.empty? && @total_count.zero?
    div(class: "flex items-center gap-1.5 px-4 py-2 border-b border-[var(--pu-border)] flex-wrap") do
      @query.active_filter_descriptions.each { |f| render_pill(f) }
      render_add_filter_pill
      div(class: "ml-auto text-xs text-[var(--pu-text-muted)]") { "#{@total_count} results" }
    end
  end
  # ...
end
```

- [ ] **Step 3:** Pill style: `h-6 px-2 rounded-full bg-primary-50 border border-primary-200 text-xs text-primary-700 inline-flex items-center gap-1.5`. Add-filter pill: `border-dashed`.
- [ ] **Step 4:** Wire into `lib/plutonium/ui/table/resource.rb` between Toolbar and table.
- [ ] **Step 5:** Tests:
  - empty filters + zero count → renders nothing
  - 2 active filters → 2 pills + add-pill + count
  - clearing a pill: `clear_url` builds correctly via `query.build_url(filter: ...)` reset
- [ ] **Step 6:** Commit: `feat(ui): add active filter pills strip with result count`

---

### Task 7: Column-header sort with priority badges + ⋯ menu

**Goal:** Sort moves into table column headers. Click cycles asc → desc → none. Shift-click adds secondary sort. Active sort columns show ↑/↓ + priority badge (1, 2, …). Per-column `⋯` opens a menu with sort/group/filter/hide options.

**Files:**
- Modify: `lib/plutonium/ui/table/resource.rb` (header cell rendering)
- Modify: `lib/plutonium/ui/table/theme.rb` (header cell classes)
- Modify: `lib/plutonium/resource/query_object.rb` — `sort_params_for` returns `{url:, reset_url:, position:, direction:, multi_url:}` where `multi_url` is the shift-click target (preserves other sorts).
- Modify: existing sort-toggle Stimulus controller if any, or wire shift-click via JS
- Test: `test/plutonium/resource/query_object_test.rb`, `test/plutonium/ui/table/resource_test.rb`

**Acceptance Criteria:**
- [ ] Plain click navigates to `sort_params[:url]` (resets other sorts, sets this column)
- [ ] Shift-click navigates to `sort_params[:multi_url]` (preserves other sorts, toggles this column's direction)
- [ ] Active sort column shows ↑/↓ icon and priority badge
- [ ] Priority badge hidden when only one column is sorted
- [ ] `⋯` button per column reveals menu with: Sort asc, Sort desc, Clear sort, Group by …, Filter by …, Hide column
- [ ] Hide column persists per-user (use existing column-config mechanism if present, or `localStorage` via Stimulus)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium -v`

**Steps:**

- [ ] **Step 1:** Update `lib/plutonium/resource/query_object.rb` `sort_params_for` to also build `multi_url` (preserves all other current sorts, toggles this one):

```ruby
def sort_params_for(name)
  return unless sort_definitions[name]
  {
    url: build_url(sort: name, replace: true),
    multi_url: build_url(sort: name),
    reset_url: build_url(sort: name, reset: true),
    position: selected_sort_fields.index(name.to_s),
    direction: selected_sort_directions[name]
  }
end
```

(Implementation of `replace: true` requires updating `build_url`/sort param parsing — sort is appended to existing list normally; `replace: true` discards prior sorts.)

- [ ] **Step 2:** Update header cell rendering in `lib/plutonium/ui/table/resource.rb` to:

```ruby
def render_sort_header(column, sort_params)
  th(class: "...") do
    a(href: sort_params[:url],
      data: {action: "click->table#headerClick"},
      data_multi_href: sort_params[:multi_url],
      class: "flex items-center gap-1 cursor-pointer") do
      span { column.label }
      render_sort_indicator(sort_params)
      render_column_menu_trigger(column)
    end
  end
end
```

- [ ] **Step 3:** Add Stimulus controller `table_controller.js` (or extend existing) to handle shift-click → use `data-multi-href`:

```javascript
headerClick(event) {
  if (event.shiftKey) {
    event.preventDefault();
    const url = event.currentTarget.dataset.multiHref;
    if (url) Turbo.visit(url);
  }
}
```

- [ ] **Step 4:** Implement priority badge — show only when `selected_sort_fields.size > 1`.
- [ ] **Step 5:** Implement column `⋯` menu (Phlex component or existing dropdown). Items navigate to URL fragments: sort asc/desc/clear use `sort_params`, group/filter open the existing popovers pre-filled with the column.
- [ ] **Step 6:** Tests:
  - `sort_params_for(:name)` returns `multi_url` and `url` distinct
  - clicking sets sort to single
  - shift-click adds to multi-sort
- [ ] **Step 7:** Manual: index page, click Name → sorts; shift-click Created → priority badges 1 and 2 appear.
- [ ] **Step 8:** Commit: `feat(ui): column-header sort with shift-click multi-sort`

---

### Task 8: Floating bulk action bar

**Goal:** When ≥1 row is selected, hide the filter pills strip and show a tinted bulk-action bar in its place — selection count, action buttons (Export, Archive, Delete with danger tone), Clear selection.

**Files:**
- Create: `lib/plutonium/ui/table/components/bulk_action_bar.rb`
- Modify: `lib/plutonium/ui/table/resource.rb`
- Modify: `src/js/controllers/bulk_actions_controller.js` (toggle visibility of pills vs bulk bar based on selection count)
- Test: `test/plutonium/ui/table/components/bulk_action_bar_test.rb`

**Acceptance Criteria:**
- [ ] Bulk bar is hidden when 0 selected, visible when ≥1
- [ ] Pills strip is hidden when bulk bar is visible (mutually exclusive)
- [ ] Action buttons come from the resource's `bulk_action`s, sorted by `position`
- [ ] Delete action uses danger tone (red border, red text)
- [ ] "Clear selection" button deselects all and re-shows pills strip
- [ ] Background: `bg-primary-50 dark:bg-primary-950/30`

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/table/components/bulk_action_bar_test.rb -v`

**Steps:**

- [ ] **Step 1:** Implement `BulkActionBar`:

```ruby
class BulkActionBar < Plutonium::UI::Component::Base
  def initialize(actions:)
    @actions = actions
  end

  def view_template
    div(class: "hidden bg-primary-50 dark:bg-primary-950/30 border-b border-[var(--pu-border)] px-4 py-2 flex items-center gap-3",
        data: {bulk_actions_target: "bar"}) do
      span(class: "text-sm font-medium text-primary-700 dark:text-primary-300") {
        plain_text "0 selected"
      }
      div(class: "flex items-center gap-1.5") { @actions.each { |a| render_action_button(a) } }
      div(class: "flex-1")
      button(class: "text-xs text-primary-700 hover:underline",
             data: {action: "bulk-actions#clear"}) { "Clear selection" }
    end
  end
  # ...
end
```

- [ ] **Step 2:** Update `bulk_actions_controller.js` to:
  - track selection count
  - toggle `hidden` class on the bar element AND the pills strip
  - update count text in the bar

- [ ] **Step 3:** Wire bar into `lib/plutonium/ui/table/resource.rb` directly above the table, alongside the pills strip (only one visible at a time).
- [ ] **Step 4:** Tests for component rendering and Stimulus selection count update.
- [ ] **Step 5:** Manual: select row → pills hide, bar shows with count "1 selected"; select more → count updates; click Clear → bar hides.
- [ ] **Step 6:** Commit: `feat(ui): add floating bulk action bar`

---

# Phase 4 — Show + Form Pages

### Task 9: Show page redesign

**Goal:** Show page becomes a single-column layout under PageHeader, with field panels as cards and a reserved (empty) `render_aside` slot for the future metadata DSL.

**Files:**
- Modify: `lib/plutonium/ui/page/show.rb`
- Modify: `lib/plutonium/ui/page/base.rb` (add empty `render_aside` hook)
- Modify: `lib/plutonium/ui/display/resource.rb`
- Modify: `lib/plutonium/ui/panel.rb` (card styling)
- Test: `test/plutonium/ui/page/show_test.rb`

**Acceptance Criteria:**
- [ ] Show page renders single column, max-width ~960px, centered when viewport allows
- [ ] Field panels use `pu-card` chrome with uppercase 9px section labels
- [ ] `render_aside` exists in `Page::Base`, no-op by default; show layout reserves space for it (e.g., grid with `grid-cols-[1fr_240px]` when `aside_present?` else `grid-cols-1`)
- [ ] Tabs render flush against header (Phase 1 work continues to apply)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/page/show_test.rb -v`

**Steps:**

- [ ] **Step 1:** Add `render_aside` no-op to `Page::Base`:

```ruby
def render_aside
  # no-op by default; show page reserves layout slot
end

def aside_present? = false
```

- [ ] **Step 2:** Update `Page::Show`:

```ruby
def render_default_content
  div(class: aside_present? ? "grid grid-cols-1 lg:grid-cols-[1fr_240px] gap-6" : "max-w-[960px] mx-auto") do
    div { render partial("resource_details") }
    aside(class: "hidden lg:block") { render_aside } if aside_present?
  end
end
```

- [ ] **Step 3:** Update panel/section component to render with `pu-card` + uppercase 9px label:

```ruby
section(class: "pu-card p-4 mb-4") do
  div(class: "text-[9px] font-semibold uppercase tracking-wider text-[var(--pu-text-muted)] mb-2") { label }
  # ... fields ...
end
```

- [ ] **Step 4:** Tests covering: layout grid, aside slot empty by default, panel chrome.
- [ ] **Step 5:** Manual: dummy app `/admin/users/1` shows single column with card panels.
- [ ] **Step 6:** Commit: `feat(ui): redesign Show page single-column with reserved aside`

---

### Task 10: Form page redesign

**Goal:** New/edit/interactive-action page renders a 580px centered column with card sections and a sticky footer for Cancel/Save. Inline validation: errors render as 12px danger text directly below each field.

**Files:**
- Modify: `lib/plutonium/ui/page/{new,edit,interactive_action}.rb`
- Modify: `lib/plutonium/ui/form/resource.rb`
- Modify: `lib/plutonium/ui/form/interaction.rb`
- Modify: `lib/plutonium/ui/form/theme.rb` (section card classes)
- Create: `lib/plutonium/ui/form/components/sticky_footer.rb`
- Test: `test/plutonium/ui/form/sticky_footer_test.rb`

**Acceptance Criteria:**
- [ ] Form column max-width 580px, centered (`max-w-[580px] mx-auto`)
- [ ] Field groups render as `pu-card` panels with uppercase 9px labels
- [ ] Sticky footer at viewport bottom: 56px tall, white surface, top border, Cancel + Save right-aligned
- [ ] Inline validation: error text under field, `text-xs text-danger-600 mt-1`; no toasts for field errors
- [ ] Modal context: sticky footer not rendered (modal owns its footer)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/ui/form -v`

**Steps:**

- [ ] **Step 1:** Implement `StickyFooter`:

```ruby
class StickyFooter < Plutonium::UI::Component::Base
  def view_template(&)
    div(class: "fixed bottom-0 left-0 right-0 lg:left-14 z-20 " \
               "h-14 bg-[var(--pu-surface)] border-t border-[var(--pu-border)] " \
               "px-4 flex items-center justify-end gap-2", &)
  end
end
```

- [ ] **Step 2:** Update `Form::Resource` and `Form::Interaction` to wrap content in centered column and emit submit/cancel into `StickyFooter` (skip when `@in_modal`).
- [ ] **Step 3:** Add `@in_modal` initializer kwarg to forms; `Page::InteractiveAction` and remote-modal-rendered new/edit set it `true`.
- [ ] **Step 4:** Update form theme `error_message` to `"text-xs text-danger-600 mt-1"`. Confirm error toasts (flash messages) are unaffected — only field errors style changed.
- [ ] **Step 5:** Adjust page main padding to leave room for sticky footer: `pb-16` on form pages.
- [ ] **Step 6:** Tests:
  - `StickyFooter` renders with expected classes
  - form in non-modal context renders sticky footer
  - form with `in_modal: true` does NOT render sticky footer
- [ ] **Step 7:** Manual: dummy app `/admin/users/new` shows centered form with sticky bottom footer; submit error → inline error under field.
- [ ] **Step 8:** Commit: `feat(ui): redesign form pages with centered column and sticky footer`

---

# Phase 5 — Modals

### Task 11: Slideover modal mode + per-interaction option

**Goal:** Add a slideover modal mode alongside the existing centered modal. Allow interactions to opt in via `interactive_action :name, modal: :slideover`.

**Files:**
- Modify: `lib/plutonium/resource/interactions/options.rb` (or wherever `interactive_action` registers options) — accept `modal:` kwarg
- Modify: existing modal Phlex component (likely `lib/plutonium/ui/component/...` or `app/views/layouts/_remote_modal*`) — split into `centered` and `slideover` outer containers, shared header/body/footer
- Modify: `src/js/controllers/remote_modal_controller.js` — read `data-modal-mode` and apply correct outer classes/animation
- Test: `test/plutonium/interaction/...` for the `modal:` option, plus a system test for slideover rendering

**Acceptance Criteria:**
- [ ] `interactive_action :reschedule, modal: :slideover` stores the mode on the action definition
- [ ] When this action triggers the remote modal, the modal renders as a right slideover (`right-0 top-0 h-full w-[480px]`) instead of centered
- [ ] Defaulted modal mode is `:centered`
- [ ] Slideover animates in from the right (Tailwind transition utilities)
- [ ] Mobile: slideover becomes full-screen

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/interaction -v` and a new system test

**Steps:**

- [ ] **Step 1:** Locate where `interactive_action` registers — extend the option object with `modal: :centered` default and `:slideover` accepted value.
- [ ] **Step 2:** Pass the chosen mode to the modal renderer (likely via a controller assignment to `@modal_mode` or a turbo-stream attribute).
- [ ] **Step 3:** Refactor the modal markup:

```erb
<%# centered (default) %>
<dialog class="fixed inset-0 m-auto max-w-[520px] w-full max-h-[80vh] rounded-lg ..." data-modal-mode="centered">
  ...
</dialog>

<%# slideover %>
<dialog class="fixed top-0 right-0 h-screen w-full sm:w-[480px] m-0 rounded-none ..." data-modal-mode="slideover">
  ...
</dialog>
```

- [ ] **Step 4:** Add CSS transitions for slideover (translate-x-full → translate-x-0 on open).
- [ ] **Step 5:** Add a system test: define an interactive action with `modal: :slideover`, trigger it, assert `[data-modal-mode='slideover']` element is present in DOM.
- [ ] **Step 6:** Commit: `feat(ui): support slideover modal mode for interactions`

---

### Task 12: Per-resource modal declaration

**Goal:** Resource definitions can declare `modal :slideover` to control how new/edit forms render when triggered through the modal turbo frame.

**Files:**
- Modify: `lib/plutonium/resource/definition.rb` (add `modal` class-level DSL with default `:centered`)
- Modify: `lib/plutonium/resource/controllers/crud_actions.rb` (or whichever controller invokes new/edit) — when request targets the remote modal frame, pass `definition.modal_mode` to the layout
- Modify: layout for modal-rendered new/edit forms to read mode from definition
- Test: `test/plutonium/resource/definition_test.rb`, system test for slideover-quick-create

**Acceptance Criteria:**
- [ ] `class CustomerDefinition; modal :slideover; end` is accepted; `current_definition.modal_mode == :slideover`
- [ ] Default value is `:centered`
- [ ] When `+ New` from the index toolbar targets the remote modal frame and the resource declares `modal :slideover`, the modal renders as slideover
- [ ] Page-level (non-modal) new/edit URLs render the §5 page form regardless of declaration

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/resource/definition_test.rb -v` plus a system test

**Steps:**

- [ ] **Step 1:** Add to `lib/plutonium/resource/definition.rb`:

```ruby
class_attribute :modal_mode, default: :centered

def self.modal(mode)
  raise ArgumentError, "modal must be :centered or :slideover" unless [:centered, :slideover].include?(mode)
  self.modal_mode = mode
end
```

- [ ] **Step 2:** Where the remote modal renders new/edit (probably a layout/template that wraps `resource_form`), read `current_definition.modal_mode` and apply mode.
- [ ] **Step 3:** Update the index toolbar `+ New` button to target the remote modal frame (existing behavior; confirm).
- [ ] **Step 4:** Tests:
  - `definition_test.rb`: defining `modal :slideover` sets `modal_mode`; invalid raises
  - system test: `+ New` on a resource with `modal :slideover` opens slideover
- [ ] **Step 5:** Commit: `feat(ui): per-resource modal mode declaration`

---

## Final: Cleanup & Docs

### Task 13: Documentation + changelog

**Goal:** Update Plutonium docs to reflect new UI patterns; add an upgrade note for app developers.

**Files:**
- Modify: `docs/getting-started/*` (any screenshots/snippets that show old UI)
- Modify: `docs/guides/*`
- Create: `docs/guides/ui-overhaul-2026.md` — what changed, what apps need to do
- Update: `.claude/skills/plutonium-views.md` to reference new components
- Update: `CHANGELOG.md`

**Acceptance Criteria:**
- [ ] Upgrade guide explains: replaced sidebar with icon rail; new toolbar; column-header sort; sticky form footer; new modal modes
- [ ] Skill files updated for IconRail, Topbar, Toolbar, FilterPills, BulkActionBar, StickyFooter
- [ ] Changelog entry under unreleased

**Verify:** `yarn docs:build` succeeds; manual scan of docs site

**Steps:**

- [ ] **Step 1:** Write upgrade guide.
- [ ] **Step 2:** Update affected skill files in `.claude/skills/`.
- [ ] **Step 3:** Add changelog entry.
- [ ] **Step 4:** `yarn docs:build`.
- [ ] **Step 5:** Commit: `docs(ui): document UI layout overhaul`

---

## Self-Review Notes

**Spec coverage:**
- §1 Shell → Tasks 2, 3, 4
- §2 PageHeader → Task 1
- §3 Index → Tasks 5, 6, 7, 8
- §4 Show → Task 9
- §5 Form → Task 10
- §6 Density → Task 0
- §7 Modals → Tasks 11, 12
- §8 Compatibility / cleanup → Tasks 4 (drop legacy), 13 (docs)
- §9 Out-of-scope items not implemented (correct, by design)

**User Verification scan:** Spec does not require user-in-the-loop verification — design was validated during brainstorming. NO verification tasks needed.

**Type/name consistency:** `IconRail`, `Topbar`, `Toolbar`, `FilterPills`, `BulkActionBar`, `StickyFooter`, `ViewSwitcher` — used consistently across tasks.

**Phase boundaries are commit-able:** after each phase, the framework is in a working state. Phase 1 alone delivers visible improvement (tighter header + density). Phase 2 swaps the shell. Phase 3 transforms the index page. Phase 4 polishes show/form. Phase 5 adds modal flexibility.
