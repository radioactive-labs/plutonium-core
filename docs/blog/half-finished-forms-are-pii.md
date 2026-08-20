---
title: "Plutonium wizards: a half-finished form is PII sitting in your database"
titleTemplate: "Plutonium Blog"
date: 2026-09-24
description: Multi-step flows have to put the partial answers somewhere. Once that somewhere is a table instead of a cookie, it is data you are responsible for.
author: Stefan Froelich
tags: [wizards, security, rails]
draft: true
---

# Plutonium wizards: a half-finished form is PII sitting in your database

<BlogMeta />

A single-page form has a comfortable property nobody thinks about: until the user hits submit, the data is in their browser. If they wander off, it evaporates. You never held it, so you never had to protect it, retain it, or explain it in a privacy policy.

Split that form across five screens and the property is gone. The answers from step two have to live somewhere while the user is on step three, and now you are storing them.

Plutonium wizards store staged step values in a `data` column on a single framework table. Which raises a question the framework should not answer silently: what is in that column?

## What is actually in there

Whatever the flow collects, from every step the user has completed so far. For an onboarding wizard that is a company name. For a checkout, an address. For an insurance quote, a date of birth and a medical history, sitting in a row belonging to someone who abandoned the flow at step four and is never coming back.

The rows are not long-lived by design; there is a sweep for abandoned sessions. But "not long-lived" is measured in your configured TTL, which is days, not the milliseconds a browser-held form would have been.

## The opt-in

```ruby
class CheckoutWizard < Plutonium::Wizard::Base
  encrypt_data
  # ...
end
```

That encrypts the `data` column. Deliberately *not* encrypted: `tracked_records` (record GlobalIDs only), and the `owner`, `anchor`, `scope` and `token` columns, which have to stay queryable for the wizard to find and resume a session at all.

Once your app has ActiveRecord encryption keys, you can flip it on globally and opt out per wizard:

```ruby
config.wizards.encrypt_data = true

class PublicSurveyWizard < Plutonium::Wizard::Base
  encrypt_data false   # explicit opt-out even when the global default is on
end
```

An explicit declaration on the wizard always wins. A wizard that declares neither inherits the global flag.

## Why it is off by default

Because it needs ActiveRecord encryption keys configured, and a framework that turns itself on and then raises on a missing key during someone's first `rails g` is a framework people uninstall. Off-by-default here is not an opinion that encryption is optional. It is an acknowledgement that the prerequisite is not in the framework's gift.

That is worth being honest about rather than dressing up, because "secure by default" is the answer everyone wants to give and it would have been the wrong one.

## The implementation detail that turned out to matter

`data` is one shared `jsonb` column across every wizard, some encrypted and some not. A model-level `encrypts :data` does not fit: it would encrypt every row regardless of the wizard's preference, and it fights the `jsonb` type.

So the store encrypts at write time with ActiveRecord's configured encryptor, the same keys `encrypts` would use, and writes a self-describing envelope:

```json
{ "_enc": "<ciphertext>" }
```

A row therefore decrypts based on **its own shape**, not on what the wizard's `encrypt_data?` currently says.

That is the part worth stealing if you are building something similar. It means toggling the flag never strands existing rows. Turn encryption on and the sessions already in flight keep working, plaintext, until they finish or get swept. Turn it off and the encrypted ones still decrypt. There is no migration, no backfill, and no window where a config change breaks resumption for everyone mid-flow.

The alternative, deciding how to read a row based on current configuration, works perfectly until the first time someone changes the configuration, which is precisely when you least want a surprise.

## The question the feature is really asking

Not "should I turn on encryption." It is "did I notice that this form now persists?"

Most multi-step flows get built by someone porting a long single-page form, and the persistence arrives as an implementation detail of the step mechanism rather than a decision anybody made. The flag exists mostly to prompt the thought. If your wizard collects nothing sensitive, ignore it. If it collects a date of birth, you are storing dates of birth, and that was true before anyone thought to ask.
