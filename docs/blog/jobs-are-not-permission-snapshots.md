---
title: "Plutonium async runs: a queued job is not a permission snapshot"
titleTemplate: "Plutonium Blog"
date: 2026-09-03
description: The usual bulk-job pattern decides who is allowed at enqueue time and then trusts that decision minutes later. Plutonium re-derives it, per target, right before doing the work.
author: Stefan Froelich
tags: [async, authorization, rails]
draft: true
---

# Plutonium async runs: a queued job is not a permission snapshot

<BlogMeta />

Here is the bulk operation everyone writes at least once:

```ruby
def archive_all
  ids = params[:ids]
  authorize_all!(ids)
  ArchivePostsJob.perform_later(current_user.id, ids)
  redirect_to posts_path, notice: "Archiving in the background"
end
```

It is a reasonable piece of code and it contains a bug that is easy to miss, because the bug is not in any line. It is in the gap between two of them.

Authority is decided in the controller, at enqueue time. The work happens somewhere else, minutes or hours later. In between, the queue is holding a list of record IDs and a user ID, and nothing in that payload is a permission. It is a claim that a permission existed once.

## What can change in the gap

Quite a lot, and none of it is exotic:

- The initiator loses access. They are removed from the team, their role is downgraded, their account is suspended. The job proceeds anyway, applying an authority that was revoked before it ran.
- A record moves to another tenant, or gets reparented, or is deleted. The job loads it by ID and acts on it, because an ID does not carry a tenant.
- Someone renames or re-namespaces the model class between deploy and drain. The job deserializes into a class whose policy the initiator was never subject to.
- The initiator, the tenant, or the parent record is deleted outright. Now the job is holding a foreign key to nothing.

Each of these is individually unlikely on any given day. Collectively, across a queue that runs every day for years, they are certainties. And every one of them fails in the same direction: the job does the work.

## What Plutonium persists instead

An `async` interaction does not serialize a decision. It persists a run, and the run records the *inputs to* a decision: who initiated it, which tenant they were in, which parent record scoped the dispatch if it was nested, and the validated attributes.

When the job picks it up, `Async::Context` rebuilds the authorization triple from that row and re-asks every question from scratch. It trusts nothing the dispatching request already concluded.

There are four separate checks, and the interesting part is that they are separate.

**The scope check** re-runs the same `associated_with` filtering the index would use. A target that left the tenant, left the parent, or was deleted between dispatch and perform is reported as `missing` or `unauthorized`. It is not silently skipped, which matters: a run that quietly processes 47 of 50 records and reports success is worse than one that tells you which three it refused.

**The predicate check** re-asks the policy the same question dispatch asked, per target, immediately before each `perform_on`. Not once up front for the batch. That distinction is the whole feature: an initiator whose permission is revoked halfway through a run stops applying to the remaining targets, mid-run.

**The policy mismatch check** refuses to run at all if the class has been renamed, reparented, or re-namespaced since dispatch. The alternative is authorizing under a policy the initiator was never subject to, which is the kind of thing that is invisible until it is an incident.

**The deleted subject check** refuses the run if the initiator, tenant, or parent is gone. This one has a subtlety worth spelling out, because it is where a naive implementation quietly breaks. When the association nils out, `nil` reads as "there was never one here": no tenant, or not a nested dispatch. Both of those interpretations *drop a filter* rather than narrowing one. So a deleted tenant would widen the run's reach rather than stopping it. The `*_type` column is what distinguishes "this run carries no tenant" from "this run carries a tenant that is gone."

## Failing closed

The rule underneath all four is that resolution failure always fails **closed**. Refuse, or report missing. Never "assume permitted."

That sounds obvious written down. It is not what most hand-rolled jobs do, because most hand-rolled jobs do not re-resolve anything at all, and code that never asks a question cannot fail its answer closed. The default behaviour of `find(id)` plus a serialized `user_id` is to fail open, silently, in exactly the cases you would most want to know about.

## What you write

None of the above appears in your code. The interaction declares the work:

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

`async` replaces `execute`. Everything in front of it is unchanged: same form, same validations, same policy gate. Only what happens on submit changes. Instead of doing the work in the request, it persists a run, enqueues it, and redirects to a progress page you did not write.

The block is a class body rather than a closure, and that is deliberate for the same reason the row stores an initiator instead of a serialized user object. The work happens in a process with no controller, no request, and no `view_context` to capture. `def` opens a fresh scope, so those method bodies cannot accidentally close over the interaction's locals, which is the one thing that would make writing them there misleading.

## The part that is genuinely hard

Re-deriving permissions is the easy half. The hard half is that a worker crash mid-batch leaves a run marked `running` forever, and nothing revisits it on its own.

Plutonium ships `Async::ReapJob` for that: it finds runs with no recorded activity past `config.async_interactions.stall_after`, resets them to `pending`, and re-enqueues. The install generator schedules it automatically when Solid Queue is in the bundle. On any other scheduler **you have to schedule it yourself**, and if you do not, a crash mid-batch is a row that says `running` until someone goes looking.

That is worth stating plainly rather than burying, because it is the failure mode the feature cannot solve for you.

## Why bother

Because the alternative is a permission model where the answer to "can this user do this?" is computed once, in a controller, and then trusted by a different process at an unbounded later time. That is a snapshot, and a snapshot of an authorization decision is not an authorization decision. It is a cached one, with no invalidation.

Async interactions are marked experimental, so the DSL may still move. The property described here is not the part I expect to change.
