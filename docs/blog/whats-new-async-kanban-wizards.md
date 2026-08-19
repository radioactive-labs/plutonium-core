---
title: "What's new: async interactions, kanban boards, and wizards"
date: 2026-08-19
description: Three features that replace the same detour — dropping out of Plutonium to hand-roll a job, a board, or a multi-step form.
author: Stefan Froelich
tags: [release, async, kanban, wizards]
draft: true
---

# What's new: async interactions, kanban boards, and wizards

<BlogMeta />

Plutonium's pitch is that the boring 80% of an admin app should already exist. For a while there were three obvious holes in that — three places where you'd get most of the way through a feature and then have to drop out of the framework and hand-roll the rest: work that takes too long for a request, a board view, and a form that spans more than one screen.

All three are now closed.

## Async interactions

An interaction is the button-plus-form-plus-outcome in front of an operation. That works right up until the operation doesn't fit in a request — archiving five thousand records, generating a report, or calling a third-party API that takes its time. The old answer was to write the interaction anyway, enqueue a job from `execute`, invent somewhere to store progress, and build a page to show it.

Now you declare the work with `async` and skip all of that:

```ruby
class Blogging::ArchivePosts < ResourceInteraction
  presents label: "Archive", icon: Phlex::TablerIcons::Archive
  attribute :resources          # bulk — perform_on runs once per record
  attribute :reason, :string

  async do
    on_failure :continue        # :halt (default) | :continue | :transactional

    def perform_on(post)
      post.archive!(reason: options["reason"])
    end
  end
end
```

`async` replaces `execute` entirely. Everything in front of it is unchanged — the interaction still validates its inputs, still gets gated by the same policy method, still renders the same form. Only what happens on submit changes: instead of doing the work, it persists a run, enqueues it, and redirects to it.

Three things are worth calling out.

**The run is a resource.** Register it once per portal and its show page *is* the progress page — a live count, the failures so far, and a banner above the resource's collection while a run is in flight. You didn't write any of it.

**Failure has a policy, not a convention.** `on_failure` picks between `:halt` (stop at the first failure), `:continue` (record it and keep going), and `:transactional` (one transaction around the batch, so any failure rolls back everything).

**Permissions are re-derived at perform time, never replayed from dispatch.** The row records who initiated the run and under which tenant, then resolves targets through the policy scope again when the job actually runs. A run is a job, not a snapshot of what the initiator could do at the moment they clicked. If someone loses access between dispatch and perform, the run respects that.

The block is a class body, not a closure — it declares a run class with `perform_on` (targeted work, one call per record) or `perform` (opaque work, no subject), and your validated attributes arrive through `options`. That's deliberate: the work happens in another process with no controller, no request, and no `view_context` to capture.

It's opt-in — a config flag and a migration. Full details in [Async Interactions](/reference/behavior/async-interactions).

## Kanban boards

Any resource index can become a drag-and-drop board from a single `kanban do…end` block in the definition. Columns, WIP limits, locked columns, cross-column drop restrictions — all enforced server-side, not just hidden in the UI. Each column gets an `+ Add` button that opens the resource's normal new form and drops the new card into that column. Column actions run an interaction against every card in a column. Realtime is one line, and every connected viewer converges on the same board state after a move.

See [Kanban Boards](/guides/kanban) for a complete worked example — migration, model, definition, and policy for a task board.

## Wizards

Multi-step flows — onboarding, checkout, "create four related records across five screens", branching questionnaires — are now a single declarative class. Ordered `step`s collect typed data, `condition:` makes steps appear and disappear based on earlier answers, a built-in review step recaps everything before a Finish button, and `execute` commits at the end, atomically by default.

The part that matters most: it reuses the field DSL you already know. `attribute`, `input`, `validates`, `structured_input`, `form_layout` all behave exactly as they do in a definition or an interaction. There's no parallel stack to learn, and no second way to render a select.

Sessions live in one framework table, and it's opt-in like the others. See [Wizards](/guides/wizards).

## The thing underneath two of them

Kanban didn't invent its ordering. It's the same fractional positioning that powers [drag-to-reorder](/reference/positioning) on ordinary index tables, card grids, and nested association tables: `positioned_on` on the model says how positions are stored, `position_on` in the definition says the list is orderable, and a drop writes exactly one decimal — the midpoint between its two neighbours. No renumbering sweep across the table.

A board and a sortable table are the same feature wearing different clothes, which is why they share a vocabulary.

## All three are marked experimental

Deliberately, and it's on every page. The features are complete and we're using them, but the DSLs are new and we'd rather change a method name in response to real use than freeze the first guess into a compatibility promise. If you build on them, watch the changelog — and tell us where the API fights you, because right now that feedback still changes things.

---

Everything above is in the docs already; this is just the first time it's been announced anywhere. If you're upgrading from an older version, the [changelog](https://github.com/radioactive-labs/plutonium-core/blob/master/CHANGELOG.md) is the complete list.
