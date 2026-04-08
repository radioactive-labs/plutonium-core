# Plutonium Skills Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure all Plutonium skills so they trigger at the right moments, surface critical anti-patterns first, consolidate cross-cutting concerns (especially entity scoping), and enable greenfield bootstrap loading.

**Architecture:** Apply a uniform skill template (description rewrite + 🚨 Critical block + checklist + cross-refs) across all 17 final skills. Merge 3 sets of overlapping skills, create one new `plutonium-entity-scoping` skill, and rewrite the `plutonium` index skill as a router + greenfield bootstrapper.

**Tech Stack:** Markdown skill files in `.claude/skills/<name>/SKILL.md`, plus `CLAUDE.md` updates for any references to renamed skills.

**User Verification:** NO — this is a documentation/skill refactor. The user requested the overhaul and approved the design; no human-in-the-loop validation is required by the spec. Final review happens via normal git diff.

**Spec:** `docs/superpowers/specs/2026-04-08-plutonium-skills-overhaul-design.md`

---

## File map

**Skills to delete (after merge):**
- `.claude/skills/plutonium-definition-actions/`
- `.claude/skills/plutonium-definition-query/`
- `.claude/skills/plutonium-profile/`
- `.claude/skills/plutonium-theming/`

**Skills to rename:**
- `.claude/skills/plutonium-rodauth/` → `.claude/skills/plutonium-auth/`

**Skills to create:**
- `.claude/skills/plutonium-entity-scoping/SKILL.md`

**Skills to modify (every remaining skill):**
- All 17 final skills get description rewrite + 🚨 Critical block + cross-refs.

**Other files to check:**
- `CLAUDE.md` (project root) for references to renamed/deleted skills.
- `.claude/skills/*/SKILL.md` for cross-references to renamed/deleted skills.

---

## Conventions used by every task

**Description format (Phase C):**
```
description: Use BEFORE <verb/construct>. Also when <secondary trigger>. <one-line scope>.
```

**🚨 Critical block format (Phase D), inserted directly after the H1:**
```markdown
## 🚨 Critical (read first)
- **Use the generator.** `pu:<gen>` — never hand-write <X>. <one-line why>.
- **<Top anti-pattern #1>** — one-line + why.
- **<Top anti-pattern #2>** — one-line + why.
- **Related skills:** `plutonium-X` (when Y), `plutonium-Z` (when W).
```

Cap at ~5 bullets. Pull anti-patterns from existing Gotchas section.

**Commit cadence:** one commit per task. Commit message format:
`docs(skills): <task summary>`

---

## Task 0: Baseline audit

**Goal:** Capture the current state so later tasks can verify nothing was lost.

**Files:**
- Read: every `.claude/skills/plutonium-*/SKILL.md`
- Create: `/tmp/skills-baseline.txt` (line counts + headers index)

**Acceptance Criteria:**
- [ ] Line count for every current skill recorded
- [ ] List of all H2 headings per skill recorded
- [ ] List of all `## Gotchas` / anti-pattern bullets per skill recorded
- [ ] Identified which skills currently mention entity scoping / `associated_with` / `default_relation_scope` / `relation_scope`

**Verify:** `wc -l /tmp/skills-baseline.txt` → non-zero

**Steps:**

- [ ] **Step 1:** Run `wc -l .claude/skills/plutonium-*/SKILL.md` and save.
- [ ] **Step 2:** For each skill, extract `^## ` headings via Grep.
- [ ] **Step 3:** Grep `.claude/skills/` for `associated_with|default_relation_scope|relation_scope|entity scoping|entity_scope` to find every mention. This list seeds Task 5 (entity-scoping extraction).
- [ ] **Step 4:** Grep `.claude/skills/` and `CLAUDE.md` for `plutonium-rodauth|plutonium-profile|plutonium-theming|plutonium-definition-actions|plutonium-definition-query` to find every cross-reference that will need updating.
- [ ] **Step 5:** Save all findings to `/tmp/skills-baseline.txt`.
- [ ] **Step 6:** No commit (audit only).

---

## Task 1: Merge plutonium-definition trio

**Goal:** Fold `plutonium-definition-actions` and `plutonium-definition-query` into `plutonium-definition` as sections, then delete the source skills.

**Files:**
- Modify: `.claude/skills/plutonium-definition/SKILL.md`
- Delete: `.claude/skills/plutonium-definition-actions/` (whole directory)
- Delete: `.claude/skills/plutonium-definition-query/` (whole directory)

**Acceptance Criteria:**
- [ ] `plutonium-definition/SKILL.md` contains all original content from the three skills, organized into sections: §Fields/Inputs/Displays, §Query (search/filters/scopes), §Actions (custom + bulk).
- [ ] A TOC at the top with anchor links to each section.
- [ ] No content from the deleted skills is lost (verify by H2-heading diff against baseline).
- [ ] `plutonium-definition-actions/` and `plutonium-definition-query/` directories no longer exist.

**Verify:** `ls .claude/skills/ | grep definition` → only `plutonium-definition`

**Steps:**

- [ ] **Step 1:** Read all three current skill files in full.
- [ ] **Step 2:** Plan the new section order. Use this structure:
  ```
  ---
  name: plutonium-definition
  description: <will be rewritten in Phase C — leave existing for now>
  ---

  # Plutonium Definitions

  ## Contents
  - [Fields, Inputs, Displays](#fields-inputs-displays)
  - [Query: Search, Filters, Scopes](#query)
  - [Actions: Custom and Bulk](#actions)
  - [Gotchas](#gotchas)

  <existing plutonium-definition body, retitled as ## Fields, Inputs, Displays>

  ## Query
  <full body of plutonium-definition-query, with H2s demoted to H3>

  ## Actions
  <full body of plutonium-definition-actions, with H2s demoted to H3>

  ## Gotchas
  <merged gotchas from all three>
  ```
- [ ] **Step 3:** Write the merged file via Write.
- [ ] **Step 4:** Delete the two source directories: `rm -rf .claude/skills/plutonium-definition-actions .claude/skills/plutonium-definition-query`
- [ ] **Step 5:** Verify with `ls .claude/skills/ | grep definition`.
- [ ] **Step 6:** Commit: `docs(skills): merge definition-actions and definition-query into plutonium-definition`

---

## Task 2: Merge plutonium-profile into plutonium-rodauth, rename to plutonium-auth

**Goal:** Combine rodauth and profile content into a single `plutonium-auth` skill.

**Files:**
- Modify: `.claude/skills/plutonium-rodauth/SKILL.md` (will be moved)
- Delete: `.claude/skills/plutonium-profile/` (whole directory)
- Rename: `.claude/skills/plutonium-rodauth/` → `.claude/skills/plutonium-auth/`

**Acceptance Criteria:**
- [ ] All content from `plutonium-rodauth` and `plutonium-profile` lives in `.claude/skills/plutonium-auth/SKILL.md`.
- [ ] Sectioned: §Rodauth setup · §Account types · §Profile page.
- [ ] `name:` frontmatter updated to `plutonium-auth`.
- [ ] TOC at top.
- [ ] Old directories no longer exist.

**Verify:** `ls .claude/skills/ | grep -E 'auth|rodauth|profile'` → only `plutonium-auth`

**Steps:**

- [ ] **Step 1:** Read both current skill files.
- [ ] **Step 2:** Construct merged file body with TOC + 3 sections + merged gotchas.
- [ ] **Step 3:** `mv .claude/skills/plutonium-rodauth .claude/skills/plutonium-auth`
- [ ] **Step 4:** Write merged content to `.claude/skills/plutonium-auth/SKILL.md`, updating `name: plutonium-auth` in frontmatter.
- [ ] **Step 5:** `rm -rf .claude/skills/plutonium-profile`
- [ ] **Step 6:** Verify with `ls .claude/skills/`.
- [ ] **Step 7:** Commit: `docs(skills): merge plutonium-profile into plutonium-rodauth, rename to plutonium-auth`

---

## Task 3: Merge plutonium-theming into plutonium-assets

**Goal:** Fold theming content into assets as a section.

**Files:**
- Modify: `.claude/skills/plutonium-assets/SKILL.md`
- Delete: `.claude/skills/plutonium-theming/`

**Acceptance Criteria:**
- [ ] `plutonium-assets/SKILL.md` contains all theming content as §Design tokens / theming.
- [ ] Sectioned: §Tailwind/CSS · §Stimulus registration · §Design tokens & theming.
- [ ] TOC at top.
- [ ] `plutonium-theming/` no longer exists.

**Verify:** `ls .claude/skills/ | grep -E 'assets|theming'` → only `plutonium-assets`

**Steps:**

- [ ] **Step 1:** Read both source files.
- [ ] **Step 2:** Build merged structure with TOC.
- [ ] **Step 3:** Write merged file.
- [ ] **Step 4:** `rm -rf .claude/skills/plutonium-theming`
- [ ] **Step 5:** Verify.
- [ ] **Step 6:** Commit: `docs(skills): merge plutonium-theming into plutonium-assets`

---

## Task 4: Update cross-references to merged/renamed skills

**Goal:** Find and update every reference to the deleted/renamed skills throughout the repo.

**Files:**
- Modify: any file matching the grep results from Task 0 step 4.
- Likely candidates: `CLAUDE.md`, other `.claude/skills/*/SKILL.md`, `docs/`.

**Acceptance Criteria:**
- [ ] No references remain to `plutonium-rodauth`, `plutonium-profile`, `plutonium-theming`, `plutonium-definition-actions`, `plutonium-definition-query`.
- [ ] References point to the new names (`plutonium-auth`, `plutonium-definition`, `plutonium-assets`).

**Verify:**
```bash
grep -r 'plutonium-rodauth\|plutonium-profile\|plutonium-theming\|plutonium-definition-actions\|plutonium-definition-query' .claude/ CLAUDE.md docs/ 2>/dev/null
```
Expected: no output.

**Steps:**

- [ ] **Step 1:** Run the verify grep above.
- [ ] **Step 2:** For each match, Edit the file to update the reference.
- [ ] **Step 3:** Re-run grep until empty.
- [ ] **Step 4:** Commit: `docs(skills): update cross-references after skill merges/renames`

---

## Task 5: Create plutonium-entity-scoping skill

**Goal:** Single source of truth for entity scoping. Extract scoping content from `plutonium-model`, `plutonium-policy`, `plutonium-portal`, `plutonium-invites` and consolidate here. Add worked examples for the three model shapes.

**Files:**
- Create: `.claude/skills/plutonium-entity-scoping/SKILL.md`
- Modify (in Task 8 cross-ref pass, not here): the four source skills get a teaser + link.

**Acceptance Criteria:**
- [ ] Skill exists with the standard template structure.
- [ ] Description: `Use BEFORE writing relation_scope, associated_with, scoping a model to a tenant, or any multi-tenancy work. Also when configuring entity strategies on a portal. The single source of truth for Plutonium entity scoping.`
- [ ] 🚨 Critical block lists: never bypass `default_relation_scope`, always declare `associated_with`, use a generator to scaffold scoped resources.
- [ ] Quick checklist for "scope a new model to a tenant".
- [ ] Sections: §How entity scoping works · §`associated_with` resolution · §`default_relation_scope` and safe `relation_scope` overrides · §Entity strategies (path, custom) · §Three model shapes (worked examples).
- [ ] Three model-shape worked examples: (a) direct child `Comment belongs_to :post belongs_to :tenant`, (b) join table `Membership` linking user/tenant, (c) grandchild `Comment` → `Post` → `Tenant`.
- [ ] Cross-refs to `plutonium-model`, `plutonium-policy`, `plutonium-portal`, `plutonium-invites`.

**Verify:** `cat .claude/skills/plutonium-entity-scoping/SKILL.md | wc -l` → > 100

**Steps:**

- [ ] **Step 1:** Re-read the entity-scoping bits from `plutonium-model`, `plutonium-policy`, `plutonium-portal`, `plutonium-invites` (use the seed list from Task 0 step 3).
- [ ] **Step 2:** Draft the file using the standard skill template.
- [ ] **Step 3:** Write the three model-shape examples. Direct child is the existing `Comment/Post` example; for join-table show a `Membership` model with `belongs_to :user, belongs_to :tenant` and `has_one :tenant, through: :membership` on `User`; for grandchild show `Comment.has_one :tenant, through: :post` and how `associated_with` resolves it.
- [ ] **Step 4:** Write the file.
- [ ] **Step 5:** Verify line count.
- [ ] **Step 6:** Commit: `docs(skills): add plutonium-entity-scoping skill`

---

## Task 6: Rewrite descriptions for all 17 skills

**Goal:** Every skill's `description:` frontmatter follows `Use BEFORE <verb/construct>. Also when <secondary>. <scope>.`

**Files:**
- Modify: frontmatter in all 17 `.claude/skills/plutonium-*/SKILL.md` files.

**Acceptance Criteria:**
- [ ] Every description starts with "Use BEFORE".
- [ ] Each description names at least one specific code construct, generator, or file the agent might be about to touch.
- [ ] No description is a topic-noun list.

**Verify:**
```bash
grep -h '^description:' .claude/skills/plutonium-*/SKILL.md | grep -v 'Use BEFORE\|Use when starting\|Use when'
```
Expected: empty (or only the index skill, which has its own format).

**Steps:**

- [ ] **Step 1:** For each skill, draft new description using this table as a starting point. **The drafts below are starting points — adjust if reading the skill reveals a more specific trigger.**

| Skill | Draft description |
|---|---|
| `plutonium` | `Use BEFORE starting any Plutonium work — new app, new feature, or first edit in an unfamiliar area. Routes you to the right skills and bootstraps greenfield work.` |
| `plutonium-installation` | `Use BEFORE installing Plutonium in a Rails app or running pu:install. Also when configuring initial Plutonium setup. Covers generators, gemfile, and initial config.` |
| `plutonium-create-resource` | `Use BEFORE running pu:res:scaffold or creating any new resource. Also when picking field types for a generator. Covers field syntax and scaffold options.` |
| `plutonium-model` | `Use BEFORE editing a Plutonium resource model, adding associations, has_cents, SGID, or routing helpers. For tenancy, see plutonium-entity-scoping.` |
| `plutonium-policy` | `Use BEFORE writing relation_scope, permitted_attributes, permitted_associations, or any policy override. For tenant-scoped relation_scope, also load plutonium-entity-scoping.` |
| `plutonium-entity-scoping` | (already set in Task 5) |
| `plutonium-controller` | `Use BEFORE overriding a controller action, adding a hook, or changing redirect logic in a Plutonium controller.` |
| `plutonium-interaction` | `Use BEFORE writing an interaction class, encapsulating business logic, or building multi-step operations beyond basic CRUD.` |
| `plutonium-definition` | `Use BEFORE editing a resource definition — adding fields, inputs, displays, search, filters, scopes, custom actions, or bulk actions.` |
| `plutonium-views` | `Use BEFORE building a custom page, panel, table, layout, or Phlex component in Plutonium.` |
| `plutonium-forms` | `Use BEFORE customizing a form template, field builder, or input component in Plutonium.` |
| `plutonium-assets` | `Use BEFORE configuring Tailwind, registering a Stimulus controller, or editing design tokens / theming in a Plutonium app.` |
| `plutonium-auth` | `Use BEFORE configuring Rodauth, account types, login flows, or building a profile / account settings page.` |
| `plutonium-invites` | `Use BEFORE setting up user invitations or entity membership in a multi-tenant Plutonium app. Also load plutonium-entity-scoping.` |
| `plutonium-portal` | `Use BEFORE creating a portal, mounting a portal engine, configuring entity strategies, or routing portal-specific resources.` |
| `plutonium-package` | `Use BEFORE creating a feature package or portal package, or organizing a Plutonium app into modular engines.` |
| `plutonium-nested-resources` | `Use BEFORE configuring parent/child resource relationships, nested routes, or scoped URL generation.` |

- [ ] **Step 2:** For each skill, Edit the `description:` line in the frontmatter.
- [ ] **Step 3:** Run the verify grep.
- [ ] **Step 4:** Commit: `docs(skills): rewrite descriptions to trigger on verbs and constructs`

---

## Task 7: Add 🚨 Critical block to all 17 skills

**Goal:** Every skill gets a fixed-position 🚨 Critical block right after the H1.

**Files:**
- Modify: all 17 `.claude/skills/plutonium-*/SKILL.md` files.

**Acceptance Criteria:**
- [ ] Every skill has `## 🚨 Critical (read first)` as the first H2 after the H1.
- [ ] Each block contains: generator-first bullet (where applicable), 1-2 top anti-patterns pulled from gotchas, and a "Related skills" bullet with 1-3 cross-refs.
- [ ] Cap: ~5 bullets per block.
- [ ] Existing Gotchas sections are kept (not deleted) — top items are duplicated to the 🚨 block.

**Verify:**
```bash
for f in .claude/skills/plutonium-*/SKILL.md; do
  head -30 "$f" | grep -q '🚨 Critical' || echo "MISSING: $f"
done
```
Expected: no output.

**Steps:**

- [ ] **Step 1:** For each skill, read the file and identify (a) does it have a generator? (b) what are the top 1-2 anti-patterns from existing gotchas? (c) which other skills does it relate to?
- [ ] **Step 2:** Write a 🚨 block following the convention. Example for `plutonium-policy`:
  ```markdown
  ## 🚨 Critical (read first)
  - **Use generators.** `pu:res:scaffold` and `pu:res:conn` create policies — never hand-write policy files.
  - **Never bypass `default_relation_scope`.** Overriding `relation_scope` with a raw `where(...)` skips entity scoping and leaks tenant data. Always compose with `super` or use `associated_with`.
  - **Derived actions inherit.** `update?` falls back to `create?` unless overridden — don't duplicate.
  - **Related skills:** `plutonium-entity-scoping` (for tenant-scoped overrides), `plutonium-model` (for `associated_with`), `plutonium-definition` (for `permitted_attributes` location).
  ```
- [ ] **Step 3:** Edit each skill to insert the block after the H1 (before the first existing H2).
- [ ] **Step 4:** Run the verify loop.
- [ ] **Step 5:** Commit: `docs(skills): add 🚨 Critical block to every skill`

---

## Task 8: Add cross-references back to source skills (entity-scoping teasers)

**Goal:** Every skill that previously held entity-scoping content now has a one-paragraph teaser + link to `plutonium-entity-scoping`. Prevents drift and content duplication.

**Files:**
- Modify: `.claude/skills/plutonium-model/SKILL.md`
- Modify: `.claude/skills/plutonium-policy/SKILL.md`
- Modify: `.claude/skills/plutonium-portal/SKILL.md`
- Modify: `.claude/skills/plutonium-invites/SKILL.md`

**Acceptance Criteria:**
- [ ] Each of the four skills has a "## Entity scoping" section (or similar) that contains: a one-paragraph summary of how that skill relates to entity scoping, and an explicit link to `plutonium-entity-scoping` as the authoritative source.
- [ ] The 🚨 block of each of these four skills mentions `plutonium-entity-scoping` in the Related bullet.
- [ ] Long-form scoping content in the source skills is replaced by the teaser + link, OR retained but explicitly marked "see plutonium-entity-scoping for the canonical version".

**Verify:**
```bash
for f in plutonium-model plutonium-policy plutonium-portal plutonium-invites; do
  grep -q 'plutonium-entity-scoping' .claude/skills/$f/SKILL.md || echo "MISSING: $f"
done
```
Expected: no output.

**Steps:**

- [ ] **Step 1:** For each of the four files, find the existing entity-scoping section (using the seed list from Task 0).
- [ ] **Step 2:** Replace it with a teaser paragraph ending in: `> **For entity scoping details, see the [plutonium-entity-scoping](../plutonium-entity-scoping/SKILL.md) skill — it is the single source of truth.**`
- [ ] **Step 3:** Verify the 🚨 block (added in Task 7) already lists `plutonium-entity-scoping` as related; if not, add it.
- [ ] **Step 4:** Run the verify loop.
- [ ] **Step 5:** Commit: `docs(skills): defer entity-scoping content to plutonium-entity-scoping`

---

## Task 9: Add Quick checklist sections to bootstrap + high-traffic skills

**Goal:** The 7 highest-traffic skills get a "## Quick checklist" section so agents can convert them to tasks via TaskCreate.

**Files (7 skills):**
- Modify: `.claude/skills/plutonium-installation/SKILL.md`
- Modify: `.claude/skills/plutonium-create-resource/SKILL.md`
- Modify: `.claude/skills/plutonium-model/SKILL.md`
- Modify: `.claude/skills/plutonium-policy/SKILL.md`
- Modify: `.claude/skills/plutonium-portal/SKILL.md`
- Modify: `.claude/skills/plutonium-definition/SKILL.md`
- Modify: `.claude/skills/plutonium-entity-scoping/SKILL.md`

**Acceptance Criteria:**
- [ ] Each of the 7 skills has a `## Quick checklist` section with a numbered list (5-10 items) describing the most common workflow for that skill.
- [ ] Checklist items are imperative and concrete (e.g., "Run `pu:res:scaffold` with the appropriate field types"), not vague ("Set up the model").
- [ ] Section is placed after 🚨 Critical and before the long-form sections.

**Verify:**
```bash
for f in plutonium-installation plutonium-create-resource plutonium-model plutonium-policy plutonium-portal plutonium-definition plutonium-entity-scoping; do
  grep -q '## Quick checklist' .claude/skills/$f/SKILL.md || echo "MISSING: $f"
done
```
Expected: no output.

**Steps:**

- [ ] **Step 1:** For each of the 7 skills, draft a 5-10 item checklist for "the most common workflow." For example, `plutonium-create-resource`'s checklist would be: 1) Pick a portal/dest, 2) Identify field types, 3) Run `pu:res:scaffold ResourceName field:type ...`, 4) Run migrations, 5) Connect to a portal via `pu:res:conn`, 6) Verify with `bin/rails routes | grep <resource>`, 7) Open the portal route in the browser.
- [ ] **Step 2:** Edit each file to insert the section.
- [ ] **Step 3:** Run the verify loop.
- [ ] **Step 4:** Commit: `docs(skills): add Quick checklist sections to bootstrap and high-traffic skills`

---

## Task 10: Rewrite the `plutonium` index skill as router + bootstrapper

**Goal:** The index skill becomes a router table, a greenfield bootstrap bundle, and a generator catalog.

**Files:**
- Modify: `.claude/skills/plutonium/SKILL.md` (full rewrite)

**Acceptance Criteria:**
- [ ] Description set per Task 6 table.
- [ ] 🚨 block at top with generator-first message and bootstrap pointer.
- [ ] Greenfield bootstrap bundle section listing the 7 foundational skills (installation, create-resource, model, policy, entity-scoping, portal, definition) with explicit triggers.
- [ ] Router table mapping "About to..." actions to the right skill(s).
- [ ] Generator catalog: table of `pu:*` generators with one-line purpose + which skill covers it.
- [ ] Multi-tenancy entries in the router table cross-reference `plutonium-entity-scoping`.

**Verify:**
```bash
grep -c 'plutonium-' .claude/skills/plutonium/SKILL.md
```
Expected: at least 17 (one mention per other skill).

**Steps:**

- [ ] **Step 1:** Read the spec's full `plutonium` index template (Section 4 in the design doc).
- [ ] **Step 2:** Run `bin/rails generate --help 2>&1 | grep '^  pu:'` from `test/dummy/` to enumerate generators. If that fails, list them by reading `lib/generators/pu/`.
- [ ] **Step 3:** Build the generator catalog table.
- [ ] **Step 4:** Write the full new file body following the template in the spec.
- [ ] **Step 5:** Verify with the grep.
- [ ] **Step 6:** Commit: `docs(skills): rewrite plutonium index as router and greenfield bootstrapper`

---

## Task 11: Final verification sweep

**Goal:** Catch any drift, missing pieces, or broken cross-references introduced during the overhaul.

**Files:**
- Read-only checks across `.claude/skills/`.

**Acceptance Criteria:**
- [ ] All 17 expected skills exist; no extras.
- [ ] All 17 skills have a 🚨 block.
- [ ] All 17 skills have a description starting with "Use BEFORE" (or the index's variant).
- [ ] No references to deleted/renamed skills anywhere in `.claude/`, `CLAUDE.md`, or `docs/`.
- [ ] `plutonium-entity-scoping` exists and has the three model-shape examples.
- [ ] `plutonium` index lists all 17 skills somewhere (router table + bootstrap bundle).

**Verify:**
```bash
ls .claude/skills/ | grep -c '^plutonium'      # → 17
grep -L '🚨 Critical' .claude/skills/plutonium-*/SKILL.md   # → empty
grep -L '^description: Use BEFORE\|^description: Use when starting' .claude/skills/plutonium-*/SKILL.md   # → empty
grep -r 'plutonium-rodauth\|plutonium-profile\|plutonium-theming\|plutonium-definition-actions\|plutonium-definition-query' .claude/ CLAUDE.md docs/ 2>/dev/null   # → empty
```

**Steps:**

- [ ] **Step 1:** Run all four verify commands.
- [ ] **Step 2:** Fix any failures inline.
- [ ] **Step 3:** Re-run until all pass.
- [ ] **Step 4:** Commit (only if fixes were made): `docs(skills): final verification fixes for skills overhaul`

---

## Self-review

- Spec coverage: ✓ all 7 phases (A-G) of the spec map to tasks 1-10; Task 0 is the audit; Task 11 is the final sweep.
- Placeholder scan: ✓ no TBDs; descriptions table provides starting points but instructs the implementer to adjust based on reading.
- Type consistency: N/A (no code).
- Verification requirement scan: NO — no user verification required.

