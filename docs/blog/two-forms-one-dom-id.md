---
title: "Two forms, one DOM id, and the Rails validation errors that vanished"
titleTemplate: "Plutonium Blog"
date: 2026-09-14
description: A Turbo Stream replaces the first matching element in document order. When two forms on a page share an id, that is rarely the one the user submitted.
author: Stefan Froelich
tags: [hotwire, turbo, debugging]
draft: true
---

# Two forms, one DOM id, and the Rails validation errors that vanished

<BlogMeta />

The bug report was the worst kind: "sometimes validation errors don't show up." Not an exception, not a 500, no log line. The form submits, the modal sits there, and whatever the server said about the invalid email address goes nowhere.

The cause is one sentence of Turbo's contract, and it is not a bug in Turbo.

## The mechanism

`turbo_stream.replace("resource-form", …)` replaces the element with that id. If more than one element has that id, Turbo takes the first match in document order. The DOM does not enforce id uniqueness, and nothing in Rails warns you.

In an admin UI, duplicate form ids are not exotic. Two ways it happened here:

- A primary modal opens a secondary, stacked modal. Both render a resource form. Both call it `resource-form`.
- Any index page ships an off-screen Filters slideover with its own form, alongside the CRUD form.

So the server responds to a submission from the *second* form, Turbo finds the *first*, replaces something the user cannot see, and the visible form is untouched. From the user's side, nothing happened. From the logs' side, a 422 rendered and a stream was sent. Everything worked.

That gap between "the server did the right thing" and "the user saw nothing" is why this survives review. There is no failing test to write until you know the failure exists.

## The fix

Ids get scoped to the Turbo frame they render in:

```ruby
def turbo_scoped_dom_id(base)
  base = base.to_s
  case current_turbo_frame
  when Plutonium::REMOTE_MODAL_FRAME           then "#{base}-primary"
  when Plutonium::REMOTE_MODAL_SECONDARY_FRAME then "#{base}-secondary"
  else base
  end
end
```

Outside a modal you get `resource-form`. Inside the primary modal, `resource-form-primary`. Inside the secondary, `resource-form-secondary`. The stream replace derives its target the same way, from the frame the request came in on, so a submission from the stacked modal can only ever address the stacked modal's form.

The Filters slideover stopped borrowing the name entirely and uses `filter-form`, so a CRUD replace cannot reach it regardless of frames.

## Two things that made it harder than it sounds

**Ids had to be resolved at render time, not construction time.** The obvious place to compute the id is when the form component initialises its attributes. Phlex cannot reach `view_context` there, and `current_turbo_frame` comes from the request. So resolution moved into a `form_attributes` override that runs during render, when the frame is actually knowable.

**The id had to be forced rather than merged.** Phlexi's `@namespace.dom_id` prepends a namespace token if you let it merge, which produced ids like `q filter-form`. A space in an id is legal HTML and completely breaks `getElementById`. Forcing the value avoided a bug that would have looked exactly like the one being fixed.

## What generalises

You do not need Plutonium to hit this. You need a Turbo Stream, a component that hardcodes an id, and any situation where that component can appear twice. Modals over modals is the common one. A slideover, a drawer, an inline edit row inside a table that also has a create form: all the same shape.

Three things worth taking away:

**A stream replace is a query, not an address.** `replace("resource-form")` says "find something called this," and it will find something. It is only unambiguous if you have guaranteed uniqueness, which nothing does for you.

**Silence is the tell.** When a form submits and *nothing at all* happens, suspect that something did happen, off-screen. A stream that targets the wrong element is indistinguishable from a stream that was never sent, unless you go looking in the network tab.

**Component ids need a scope.** Any component that hardcodes a DOM id has an implicit assumption that it renders once per page. That assumption is fine right up until the day someone opens it in a modal.

The tests that came with the fix cover the helper in all five frame contexts, including no frame and a non-modal frame. Which is the other half of the lesson: once you know the failure mode, it is trivial to test. The expensive part was believing "sometimes errors don't show up" for long enough to find it.
