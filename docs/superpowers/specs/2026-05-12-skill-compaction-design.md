# Skill Compaction & Consolidation Design

**Date:** 2026-05-12
**Status:** Approved (pending implementation)

## Problem

The `.claude/skills/` directory currently holds 19 Plutonium skills totaling ~7,846 lines. Several issues:

- Skills are too verbose for a stable-API framework. Plutonium rarely changes shape, so re-explaining concepts has little ROI.
- Several skills are read together for any non-trivial task (e.g. create-resource + model + definition). Loading them separately wastes context.
- Some skills duplicate content (Rails-isms, philosophy preambles, repeated DSL explanations).

Skills are written for **developers using the framework**, not for first-time Rails users. They should read like reference + decision rules, not tutorials.

## Goals

1. Reduce total skill volume by ~45% (target: ~4,150 lines from 7,846).
2. Merge skills that are almost always loaded together.
3. Keep skills self-contained with inline code examples (chosen over linking to `test/dummy`).
4. Preserve high-value reference material (option/DSL/field tables).

## Non-Goals

- Restructuring user-facing `docs/` site.
- Changing the framework API.
- Splitting examples into separate files outside the skill.

## Target Skill Map

From 19 skills to 8:

| New skill | Merges | Est. lines |
|---|---|---|
| `plutonium` | (router, kept) | ~150 |
| `plutonium-app` | installation + portal + package | ~600 |
| `plutonium-resource` | create-resource + model + definition | ~800 |
| `plutonium-behavior` | controller + policy + interaction | ~700 |
| `plutonium-ui` | views + forms + assets | ~700 |
| `plutonium-auth` | (kept, compacted) | ~350 |
| `plutonium-tenancy` | entity-scoping + nested-resources + invites | ~600 |
| `plutonium-testing` | (kept, compacted) | ~250 |

**Total: ~4,150 lines.**

### Rationale per merge

- **plutonium-app** — installation, portal creation, and package creation are the setup arc. Always done together on a new app.
- **plutonium-resource** — model declarations, scaffold options, and definition DSL are the core "build a resource" workflow.
- **plutonium-behavior** — controllers, policies, and interactions form the request/authorization/business-logic layer.
- **plutonium-ui** — views, forms, and assets all touch presentation. Assets covers the toolchain backing both views and forms.
- **plutonium-tenancy** — entity-scoping is the core mechanic; nested-resources and invites are both consumers of that mechanic.
- **plutonium-auth** stays solo at the user's request (rodauth/profile is distinct enough from tenancy/invites).
- **plutonium-testing** stays solo (orthogonal concern, loaded only for test work).

## Compaction Rules

Applied to every skill during merge.

**Cut:**
- Rails/Ruby basics — assume reader knows Rails.
- Philosophy/motivation preambles.
- Duplicated content across merged skills (one canonical location per concept).
- Verbose prose where a 10-line snippet shows the same thing.
- Marketing copy ("Plutonium gives you...").

**Keep:**
- Decision rules ("use X when…, Y when…").
- Non-obvious gotchas and constraints.
- Short canonical inline snippets.
- **Option/field/DSL tables** — high-value reference, kept verbatim.
- Cross-references to other skills via `[[plutonium-resource]]` style links.

## Format per merged skill

1. **Header paragraph** — what this covers + when to load.
2. **Sub-sections per merged topic** — each with: decision rules → minimal inline example → gotchas → tables (where applicable).
3. **Cross-references** at bottom.

## Rollout

1. **Pilot:** `plutonium-resource` first (largest, hardest — biggest signal on whether the template works).
2. **Review pilot together** — adjust template if needed.
3. **Apply pattern** to the remaining merges. One PR per merged skill OR all-in-one (TBD with user).
4. **Update `plutonium` router skill** last — it references the new names.
5. **Delete old skill directories** only after the new one lands.

Skills require a gem release to take effect for users (per `CLAUDE.md`), so this ships as a single release regardless of how PRs are split.

## Risks

- **Loss of granularity for context loading** — a single merged skill loads more tokens even when only one sub-topic is needed. Mitigated by aggressive compaction (loose budget but still much smaller than today's biggest individual skills).
- **Cross-references breaking** — the `plutonium` router skill and any external references must update at the same time as the merge.
- **Drift from `docs/`** — the user-facing docs site may still reference old skill structure; out of scope for this spec but worth noting.

## Open Questions

- Should the merge land as one PR or eight? (Deferred to rollout time.)
- Are there external references to the old skill names (other repos, marketplace listings) that need updating?
