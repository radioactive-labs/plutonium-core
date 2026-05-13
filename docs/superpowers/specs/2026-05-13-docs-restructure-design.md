# Docs Restructure & Compaction Design

**Date:** 2026-05-13
**Status:** Draft — awaiting approval

## Problem

Following the skill consolidation (19 → 8 skills, ~37% volume cut), the `docs/` site is misaligned in two ways:

1. **Reference structure** mirrors the OLD skill structure (separate `model/`, `definition/`, `policy/`, `controller/`, `interaction/`, `views/`, `assets/`, `portal/`, `generators/`). It should mirror the new 7 functional areas.
2. **Concept/task split is muddled.** Some "guides" are really concept explanations (e.g. `guides/authorization.md` overlaps `reference/policy/`). Some concepts have NO reference home (auth, tenancy, testing — they live in `guides/` only).

## Goals

**Primary goal: quality.** Volume reduction is incidental.

1. Restructure `reference/` to mirror the 7 functional areas from the skill consolidation — so readers can predict where to look.
2. Establish a clean role split: **guides = task recipes ("how do I X")**, **reference = concept lookup ("what does X do")**. Some duplication is fine when framed as different entry points; tables of options live in ONE place.
3. Improve every page on these axes:
   - **Right place** — concepts in reference, recipes in guides.
   - **Right structure** — 🚨 callouts at top for "you'll regret this" rules; option/decision tables for scannability; decision rules over generic exhortations.
   - **Right content** — keep WHY explanations that help reason about edge cases; cut marketing copy and empty "best practices" exhortations; verify technical accuracy as we go (the skill work caught real bugs — same energy).
4. Light pass on the tutorial — preserve narrative flow; improve clarity where prose is unclear.

## Non-Goals

- Restructuring `getting-started/` navigation (the tutorial arc stays).
- Changing VitePress theme, search provider, or build pipeline.
- Adding new content beyond reorganizing what exists.

## Current state

40 markdown files, ~13,222 lines.

| Area | Files | Notes |
|---|---|---|
| `getting-started/` | 11 | Index + installation + 8-step tutorial. Narrative learning arc. |
| `guides/` | 14 | Task-oriented but inconsistent — some concept-heavy. |
| `reference/` | 16 | Concept-by-concept, mirrors the OLD skill structure. |

## Target reference structure (mirrors 7 skill areas)

```
reference/
├── index.md          ← rewritten overview, links to the 7 areas
├── app/
│   ├── index.md      ← installation, configuration
│   ├── packages.md   ← feature + portal packages
│   ├── portals.md    ← portal engines, mounting, route registration
│   └── generators.md ← full generator catalog
├── resource/
│   ├── index.md      ← overview, the 4 layers
│   ├── model.md      ← `Plutonium::Resource::Record`, has_cents, SGID, routing (merges current model/)
│   ├── definition.md ← field/input/display/column, page chrome (merges current definition/index + fields)
│   ├── query.md      ← search, filters, scopes, sort
│   └── actions.md    ← custom + bulk actions
├── behavior/
│   ├── index.md      ← overview, the controller/policy/interaction trio
│   ├── controllers.md ← hooks, key methods, presentation
│   ├── policies.md   ← actions, permitted attributes, associations, relation_scope
│   └── interactions.md ← structure, outcomes, chaining, URL generation
├── ui/
│   ├── index.md      ← overview
│   ├── pages.md      ← IndexPage/ShowPage/NewPage/EditPage, hooks
│   ├── forms.md      ← field builder, layouts, theming, association inputs (current views/forms.md)
│   ├── displays.md   ← Display class, custom rendering
│   ├── tables.md     ← Table class, customization
│   ├── components.md ← component kit, custom Phlex components
│   ├── layouts.md    ← shell, eject, ResourceLayout
│   └── assets.md     ← Tailwind config, Stimulus, design tokens, .pu-* classes (current assets/)
├── auth/             ← NEW (currently only in guides/)
│   ├── index.md      ← Rodauth overview
│   ├── accounts.md   ← basic, admin, SaaS account types
│   └── profile.md    ← profile resource, SecuritySection
├── tenancy/          ← NEW (currently spread across guides/)
│   ├── index.md      ← overview, three pieces (portal/policy/model)
│   ├── entity-scoping.md ← associated_with, three model shapes
│   ├── nested-resources.md ← parent/child routes, scoping
│   └── invites.md    ← invitation system
└── testing/          ← NEW (currently only in guides/)
    ├── index.md
    ├── crud.md
    ├── policy.md
    ├── nested.md
    ├── portal-access.md
    └── auth-helpers.md
```

### Content migrations

| Current file | Goes to |
|---|---|
| `reference/model/index.md` + `features.md` | `reference/resource/model.md` |
| `reference/definition/index.md` + `fields.md` | `reference/resource/definition.md` |
| `reference/definition/query.md` | `reference/resource/query.md` |
| `reference/definition/actions.md` | `reference/resource/actions.md` |
| `reference/controller/index.md` | `reference/behavior/controllers.md` |
| `reference/policy/index.md` | `reference/behavior/policies.md` |
| `reference/interaction/index.md` | `reference/behavior/interactions.md` |
| `reference/views/index.md` | split → `pages.md`, `displays.md`, `tables.md`, `components.md`, `layouts.md` |
| `reference/views/forms.md` | `reference/ui/forms.md` |
| `reference/assets/index.md` | `reference/ui/assets.md` |
| `reference/portal/index.md` | `reference/app/portals.md` |
| `reference/generators/index.md` | `reference/app/generators.md` |
| `getting-started/installation.md` | concept part → `reference/app/index.md`; task part stays |
| `guides/authentication.md` | concept part → `reference/auth/index.md` + `accounts.md`; recipe stays |
| `guides/user-profile.md` | concept part → `reference/auth/profile.md`; recipe stays |
| `guides/multi-tenancy.md` | concept part → `reference/tenancy/entity-scoping.md`; recipe stays |
| `guides/nested-resources.md` | concept part → `reference/tenancy/nested-resources.md`; recipe stays |
| `guides/user-invites.md` | concept part → `reference/tenancy/invites.md`; recipe stays |
| `guides/testing.md` | concept part → `reference/testing/*`; recipe stays |
| `guides/creating-packages.md` | concept part → `reference/app/packages.md`; recipe stays |

## Guides restructure

Each guide becomes a clean **task recipe**:

- Single goal stated at the top ("Add authentication to your app")
- Numbered step-by-step
- Each step links to the relevant reference page for "why" and "what else"
- No exhaustive option tables (those live in reference)
- ~50-150 lines each, down from ~300-600

Keep the 14 guides at their current paths so external links don't break.

## Editing principles (quality-first)

Not "cut everything"; cut what doesn't earn its keep. Specifically:

**Cut:**
- Marketing copy ("Plutonium is awesome because…").
- Empty "best practices" exhortations ("write clean code", "test your code").
- Content duplicated across pages — one canonical home + cross-link.
- Verbose prose where a 10-line snippet shows the same thing.
- Rails-101 explanations that don't set up a Plutonium twist.

**Keep — and add more of:**
- **WHY explanations** that help readers reason about edge cases.
- **Non-obvious gotchas** — the dangerous-default stuff that bites people.
- **Decision rules** ("use X when you need Y") over generic exhortations.
- **Option / field / DSL tables** — readers scan them, they don't read prose.
- **Inline code examples** that work — copy-pasteable, no `...` stand-ins.
- **🚨 callouts at top of each page** for the "you'll regret this" rules.

**Verify as we go.** The skill work caught real bugs (auto-detection rules, association input behavior, action visibility flags, `views` DSL naming). Same energy here — when prose claims X, check the source.

## Tutorial compaction pass

Same cuts as above, but preserve:

- Step structure (1-8 stays)
- Narrative flow (one step builds on the next)
- Frequent "expected output" / "verify" callouts
- Screenshots and visuals (keep all references)

Target: 10-20% volume reduction without losing pedagogical value.

## VitePress sidebar rewrite

`.vitepress/config.ts` sidebar rewritten for the new structure. Three sidebars:

- `/getting-started/` — unchanged
- `/guides/` — same 14 entries, reorganized into the 7 functional groups
- `/reference/` — new 7-area structure

## Rollout

1. **Pilot one reference area** — pick `reference/resource/` (largest, most-read). Build it from scratch using the merged skills as the template. Get user feedback on shape.
2. **Build out the other 6 areas** — one at a time or in parallel, your call.
3. **Move concept content** from guides into reference. Hollow guides become recipes.
4. **Tutorial compaction pass** — minimal, last.
5. **Rewrite VitePress sidebar** — once all paths exist.
6. **Delete old reference directories** — `model/`, `definition/`, `policy/`, etc. — in one sweep after everything's in place.
7. **Build the site locally** — verify no dead links, search index regenerates cleanly.

## Risks

- **External links break.** GitHub PRs, blog posts, Stack Overflow answers may link to `reference/model/`, `reference/definition/actions`, etc. Mitigation: VitePress supports redirects, OR keep stub pages that redirect via meta refresh. Cheap to add.
- **Guides ↔ reference duplication drifts.** If a recipe and its reference page describe the same option differently, readers get confused. Mitigation: linting (no duplicate DSL/option tables across guide + reference).
- **Volume isn't the metric.** Some pages will get longer (currently underdeveloped topics: tenancy, testing, profile). Some will get shorter. The win is navigability and clarity, not line count.

## Open questions

- Add `.vitepress` redirect configuration for old reference paths? (Recommended: yes, low cost.)
- Should `reference/app/generators.md` be the full catalog or a per-area split? (Recommended: full catalog — it's reference, scannability matters.)
- Are there guides that should be **deleted entirely** because they're 100% concept overlap with reference? (Decide after pilot.)
