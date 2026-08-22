---
title: "What's new in Plutonium: async interactions, kanban boards, and wizards"
titleTemplate: "Plutonium Blog"
date: 2026-09-07
description: Three features that close the same gap, where you got most of the way through building something in Rails and then had to leave the framework to finish it.
author: Stefan Froelich
tags: [release, async, kanban, wizards]
draft: true
---

# What's new in Plutonium: async interactions, kanban boards, and wizards

<BlogMeta />

Three features landed that share a shape. Each one closes a place where you could get most of the way through a feature and then had to drop out of the framework and hand-roll the rest: work that takes too long for a request, a board view, and a form that spans more than one screen.

## Async interactions

An interaction is the button, form, policy gate and outcome in front of an operation. That works right up until the operation does not fit in a request: archiving five thousand records, generating a report, calling a third-party API that takes its time.

The old answer was to write the interaction anyway, enqueue a job from `execute`, invent somewhere to store progress, and build a page to show it. Now you declare the work with `async` and skip all of that:

```ruby
class Blogging::ArchivePosts < ResourceInteraction
  presents label: "Archive", icon: Phlex::TablerIcons::Archive

  attribute :resources          # bulk, so perform_on runs once per record
  attribute :reason, :string

  async do
    on_failure :continue        # :halt (default) | :continue | :transactional

    def perform_on(post)
      post.archive!(reason: options["reason"])
    end
  end
end
```

`async` replaces `execute` entirely. Everything in front of it is unchanged: the interaction still validates its inputs, still gets gated by the same policy method, still renders the same form. Only what happens on submit changes. It persists a run, enqueues it, and redirects to it.

Three things worth calling out.

**The run is a resource.** Register it once per portal:

```bash
rails g pu:async_interactions:install --dest=admin_portal
```

Its show page *is* the progress page: a live count, the failures so far, and a banner above the resource's collection while a run is in flight. You wrote none of it.

**Failure has a policy, not a convention.** `on_failure` picks between `:halt` (stop at the first failure), `:continue` (record it and keep going), and `:transactional` (one transaction around the batch, so any failure rolls back everything).

**Permissions are re-derived at perform time, never replayed from dispatch.** The row records who initiated the run and under which tenant, then resolves targets through the policy scope again when the job actually runs. If someone loses access between dispatch and perform, the run respects that. There is [a longer post](/blog/jobs-are-not-permission-snapshots) on why this matters.

It is opt-in: a config flag and a migration.

## Kanban boards

Any resource index can become a drag-and-drop board from a single `kanban do…end` block in the definition:

```ruby
class TaskDefinition < ResourceDefinition
  kanban do
    column :todo,
      scope: -> { where(status: "todo") },
      on_enter: ->(r) { r.update!(status: "todo") },
      role: :backlog

    column :doing,
      scope: -> { where(status: "doing") },
      on_enter: ->(r) { r.update!(status: "doing") },
      wip: 3

    column :done,
      scope: -> { where(status: "done") },
      on_enter: :mark_done!,     # Symbol calls record.mark_done!
      accepts: [:doing]          # only cards from :doing can land here
  end
end
```

 Columns, WIP limits, locked columns and cross-column drop restrictions, all enforced server-side rather than merely hidden in the UI. Each column gets an `+ Add` button that opens the resource's normal new form and drops the new card into that column. Column actions run an interaction against every card in a column. Realtime is one line, and every connected viewer converges on the same board state after a move.

See [Kanban Boards](/guides/kanban) for a complete worked example: migration, model, definition and policy for a task board.

## Wizards

Onboarding, checkout, "create four related records across five screens", a branching questionnaire: multi-step flows are now a single declarative class. Ordered `step`s collect typed data, `condition:` makes steps appear and disappear based on earlier answers, a built-in review step recaps everything before the Finish button, and `execute` commits at the end, atomically by default.

```ruby
class CompanyOnboardingWizard < Plutonium::Wizard::Base
  presents label: "Onboard a company", icon: Phlex::TablerIcons::BuildingSkyscraper

  step :company, label: "Company details" do
    attribute :name, :string
    input :name
    validates :name, presence: true
  end

  step :plan, label: "Plan" do
    attribute :plan, :string
    input :plan, as: :radio_buttons, choices: %w[free pro]
    validates :plan, presence: true
  end

  review label: "Review & submit"

  def execute
    company = Company.create!(name: data.company.name, plan: data.plan.plan)
    succeed(company).with_message("You're all set!")
  end
end
```

The part that matters most is that it reuses the field DSL you already know. `attribute`, `input`, `validates`, `structured_input` and `form_layout` behave exactly as they do in a definition or an interaction. There is no parallel stack to learn and no second way to render a select.

See [Wizards](/guides/wizards) for the full DSL, including per-step writes, resume, and one-time wizards.

## The thing underneath the board

Kanban did not invent its ordering. It uses the same fractional positioning that powers [drag-to-reorder](/reference/resource/positioning) on ordinary index tables, card grids and nested association tables. `positioned_on` on the model says how positions are stored, `position_on` in the definition says the list is orderable, and a drop writes exactly one decimal, the midpoint between its two neighbours. No renumbering sweep across the table.

A board and a sortable table are the same feature wearing different clothes, which is why they share a vocabulary. Positioning itself is stable, not experimental.

## Kanban, wizards and async are marked experimental

Deliberately, and it says so on each page. The features are complete and in use, but the DSLs are new and I would rather rename a method in response to real use than freeze a first guess into a compatibility promise. Positioning is not in that group.

If you build on the experimental three, watch the changelog, and tell me where the API fights you. That feedback still changes things.
