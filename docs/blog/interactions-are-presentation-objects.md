---
title: "Plutonium interactions are presentation objects, not service objects"
titleTemplate: "Plutonium Blog"
date: 2026-08-31
description: One required keyword argument in the constructor decides where your business logic is allowed to live, and it is not in the interaction.
author: Stefan Froelich
tags: [architecture, interactions, rails]
draft: true
---

# Plutonium interactions are presentation objects, not service objects

<BlogMeta />

Every Rails codebase eventually grows a folder for "the logic that isn't a model and isn't a controller." It gets called `app/services`, or `app/operations`, or `app/commands`. Plutonium has a folder that looks like that. It is called `app/interactions`, and putting your business logic in it is usually a mistake.

Here is why, in one line of the base class:

```ruby
def initialize(view_context:, **attributes)
```

`view_context:` is required. Not optional, not defaulted. An interaction cannot be constructed without one.

That single constraint decides the whole architecture, so it is worth being precise about what it means.

## What the constraint rules out

A `view_context` comes from a Rails view render. A background job does not have one. Neither does an API controller responding with JSON, a rake task, a seeds script, or the console.

So the moment a second caller needs the operation, you have exactly two options, and both are bad:

1. **Duplicate the logic** in the job, and now two implementations of "publish a post" drift apart.
2. **Manufacture a `view_context`** so the job can build the interaction, which means a background job now owns a rendering context it has no business owning, purely to satisfy a constructor.

`view_context` is the tell. If an object requires a view to exist, that object is part of the presentation layer, whatever folder you filed it in.

## What an interaction is actually for

An interaction is the entry point from a Plutonium page into an operation. Its job is:

- declaring the inputs, which become a form
- rendering as a button in the right place, decided by whether it declares `:resource`, `:resources`, or neither
- validating the shape of what the user typed
- being gated by a policy method
- returning an outcome the controller turns into a flash message and a redirect

That is a complete and useful job. It is also entirely presentational. None of it is "what publishing a post means."

## So where does the logic go

On the model, per ordinary Rails convention. Named in domain language, not persistence language: `publish!`, `archive!`, `register!`, never `update_published_at`.

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  def publish!(on: Time.current)
    update!(published: true, published_at: on)
  end
end
```

```ruby
# app/interactions/publish_post_interaction.rb
class PublishPostInteraction < ResourceInteraction
  presents label: "Publish", icon: Phlex::TablerIcons::Send

  attribute :resource
  attribute :publish_date, :datetime, default: -> { Time.current }

  input :publish_date
  validates :publish_date, presence: true

  private

  def execute
    resource.publish!(on: publish_date)
    succeed(resource).with_message("Post published!")
  rescue ActiveRecord::RecordInvalid => e
    failed(e.record.errors)
  end
end
```

The interaction is three lines of doing and a lot of declaring. That ratio is the point.

## The rule, stated properly

**Logic may start in `execute`.** A one-off with a single caller is fine inline. Do not pre-extract, and do not invent a service layer for it. Plutonium deliberately ships nowhere to put one, and YAGNI applies here as much as anywhere.

**The trigger to extract is the second caller.** A background job, an API controller, a rake task, the console, another interaction. Not a line count, not a sense that the method is getting long.

**The destination is the model.** Fat models, the way Rails always meant it.

## The chain that gives it away

Here is the shape that tells you the logic ended up in the wrong layer:

```ruby
# Three interactions, three view_contexts.
CreateUserInteraction.call(view_context:, **user_params)
  .and_then { |user| SendWelcomeEmail.call(view_context:, user:) }
  .and_then { |user| LogActivity.call(view_context:, user:) }
```

Now write the signup API endpoint. Or the seeds script. Or the admin rake task that backfills accounts. None of them can supply a `view_context`, so none of them can send the welcome email or write the audit row. The email and the audit trail are stranded inside the presentation layer, reachable only by someone clicking a button.

The same thing, put where it belongs:

```ruby
def execute
  user = User.register!(**attributes)   # welcome email + audit row live in here
  succeed(user).with_message("Welcome aboard!")
end
```

Chaining three interactions is usually one model method wearing three presentation costumes.

## What genuinely does belong inline

Not everything in `execute` is misplaced. This is correct:

```ruby
def execute
  resource.update!(updated_by: current_user)
  succeed(resource)
end

private

def current_user = view_context.controller.helpers.current_user
```

"Who clicked the button" is context that only the presentation layer holds. A job has no answer for it. There is no second caller to extract for, because the fact being recorded is itself presentational.

## Validations split the same way

The split shows up again in validations, and it is worth getting right because the two kinds surface differently.

An **interaction validation** asks "can I read this input?" Is it present, does it parse, is the format plausible. It attaches to a declared attribute, so the re-rendered form shows the error inline against that field.

A **model validation** asks "is this record legal?" It holds no matter who is calling, including the job that has no form to render errors into. `failed(record.errors)` flattens `ActiveModel::Errors` into full messages on `:base`, so those land in the error summary rather than against a field.

Which means it is often right to duplicate a cheap invariant: the model keeps the authoritative copy, and the interaction keeps a copy purely so the message lands on the right input. What must never happen is the reverse, where only the interaction enforces it, because the day a job calls the model directly, the rule is not in the picture at all.

## Why a required keyword argument is a good design

It would have been easy to make `view_context:` optional. Default it to `nil`, let the interaction work headlessly, and interactions become service objects that happen to render forms.

Leaving it required is a constraint that answers an architectural question every Rails team argues about, permanently, at the point where the question is cheapest to answer: when you try to call the thing from a job and it will not build.

You can still write a service layer if you want one. Plutonium is plain Rails underneath and nothing stops you. But you will not drift into one by accident, which is how most of them get started.
