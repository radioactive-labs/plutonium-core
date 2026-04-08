# Plutonium Skills Overhaul — Design

**Date:** 2026-04-08
**Status:** Approved (pending user review of this doc)

## Problem

The current Plutonium skills (`.claude/skills/plutonium-*`) are content-correct but
fail to trigger at the right moments. Concrete failure modes observed in real
sessions:

1. Agents write `relation_scope` overrides without ever loading `plutonium-policy`,
   bypassing `default_relation_scope` and breaking entity scoping.
2. Agents hand-write resource files instead of using `pu:res:scaffold`.
3. Agents miss cross-cutting concerns (multi-tenancy spans 4 skills; nobody reads 4).
4. Greenfield onboarding is one-skill-at-a-time as the agent stumbles into mistakes.
5. The definition concept is split across 3 skills — agents read one and miss the others.

Root cause: skill `description:` fields list **topics** ("authorization, attribute
visibility, relation scoping..."). Agents triage descriptions against **moments**
("I am about to write `relation_scope`"). Topic-based descriptions don't fire.

## Goals

1. Skills get invoked at the *moment* an agent is about to make a relevant decision.
2. The most expensive mistakes live in a fixed 🚨 block at the top of the relevant skill.
3. Cross-cutting concerns (entity scoping especially) are consolidated and discoverable.
4. **Generators are the default path.** Every skill that touches a generator-backed
   concern leads with "use `pu:...`, do not hand-write."
5. **Greenfield onboarding works.** When an agent starts new work, it loads a bundle
   of foundational skills upfront via the index skill.
6. The index skill (`plutonium`) acts as a router AND a greenfield bootstrapper.
7. Critical workflows are checklists; explanation is prose.

## Non-goals

- Not rewriting prose content wholesale — content is mostly correct.
- No telemetry/measurement infrastructure.
- No new code examples beyond what's needed for the 🚨 blocks.
- No skill renames beyond `plutonium-rodauth → plutonium-auth`.

## Final skill set (20 → 17)

### Merges

| New skill | Absorbs | Rationale |
|---|---|---|
| `plutonium-definition` | + `plutonium-definition-actions`, `plutonium-definition-query` | Agents writing a definition need all three; today's split causes "read one, miss two" |
| `plutonium-auth` (renamed from `plutonium-rodauth`) | + `plutonium-profile` | Profile is a thin layer over rodauth, almost never edited independently |
| `plutonium-assets` | + `plutonium-theming` | Both are "configure the frontend toolchain" — Tailwind + Stimulus + tokens are one mental model |

### New skill

| Skill | Purpose |
|---|---|
| `plutonium-entity-scoping` | Consolidates the entity-scoping/multi-tenancy-specific content currently fragmented across `plutonium-model`, `plutonium-policy`, `plutonium-portal`, and `plutonium-invites`. The single source of truth for: `associated_with` resolution, `default_relation_scope` rules, `relation_scope` override safety, entity strategies (path/custom), and the join-table/grandchild model shapes. |

The four source skills retain their general content but defer to
`plutonium-entity-scoping` for tenancy specifics via cross-reference.

### Stays separate

`plutonium`, `plutonium-installation`, `plutonium-create-resource`, `plutonium-model`,
`plutonium-policy`, `plutonium-controller`, `plutonium-interaction`, `plutonium-portal`,
`plutonium-package`, `plutonium-nested-resources`, `plutonium-invites`,
`plutonium-forms`, `plutonium-views`.

**Final count: 17 skills** (20 − 3 merges + 1 new − 1 rename effect = 17).

## Skill template

Every skill follows this fixed shape so agents always know where to look:

```markdown
---
name: plutonium-<topic>
description: Use BEFORE <specific verb/construct>. Also when <secondary trigger>. <one-line scope>.
---

# plutonium-<topic>

## 🚨 Critical (read first)
- **Use generators, not hand-written files.** `pu:<gen>` — never create <X> manually.
- **<Top anti-pattern #1>** — one-liner + why.
- **<Top anti-pattern #2>** — one-liner + why.
- **Related skills you may also need:** [list with one-line reasons]

## When to use this skill
Checklist of decision points / code constructs that should trigger loading this skill.

## Quick checklist  (bootstrap + high-traffic skills only)
Numbered checklist for the most common workflow. Agent can TaskCreate from this.

## <Sections — scaled to topic>
Prose + code examples.

## Gotchas
The full anti-pattern list with explanations.

## See also
Cross-references to related skills.
```

### Template rules

- **Description starts with `Use BEFORE <verb/construct>`** — verbs and code names,
  not topic nouns. This is the single biggest triggering fix.
- **🚨 Critical block is fixed-position** (always right after the H1) and capped at
  ~5 bullets.
- **Generator-first** is in the 🚨 block of every skill where a generator exists.
- **Cross-references in 🚨 are mandatory** — the "Related skills" bullet replaces
  most of the multi-tenancy discoverability problem.
- **TOC at top of merged skills** so agents can jump to a section without reading
  the whole file.

## The index skill (`plutonium`) as router + bootstrapper

```markdown
---
name: plutonium
description: Use BEFORE starting any Plutonium work — new app, new feature, or first edit in an unfamiliar area. Routes you to the right skills and bootstraps greenfield work.
---

# plutonium

## 🚨 Read this first
- Plutonium is generator-driven. Almost every file you'd hand-write has a `pu:*`
  generator. Use it. Hand-written files drift from conventions.
- For greenfield (new app or substantial new feature), load the **bootstrap bundle**
  below before writing any code.
- For targeted edits, use the **router table**.
- For anything touching tenant scoping, load `plutonium-entity-scoping`.

## Greenfield bootstrap bundle
Triggers: installing Plutonium, adding the first resource of a new domain, building
a new portal/package, "set up X from scratch", "build me a Y app".

Load ALL of these before writing code:
1. `plutonium-installation`
2. `plutonium-create-resource`
3. `plutonium-model`
4. `plutonium-policy`
5. `plutonium-entity-scoping`   ← new
6. `plutonium-portal`
7. `plutonium-definition`

## Router (targeted edits)
| About to... | Load |
|---|---|
| Write/edit a model, add associations | `plutonium-model` |
| Scope a model to a tenant, write `associated_with`, deal with multi-tenancy | `plutonium-entity-scoping` |
| Write `relation_scope`, `permitted_attributes`, override a policy | `plutonium-policy` (+ `plutonium-entity-scoping` if scoping) |
| Add fields, search, filters, custom actions to a resource | `plutonium-definition` |
| Customize a controller action, hook, redirect | `plutonium-controller` |
| Encapsulate business logic, multi-step ops | `plutonium-interaction` |
| Build a custom page, panel, table, layout | `plutonium-views` |
| Customize forms, field builders, inputs | `plutonium-forms` |
| Configure Tailwind, Stimulus, design tokens | `plutonium-assets` |
| Set up Rodauth, accounts, profile pages | `plutonium-auth` |
| Set up user invitations / membership | `plutonium-invites` (+ `plutonium-entity-scoping`) |
| Configure parent/child resources, nested routes | `plutonium-nested-resources` |
| Create a portal or feature package | `plutonium-portal` / `plutonium-package` |

## Generator catalog
[Table of `pu:*` generators with one-line purpose + which skill covers it.]
```

## Execution phases

### Phase A — Restructure (mechanical)
1. Merge `plutonium-definition-actions` + `plutonium-definition-query` into
   `plutonium-definition` with TOC + sections.
2. Rename `plutonium-rodauth` → `plutonium-auth`; merge `plutonium-profile` into it.
3. Merge `plutonium-theming` into `plutonium-assets` with TOC + sections.
4. Delete merged source skills.
5. Grep the codebase for references to deleted/renamed skill names; update.

### Phase B — Create `plutonium-entity-scoping`
- Extract entity-scoping content from `plutonium-model`, `plutonium-policy`,
  `plutonium-portal`, `plutonium-invites`.
- Single source of truth for: `associated_with`, `default_relation_scope`,
  `relation_scope` override safety, entity strategies, and the three model shapes
  (direct child, join-table, grandchild) with worked examples.
- Source skills keep general content but link here for tenancy specifics.

### Phase C — Rewrite descriptions (every skill)
- Format: `Use BEFORE <verb/construct>. Also when <secondary>. <scope>.`
- Each calls out specific code constructs.

### Phase D — Add 🚨 Critical block to every skill
- Fixed position (right after H1).
- ~5 bullets max.
- Pull existing anti-patterns from gotchas to the top.

### Phase E — Rewrite `plutonium` index skill
- Bootstrap bundle.
- Router table.
- Generator catalog.

### Phase F — Quick checklists
Add to bootstrap-bundle skills + `plutonium-definition` + `plutonium-entity-scoping`.
Skip for low-traffic skills.

### Phase G — Cross-references
- Every tenancy-touching skill links to `plutonium-entity-scoping`.
- Definition / policy / model get mutual cross-refs.
- Verify bidirectionality.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Merged skills are bigger → more tokens per load | TOC at top, section anchors, router tells agent which section to jump to |
| Renaming `plutonium-rodauth → plutonium-auth` breaks references | Grep + update in Phase A step 5; also update CLAUDE.md if mentioned |
| Description rewrites are subjective | Same pattern for all (`Use BEFORE <verb>`), reviewed for consistency |
| `plutonium-entity-scoping` could become a dumping ground | Strict scope: only entity scoping itself. General model/policy stuff stays in source skills. |
| Source skills' tenancy sections become stubs that drift | Rule: source skill has a 🚨 bullet "for entity scoping, see `plutonium-entity-scoping`" and a one-paragraph teaser, nothing more |

## Out of scope

- New code examples beyond 🚨 blocks and the three model-shape examples in
  `plutonium-entity-scoping`.
- Telemetry / measurement.
- Skill content rewrites beyond what's needed for the new structure.
- Consolidating below 17 skills.

## Success criteria

1. An agent about to write `relation_scope` loads `plutonium-policy` AND
   `plutonium-entity-scoping` from description triggering alone.
2. An agent doing greenfield work loads the bootstrap bundle from a single read of
   `plutonium`.
3. Every skill that has a generator mentions "use the generator" in its 🚨 block.
4. The three model shapes (direct child / join table / grandchild) have worked
   examples in `plutonium-entity-scoping`.
5. No skill description starts with a topic noun list; all start with `Use BEFORE`.
