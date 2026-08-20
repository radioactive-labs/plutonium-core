---
title: "Plutonium wasn't built for AI agents. Rails conventions are why they work."
titleTemplate: "Plutonium Blog"
date: 2026-09-10
description: The conventions were chosen for human reasons. Assistants turned out to be unusually accurate inside them, which was informative about both the framework and the docs.
author: Stefan Froelich
tags: [ai, conventions, rails]
draft: true
---

# Plutonium wasn't built for AI agents. Rails conventions are why they work.

<BlogMeta />

There is an "For AI Agents" page in these docs and a `.claude/skills/` directory in the repo, so it is fair to assume this was designed as an AI thing. It was not. The order of events was the other way round, and the order matters, because it is the part that generalises to your own codebase.

I built Plutonium convention-heavy for ordinary human reasons: fewer decisions per feature, one place to change anything, code that reads the same across projects. Then I noticed that assistants were unusually accurate inside it, in a way they were not inside the hand-rolled Rails apps I had written before. That was interesting enough to investigate, and then to lean into.

## Why the accuracy is higher

Not because of anything clever. Because there is less to guess.

Most of what an assistant gets wrong in an unfamiliar Rails app is not syntax. It is context it cannot see: which of four places a filter should live, whether this project puts business logic in the model or a service, what the local naming convention is, what already exists that it should not duplicate.

A Plutonium app answers most of those structurally:

- **The layers are named and their jobs are disjoint.** Model, definition, policy, controller, interaction. "Which fields are visible" has exactly one home, and it is not the one an assistant would guess from a filename.
- **Most behaviour is derived, not declared.** Field types come from columns, required markers from validations, select choices from `inclusion:`, preloads from the policy's permitted fields, tenant scope from associations. There is less code to write, so there is less code to get wrong.
- **Overrides are plain class inheritance.** `AdminPortal::PostDefinition < ::PostDefinition`. No registry, no precedence rules, no merge semantics that have to be learned before you can predict an outcome.
- **The generators produce conventional files.** An assistant that runs `pu:res:scaffold` starts from a correct skeleton rather than an invented one.

None of that was designed with a model in mind. It is just that "predictable enough that a newcomer can infer the next step" and "predictable enough that a language model can" turn out to be close to the same property.

## What I did after noticing

Leaned in, with three things that cost the project nothing if you never use them.

**Skills.** `.claude/skills/` holds a router plus targeted guides. They are not documentation-for-humans copied into a folder. They are written as instructions: what to read before acting, what to ask, the mistakes that cost the most, and explicit gates that say "inspect the app yourself rather than asking the user to describe it."

**`llms.txt` and per-page markdown twins.** Every docs page has a raw `.md` sibling, plus generated `llms.txt` and `llms-full.txt`. An agent can pull exact source rather than scraping rendered HTML.

**A router skill that says what *not* to write.** This is the one that mattered most. The failure mode of an eager assistant is over-declaring: writing `field :title` when the type is already detected, restating a scope, redeclaring an input that auto-detection already got right. So the router now leads with the rule that a declaration matching the detected default is dead code.

## If you do not care about AI

You lose nothing. There is no AI runtime in Plutonium, no model calls, no telemetry, no feature that only works with an assistant. The skills are markdown files you can ignore, and `llms.txt` is a static artifact of the docs build.

What is left is the thing that was there first: a framework where the conventions are strong enough that the next step is usually inferable. That was worth having when the only inference engine was a new team member reading the codebase on their first day.
