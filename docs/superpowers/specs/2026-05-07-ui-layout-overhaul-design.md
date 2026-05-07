# Plutonium UI Layout Overhaul — Design Spec

**Date:** 2026-05-07
**Scope:** Visual + structural redesign of Plutonium's app shell, page header, index/show/form pages. Code-level component refactoring (slot APIs, hook reduction, partial-to-Phlex conversion) is intentionally out of scope here — this spec captures the *target UI* only. A separate refactor pass can re-architect the Phlex internals to deliver this target.

## Goals

1. Modernize the look and feel to match contemporary admin tools (Linear, Stripe Dashboard, Vercel, Plane).
2. Increase information density without sacrificing scannability.
3. Establish a coherent visual vocabulary across all four page types (index / show / form / interactive-action).
4. Leave clean extension points for upcoming features (metadata side panel, view switchers).

## Non-Goals

- Theming / token rebuild (deferred — current `--pu-*` token system stays).
- Component API consolidation (separate effort).
- Mobile-first redesign (mobile must work, but desktop is the optimization target).
- New colors / typography (use existing tokens unless a decision below requires a new one).

---

## 1. App Shell — Icon Rail + Topbar

A narrow icon-only left rail plus a topbar replaces the current expanded sidebar.

**Left rail**
- Width: ~56px, fixed.
- Icon-only nav items with tooltips on hover.
- Top: brand mark / portal switcher.
- Middle: primary nav (resources grouped by section, dividers between groups).
- Bottom: settings, theme toggle.
- Active item: filled background, primary tone.
- Mobile (<lg breakpoint): rail collapses to hamburger drawer.

**Topbar**
- Height: ~48px, sticky.
- Left: breadcrumbs (resource path; replaces in-content breadcrumbs).
- Center: global search input (filled, ~360px max).
- Right: notifications, user menu.

**Removed**
- Current expanded sidebar (240px) — labels now live in tooltips and breadcrumbs.
- In-page breadcrumbs above title — moved to topbar.

---

## 2. Page Header — Stripe-Style

Every page renders a unified header below the topbar.

```
┌────────────────────────────────────────────────────┐
│ Customers                              [Cancel] [Save] │
│ Manage customer accounts and contact details        │
├────────────────────────────────────────────────────┤
│ Overview │ Orders │ Invoices │ Activity            │
└────────────────────────────────────────────────────┘
```

- Title: 18–20px, semibold.
- Description: 13px, muted, optional, sits directly below title.
- Actions: right-aligned at title's vertical level. Primary as filled button, secondary as outline. Overflow into a `⋯` dropdown after 2 visible actions.
- Tabs: connected strip directly under header (no gap), 1px bottom border becomes the active-tab indicator's baseline.

The header is uniform across index / show / form / interactive-action.

---

## 3. Index Page — Hybrid Toolbar + Pills + Column Sort

### Toolbar (single 36-40px row above the table)

Order, left to right:
1. **View switcher** — segmented control (Grid / Cards / Kanban — Cards/Kanban are placeholders for now; only Grid is wired initially).
2. Vertical divider.
3. **Filter** button (popover).
4. **Group** button (popover).
5. Spacer (`flex-grow`).
6. **Search input** — visible, ~220px wide, expands on focus.
7. Vertical divider.
8. **Column config** icon button (`⊞`).
9. **Overflow** icon button (`⋯`) — exports, advanced options.

The "Sort" button is intentionally absent — sort is column-driven (see below).

### Active Filter Strip (below toolbar, only when filters are active)

- Each active filter renders as a removable pill: `<field> <op> <value>` with `✕`.
- After the last pill: `+ Filter` dashed pill that opens the same popover as the toolbar Filter button.
- Right-aligned: result count (e.g., "147 results").

### Table — Column-Header Sort

- Click a column header: sorts asc → desc → none (cycles).
- Shift-click: adds a secondary/tertiary sort (multi-sort).
- Active sort columns show: arrow (↑/↓) + small priority badge (1, 2, 3) when more than one column is active.
- Each header has a `⋯` menu: Sort asc / Sort desc / Clear sort / Group by / Filter by / Hide column.
- Row height: 32px (balanced density). Header height: 32px.
- Selection: leftmost column is a 12px checkbox.

### Bulk Action Bar

- Appears as a 36px strip *replacing* the active-filter strip when ≥1 row is selected.
- Tinted background (primary-50 light / primary-950/30 dark).
- Left: count + "Clear selection".
- After spacer: action buttons (Export, Archive, Delete) — Delete uses danger tone.

### Pagination Footer

- Sticky-ish strip below the table.
- Left: "Showing N–M of Total".
- Right: prev / page indicator / next.

---

## 4. Show Page — Single Column + Tabs

A single content column under the page header. Nested resources render as tabs.

### Structure

```
PageHeader (title, description, actions, tab strip)
└── content
    ├── [Aside slot — empty by default; reserved]
    └── Main column
        ├── Field panel: Details
        ├── Field panel: Address
        └── ...
```

- Field panels: card-styled (1px border, radius-md, white surface) with uppercase 9px section labels.
- Default content max-width: ~960px, centered if rail+topbar leaves wider area.
- Tabs render nested resources (the existing tab strip mechanism).

### Reserved Aside Slot (Future Hook)

The page layout reserves a `render_aside` slot that is empty by default. A future `metadata` DSL on resource definitions will populate this slot:

```ruby
class CustomerDefinition < Plutonium::Resource::Definition
  metadata do
    field :status, badge: true
    field :owner
    field :created_at
  end
end
```

When populated, the aside renders as a 200–240px right side panel with a sticky 16px-padded background-`surface-alt` column. Implementation of the DSL itself is a separate task — this spec only requires the layout to leave room.

---

## 5. Form Page — Centered Narrow + Sticky Footer

For new / edit / interactive-action.

### Structure

```
PageHeader (title, description; no actions in header)
└── content (max-width ~580px, centered)
    ├── Card: Section 1 (uppercase 9px label + fields)
    ├── Card: Section 2
    └── ...
StickyFooter (full width, right-aligned [Cancel] [Save])
```

- Form column max-width: 580px.
- Card-style sections, same chrome as show-page panels.
- Inline validation: errors render as 12px danger text directly under each field. No toasts for field-level errors. Toast/flash only for form-level outcomes.
- Sticky footer: 56px tall, white surface, top border, sticks to viewport bottom when form scrolls.
- Cancel: outline button. Save: primary filled button. Right-aligned.

### Modal Variant

The same form can render in a modal when triggered as a quick-create / quick-edit (e.g., `+ New` from an index toolbar that targets the remote modal frame, or a row-edit action):
- No sticky footer; the modal's own footer bar holds Cancel / Save.
- Internal layout otherwise identical (card sections, inline validation).
- Modal mode (`:centered` vs `:slideover`) is configurable per resource definition — see §7.
- Page-level new/edit URLs always render the full page form (§5); modal rendering is invoked via the modal turbo frame.

---

## 6. Density

**Balanced (Stripe / Vercel-class)** as the framework default.

| Token            | Value         |
|------------------|---------------|
| Table row height | 32px          |
| Body text        | 14px          |
| Section gap      | 16px          |
| Field gap        | 12px          |
| Button (md)      | 32px height, 14px text, 12px horizontal padding |
| Button (sm)      | 28px, 13px, 10px |
| Input height     | 36px (forms), 32px (toolbars) |
| Card padding     | 16px          |
| Page side padding | 24px         |

These values become the canonical scale; spot-deviations are allowed but should be rare.

---

## 7. Modals — Both Modes, Per-Action Opt-In

Two modal modes ship as siblings.

### Default: Centered Dialog
- Max-width 520px, max-height 80vh, centered, dimmed backdrop.
- Header: dialog title + close (✕).
- Body: form / content with internal scroll.
- Footer: 56px strip, right-aligned [Cancel] [Confirm].
- Use cases: short forms, confirmations, most interactive actions.

### Opt-In: Right Slide-Over Panel
- Slides in from right, full height, 480px wide on desktop, full-screen on mobile.
- Header / body / footer same as centered.
- Underlying list visible (dimmed); user keeps context.
### Configuration

**Per interaction** — defaults to `:centered`, opt into `:slideover`:
```ruby
interactive_action :reschedule, modal: :slideover
interactive_action :archive   # implicit modal: :centered
```

**Per resource (for quick-create / quick-edit modals)** — definition declares the mode used when new/edit is rendered through the modal turbo frame:
```ruby
class CustomerDefinition < Plutonium::Resource::Definition
  modal :slideover   # default :centered
end
```

The page-level new/edit URLs always render the full §5 page layout. Whether `+ New` opens a modal or navigates to the page is a per-context call-site choice (e.g., index toolbar can target the modal frame for quick-create; a "Create customer" landing CTA navigates to the full page).

Both modal modes share the same Phlex modal component; only the outer container varies.

---

## 8. Compatibility & Migration Notes

- **`Layout::ResourceLayout`** currently uses Rails partials for `resource_header` / `resource_sidebar`. Conversion to Phlex is implicit in this work — the icon rail and topbar must be Phlex components.
- **`Page::Base` hook explosion** (~12 before/after hooks) — most apps don't use these. The redesign assumes apps that override `render_breadcrumbs` etc. continue to work; new slot APIs are additive. Hook deprecation is a future cleanup.
- **Existing CSS classes** — `.pu-input`, `.pu-btn`, `.pu-card` keep their names; sizes shift to the density table above. Apps that hard-code Tailwind utilities on top will need cosmetic touch-ups but no breakage.
- **Breadcrumbs** — moving from in-page to topbar means `Plutonium::UI::Breadcrumbs` becomes a topbar component. The definition-level `breadcrumbs` toggle stays; "off" means hidden in topbar (or replaced with title only).

---

## 9. Out-of-Scope Followups (referenced, not designed here)

- **Metadata DSL** for show-page side panel (§4).
- **View switcher** wiring beyond Grid (Cards, Kanban) — placeholders in toolbar; implementation deferred.
- **Code-level Phlex refactor** — slot API, hook reduction, asset registry — separate spec.
- **Token / theme rebuild** — separate spec.

---

## 10. Acceptance Checklist

- [ ] Icon rail (56px) replaces expanded sidebar; topbar adds breadcrumbs + search + user.
- [ ] Page header is a single component (`PageHeader`) used by every page type, supporting title / description / actions / tabs.
- [ ] Index page renders the toolbar in the order of §3 with no Sort button.
- [ ] Active filters render as removable pills below the toolbar with a result count.
- [ ] Column headers sort on click (asc/desc/none) with shift-click multi-sort and priority badges.
- [ ] Bulk action bar replaces the filter strip when rows are selected.
- [ ] Show page is single-column with tab strip; an empty aside slot is reserved.
- [ ] Form pages use a 580px centered column with sticky footer; modal variant uses dialog footer.
- [ ] Density tokens (§6) are codified in CSS / Phlex constants and used consistently.
- [ ] Modal component supports both `:centered` (default) and `:slideover` via per-action / per-form opt-in.
