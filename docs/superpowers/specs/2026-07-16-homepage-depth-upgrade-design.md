# Homepage Depth & Proof Upgrade — Design

**Date:** 2026-07-16
**Status:** Approved
**Scope:** VitePress docs homepage (`docs/index.md` + `docs/.vitepress/theme/components/Home*.vue`)

## Problem

The homepage looks good but undersells the product. Two confirmed weaknesses
(vs Avo/ActiveAdmin/Administrate, Filament/Refine/AdminJS, and Jumpstart/Bullet Train):

1. **Feature depth is hidden.** Wizards, kanban boards, custom/bulk actions, and
   multi-tenancy/nesting barely appear. The surface area reads smaller than it is.
2. **Not enough proof.** Claims outnumber evidence — three CRUD screenshots and one
   asciinema cast carry the whole page.

Constraint: the overall look (design system, section rhythm, dark-terminal aesthetic)
stays. No hosted demo. No new screenshot production — reuse existing guide assets.

## Approved changes

New page order:

```
Hero → Stop writing → Walkthrough → Feature tour (NEW) → Why Plutonium (NEW, merged) → In the box → CTA
```

### 1. `HomeFeatureTour.vue` (new section)

Slots between `HomeWalkthrough` and the merged band.

- **Heading:** "More than CRUD." Sub: "Four features other frameworks make you
  build yourself. All declarative. All policy-aware."
- **Desktop (>768px):** left vertical rail listing the four features, each with a
  one-line hook; right panel shows the selected feature. Selected rail item gets the
  accent left-border treatment (matches `--pu-accent`).
- **Mobile (≤768px):** the rail reflows into an accordion — all four heads always
  visible, one open at a time, same panel content inside.
- **Panel anatomy (each feature):**
  1. File-path caption bar (e.g. `app/definitions/task_definition.rb`)
  2. DSL code snippet, dark terminal styling (`--pu-bg-dark`), syntax-highlighted
  3. Real screenshot below the code, reused from `docs/public/images/guides/`
  4. A one-line "policy-aware" callout: the button/column/step disappears when the
     policy says no
  5. "Read the guide →" link to the relevant guide page

| Rail item | Hook | Snippet | Screenshot | Guide link |
|---|---|---|---|---|
| Kanban boards | drag-drop from one block | `kanban do … end` column DSL (todo/doing/done, `wip:`, `role:`) | `guides/kanban-board.png` | `/guides/kanban` |
| Wizards | multi-step flows, branching | trimmed `CompanyOnboardingWizard` (2 steps + `review` + `execute`) | `guides/wizards-step.png` | `/guides/wizards` |
| Actions & interactions | business logic + auto UI | `action :publish, interaction: PublishPostInteraction` + `def publish? = update? && record.draft?` | `guides/custom-actions-bulk.png` | `/guides/custom-actions` |
| Multi-tenancy & nesting | scoping, invites, nesting | entity-scoping snippet (`scoped_to_entity` / portal strategy) | `guides/multi-tenancy-dashboard.png` | `/guides/multi-tenancy` |

- Interactivity via a small Vue `ref` for the selected feature (desktop rail and
  mobile accordion share state). No new dependencies.
- Note: the wizards guide labels the feature experimental; the tour panel copy should
  not contradict that (avoid "stable", fine to omit the caveat).

### 2. `HomeWhyPlutonium.vue` (new, replaces `HomePillars` + `HomeAudienceSplit`)

One `pu-section--band` section that merges both messages, cutting a full section of
page height:

- **Top:** the four pillar cards in compact form — Convention over configuration /
  It's just Rails / Multi-tenant ready / AI-readable — same icons and card styling
  as today, tighter padding.
- **Bottom:** a two-column footer row inside the same section:
  - "For Rails developers" — existing lede + 2 bullets: "Convention extended to
    CRUD, policies, and portals" and "Generated code lives in your repo — edit anything"
  - "For founders & teams" — existing lede + 2 bullets: "Admin panel, signup, and
    invites on day one" and "Multi-tenant scoping when you need it"
- `HomePillars.vue` and `HomeAudienceSplit.vue` are deleted; `docs/index.md` updated.

### 3. Copy-only weaves (existing components)

- **`HomeHero.vue`:** pillars line gains **Wizards.** and **Kanban.** in the bold list.
- **`HomeStopWriting.vue`:** Plutonium win column gains `+ Actions` (accurate — the
  scaffold ships action wiring).
- **`HomeInTheBox.vue`:** new fourth category row **Workflows** with three links:
  Wizards (`/guides/wizards`), Kanban (`/guides/kanban`), Interactions
  (`/guides/custom-actions` — there is no separate interactions guide).

### 4. Out of scope

- Hosted live demo
- New screenshot/asset production
- Full-spine restructure (each feature as a full-width alternating panel) —
  considered and superseded by the rail-tour + tightened-middle structure
- Credibility signals (testimonials, star counts) and quantified-value claims —
  explicitly not the weak spots being addressed

## Error handling / edge cases

- Screenshots must be referenced with `withBase(...)` like existing components.
- Rail/accordion is progressive: SSR renders the first feature expanded so the
  section is meaningful without JS.
- Accordion heads are `<button>`s with `aria-expanded`; rail follows the existing
  `role="tablist"` pattern used by `HomeCta.vue` pills.

## Testing / verification

- `yarn docs:dev` visual pass at desktop and ≤768px widths (rail ↔ accordion reflow).
- `yarn docs:build` must pass (dead-link check catches wrong guide paths).
- Verify all four screenshots resolve under the site base path in the built output.

## Decisions log

- Tour layout: feature rail (chosen over tabbed showcase) — breadth visible at a glance
- Mobile: accordion (chosen over horizontal pill strip) — same breadth rationale
- Phase 2 pulled forward, resolved as structure A: rail tour + merged middle band
  (chosen over full-spine panels)
