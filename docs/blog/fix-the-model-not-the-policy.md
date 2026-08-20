---
title: "Plutonium multi-tenancy: fix the model, not the policy"
titleTemplate: "Plutonium Blog"
date: 2026-08-27
description: A tenant leak is usually a modelling problem wearing a query costume. Patching it with a where clause in a policy fixes one read and leaves the others open.
author: Stefan Froelich
tags: [multi-tenancy, authorization, rails]
draft: true
---

# Plutonium multi-tenancy: fix the model, not the policy

<BlogMeta />

Most multi-tenancy bugs are not clever. They are a missing `where` on the one query somebody forgot, in the one place nobody looked.

That is worth sitting with, because it tells you what kind of problem it is. If the fix for a leak is "add the filter here too," then the filter is not a property of your data. It is a habit, applied by hand, at every read, forever, by everyone who joins the team. Habits have a failure rate.

Plutonium takes a different position: the relationship between a record and its tenant is a fact about your schema, and the framework should be able to *read* it rather than being told it repeatedly.

## What you declare

Once, on the portal:

```ruby
# packages/admin_portal/lib/engine.rb
module AdminPortal
  class Engine < ::Rails::Engine
    include Plutonium::Portal::Engine

    scope_to_entity Organization, strategy: :path
  end
end
```

Then you design your models the way you would have anyway:

```ruby
class Project < ApplicationRecord
  belongs_to :organization
end

class Task < ApplicationRecord
  belongs_to :project
  has_one :organization, through: :project
end
```

That is the whole setup. Every query in that portal is scoped, every create is associated, every nested route is constrained, because `Model.associated_with(entity)` can see the path from a record to its tenant by reading your associations.

## How the path gets resolved

In a defined order, cheapest first:

1. **A custom scope** named `associated_with_<entity_name>`. Highest priority, full SQL control.
2. **A direct `belongs_to`** to the entity class. Plain `WHERE`, most efficient.
3. **`has_one` or `has_one :through`** to the entity class. A JOIN plus a WHERE, auto-detected by reflecting on the model's associations.
4. **A reverse `has_many`** from the entity. Works, requires a JOIN, and logs a warning because you can almost always do better.

If none apply, you get an error that names both classes:

```
Could not resolve the association between 'Invoice' and 'Organization'
```

That error is the feature. It fires at the moment the relationship is undeclared, rather than letting the read succeed unscoped and become an incident later. A framework that guessed here, or silently returned everything, would be worse than one that stops.

## The wrong fix

The tempting response to that error is to reach for the policy:

```ruby
# Don't.
relation_scope do |relation|
  skip_default_relation_scope!
  relation.joins(:contract).where(contracts: {organization_id: entity_scope.id})
end
```

It works. It costs three things.

You needed `skip_default_relation_scope!` to get here, because an override is otherwise required to compose `default_relation_scope`, which calls the resolver that is already failing. So you switched off the framework's scoping in order to hand-write a replacement for it.

`default_relation_scope` does more than tenant filtering. On a nested route it scopes children through the parent association instead. Your entity join covers one of those two branches, so nested routes lose their scoping.

And it holds only where you wrote it. The next place that needs this relationship needs the join written again.

## The right fix

Put the resolution on the model, where the relationship actually lives:

```ruby
class Invoice < ApplicationRecord
  belongs_to :contract

  scope :associated_with_organization, ->(org) {
    joins(:contract).where(contracts: {organization_id: org.id})
  }
end
```

Now `Invoice` scopes exactly the way `Project` does. The index, the show page, nested routes, the export, the typeahead and the authorization scope all behave identically, because they all go through the same resolver. You replaced one lookup, not the mechanism.

And the next person who adds a read path gets the scoping for free, without knowing this conversation happened.

## The general shape

This is convention-over-configuration doing the thing it is supposed to do, one layer above where Rails usually does it. The convention covers the common cases. The exception gets a named, obvious place to live. And critically, the exception lives on the **model**, so it applies everywhere the record is read, instead of everywhere somebody remembered to apply it.

The same instinct shows up in the sharp edges:

- **Two associations to the same tenant class** and Plutonium refuses to guess which one scopes the record. You override `scoped_entity_association` on the controller. A framework that picked one for you would be picking your security model by coin flip.
- **Debugging a scope** is `skip_default_relation_scope!`, an explicit, greppable opt-out. Not a `where` bypass that survives review because it looks like ordinary code.
- **A portal with no `scope_to_entity`** sees everything, which is the right way to build a super-admin view: an explicit absence of scoping, in one obvious place, rather than a special case threaded through policies.

## Where this stops

None of this protects you from a raw `Invoice.where(...)` in a script, or from a controller you hand-wrote that never asks the policy. It scopes the paths that go through Plutonium, which is most of them in a Plutonium app, and none of them outside it.

For cross-resource reads in your own code, the equivalent discipline is to use `authorized_resource_scope(OtherModel)` rather than `OtherModel.all`, because that applies the other resource's `relation_scope` and the current policy context instead of bypassing both.

The rule is short enough to remember: if scoping fails, the model is missing a relationship. Say what the relationship is. Do not describe the query to the policy.
