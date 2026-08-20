---
title: "Plutonium association inputs post a signed id, not a database id"
titleTemplate: "Plutonium Blog"
date: 2026-09-28
description: A select whose values are primary keys is a form the user can edit. Signed Global IDs make the tampered version fail instead of succeed.
author: Stefan Froelich
tags: [security, forms, rails]
draft: true
---

# Plutonium association inputs post a signed id, not a database id

<BlogMeta />

Here is a form field every Rails app has:

```erb
<%= f.collection_select :author_id, User.all, :id, :name %>
```

It renders `<option value="42">`. The user opens devtools, changes 42 to 7, and submits. Whether that matters depends entirely on whether the controller thought to check, which is a sentence that should make you uncomfortable, because "whether someone thought to check" is not a security model.

The usual defences are real but partial. Strong parameters decide *which* keys are allowed, not which values. A policy check on the parent record authorizes the edit, not the thing being pointed at. Scoping the collection you render controls what the select *offers*, and has no bearing on what the browser sends back.

## What Plutonium sends instead

Every association on a resource model gets Signed Global ID accessors, generated automatically:

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_many :tags
end

post.user_sgid                    # => "BAh7..."
post.user_sgid = "BAh7..."        # locates and assigns from the SGID

post.tag_sgids                    # => ["...", "..."]
post.tag_sgids = [sgid1, sgid2]   # bulk replace
```

The association input posts the SGID. A Global ID carries the class as well as the id, and signing it means the server can tell whether the value it received is one it issued.

Two consequences fall out.

**Tampering fails instead of succeeding.** Editing the option value produces a signature that does not verify, so the assignment raises rather than silently pointing at record 7. The failure mode moves from "wrong data, no error" to "error, no data," which is the direction you want.

**The class travels with the value.** `42` means nothing on its own; a Global ID says `gid://app/User/42`. A payload cannot smuggle a `Post` id into a field expecting a `User`, because the type is part of the signed value rather than an assumption the controller makes.

## What it is not

It is not authorization, and treating it as such is the mistake worth naming.

An SGID proves the server issued this reference. It says nothing about whether *this* user may point at *that* record. A signed id you were legitimately given yesterday is still legitimately signed today, after your access was revoked.

So the picker's options still come from `authorized_resource_scope`, which applies the target resource's own `relation_scope` and the current policy context. That is what decides which records a user may reference. The signature is a separate property: it stops the value being swapped for one that was never offered.

Two mechanisms, two questions. What may you see, and is this the thing you were shown. Conflating them gets you a system that is careful about exactly one of them.

## Why it can be automatic

The reason this is on by default rather than an opt-in helper is that it costs the developer nothing. The accessors are generated from the associations already declared on the model, so there is no new declaration, no field-level configuration, and no way to forget it on the one form written in a hurry.

That is the general shape of the useful kind of security default: not a feature you enable, but a thing that is already true because the framework could derive it from what you had already written. A defence you have to remember to apply is a defence with a failure rate equal to how often people are tired.

## When you will notice it

Mostly, never. The inputs render as ordinary selects with typeahead, and the values round-trip. You will notice on the day you look at a payload in the network tab and wonder why the author field contains `BAh7...` instead of a number.

The answer is that a number would have been a request, and this is a receipt.
