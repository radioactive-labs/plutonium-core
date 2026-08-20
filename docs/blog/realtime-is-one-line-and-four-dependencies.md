---
title: "Plutonium realtime is one line, and four things that line assumes"
titleTemplate: "Plutonium Blog"
date: 2026-09-17
description: The server broadcasts whether or not anyone can hear it. A feature that half-works in development and does nothing in production deserves its caveats up front.
author: Stefan Froelich
tags: [kanban, hotwire, actioncable]
draft: true
---

# Plutonium realtime is one line, and four things that line assumes

<BlogMeta />

Turning on realtime for a kanban board is one line:

```ruby
kanban do
  realtime true
  # ...
end
```

Move a card and every other viewer of the same board sees it. That is true, and it is also the kind of claim that earns a framework a bad afternoon, because the line does not fail loudly when its assumptions are missing. It fails by working perfectly on the server and reaching nobody.

So here is the honest version.

## What the line actually does

Two things, both server-side.

It renders a `<turbo-cable-stream-source>` element subscribing the page to a stream. And after a successful move, it broadcasts the updated column frames to that stream.

Stream names are tenant-scoped, so viewers in different tenants cannot receive each other's boards. That part is not optional and not something you can misconfigure into a leak.

What it does **not** do is give the browser anything capable of receiving a broadcast.

## The four assumptions

**1. An ActionCable client in your JavaScript.** This is the one that bites. Plutonium's bundled JavaScript ships `@hotwired/turbo` only, with no cable client. Without `@hotwired/turbo-rails` or `@rails/actioncable` in your pack, the `<turbo-cable-stream-source>` element renders and never connects. No error, no console warning, no failed request to look at. The element is simply inert.

**2. The gems.** `turbo-rails` for `Turbo::StreamsChannel`, and ActionCable, which Rails already includes.

**3. A cable adapter in `config/cable.yml`.** `async` is fine for a single-process dev server. In multi-process production it is a trap: a broadcast from one worker never reaches clients connected to another, so realtime works for roughly one in N users depending on which worker they landed on. Redis or Solid Cable for anything real.

**4. ActionCable mounted.** At `/cable`, the usual place.

## Why this is worth a blog post rather than a footnote

Because of the shape of the failure.

Miss any of these and the feature does not break. Your board still works. Drags still persist, the server still broadcasts, the code path still runs, tests that check the move endpoint still pass. The only symptom is that a second browser window does not update, which is exactly the thing nobody checks after the first time they see it work.

And it very often *does* work the first time, in development, on a single-process server with `async` cable and a dev pack that happened to include turbo-rails. Then it stops working in production, where there are four workers and a different pack, and the bug has no error attached to it.

A feature that degrades silently between environments is worse than one that raises. Raising is a bug report; silence is a support ticket six weeks later titled "does realtime actually work?"

## The design tradeoff underneath

The obvious question is why the framework does not just bundle a cable client and remove three of the four steps.

Because that would ship an ActionCable dependency, a WebSocket connection attempt, and a chunk of JavaScript to every Plutonium app, including the large majority that never turn realtime on. Plutonium's asset bundle is deliberately small and its JavaScript deliberately boring. Paying that cost for everyone so one flag can be a true one-liner is a bad trade.

What the framework owes you instead is to be explicit that the line is not self-sufficient. Which is what the docs now do, and what this post is.

## Checking it

The verification that actually matters takes two browsers and thirty seconds. Open the board in both, move a card in one, watch the other. If it does not move, look for the cable client first: it is the missing piece roughly always, because it is the only one of the four that no other Rails feature would have already forced you to set up.

The rest of realtime, the broadcasting, the tenant scoping, the frame updates, is the part you do not have to think about. The connection is the part you do.
