---
name: plutonium-wizard
description: Use BEFORE building any multi-step Plutonium flow — onboarding, checkout, multi-model create, branching questionnaire. Covers the wizard DSL (steps, branching, using:, review, per-step on_submit/persist/rollback, execute), anchoring & resume, one-time wizards + gate, registration (wizard macro + register_wizard), and storage/config. The single source for "how do I build a wizard".
---

# Plutonium Wizards

A wizard is a multi-step flow authored as a single class — `class X < Plutonium::Wizard::Base`. It collects typed `data` across ordered `step`s, optionally branches with `condition:`, and commits at the end via `execute`. It reuses the existing field DSL, form rendering, actions, and policies — no parallel stack.

For the field/input vocabulary used inside a step, load [[plutonium-resource]]. For the Outcome / `succeed`/`failed` pattern and the Action system wizards register through, load [[plutonium-behavior]].

## 🚨 Critical (read first)

- **Enable the subsystem first.** `config.wizards.enabled = true` in `config/initializers/plutonium.rb`, then `rails db:migrate`. It's `false` by default — without it there's no `plutonium_wizard_sessions` table.
- **Use bang methods** (`create!`/`update!`/`save!`) in `on_submit` and `execute`. Failure is signalled by a **raised exception** — a non-bang `false` advances the wizard and silently loses data. Or call `fail!("msg")`.
- **`data` is step-keyed:** `data.<step>.<field>` (e.g. `data.company.name`, `data.plan.plan`). Each step has its own typed sub-object, so two steps may share a field name without colliding. Read a field through its owning step everywhere (`condition:`/`on_submit`/`execute`).
- **`condition:` lambdas must be nil-safe.** They run against `data` at every transition, including before their deciding step is filled (value is `nil`). `-> { data.plan.plan == "pro" }` ✓; `-> { data.plan.plan.upcase == "PRO" }` raises on nil ✗.
- **`review` must be the LAST step.** A step declared after `review` raises at load.
- **`using:` targets a MODEL only** — not an interaction, not a bare definition. Selectors `fields:`/`only:`/`except:`.
- **No generator.** Author wizards by hand, like interactions. They live in `app/wizards/`.
- **Wizards are portal-hosted.** They run inside a portal (auth/scoping/layout inherited). Main-app standalone wizards are out of scope for v1.
- **Schedule `SweepJob` if you use `on_submit`.** It's the only thing that cleans up abandoned mid-flow records.

---

## Minimal wizard

The common case writes nothing until the end. Steps collect `data`; one `execute` does all writes atomically.

```ruby
# app/wizards/company_onboarding_wizard.rb
class CompanyOnboardingWizard < Plutonium::Wizard::Base
  presents label: "Onboard a company", icon: Phlex::TablerIcons::BuildingSkyscraper

  step :company, label: "Company details" do
    attribute :name, :string
    attribute :subdomain, :string
    input :name
    input :subdomain
    validates :name, :subdomain, presence: true
  end

  step :plan, label: "Plan" do
    attribute :plan, :string
    input :plan, as: :radio_buttons, choices: %w[free pro]
    validates :plan, presence: true
  end

  review label: "Review & submit"

  def execute
    company = Company.create!(name: data.company.name, subdomain: data.company.subdomain, plan: data.plan.plan)
    succeed(company).with_message("You're all set!")
  end
end
```

- `presents label:/icon:` — launch button chrome (same as interactions).
- A `step :key, label: do ... end` is one screen; the block uses the field DSL ([[plutonium-resource]]).
- `data.<step>.<field>` reads the **typed** value (cast to declared type) for that step, e.g. `data.company.name`.
- `review` — built-in terminal step: auto-summary + gated Finish. Must be last.
- `execute` — runs once at the end in one transaction; returns `succeed(...)` / `failed(...)`.

## Wizard-level macros

| Macro | Meaning |
|---|---|
| `presents label:, icon:` | Launch button label + icon. |
| `navigation :linear \| :free` | Stepper jumps. `:linear` (default) = back to any visited step; `:free` = any visible visited step. Forward to unvisited is never allowed. |
| `anchored with: Model` / `anchored via: :method` | Run against an existing record (read via `anchor`). `with:` = URL `:id` (resource-mounted); `via:` = a controller method (portal-level, context). |
| `cleanup_after <ttl> \| :never` | Idle TTL before the sweep reaps the session + rolls back tracked records. Default `config.wizards.cleanup_after`. |
| `concurrency_key { … }` | Key a run by the returned value(s) (tenant folded in). The keyed `in_progress` row is the lock — a second launch resumes, never forks. Omit → unlimited `wizard_token`-keyed runs. |
| `one_time` | Retain the completed row at the `concurrency_key` → run once (gate-able). **Requires `concurrency_key`.** Omit → row deleted on complete (repeatable). |
| `encrypt_data` | Encrypt the staged `data`/`tracked_records` columns (PII flows). |
| `anonymous` | Opt into **guest (unauthenticated) access.** Default = auth required. A guest wizard may authenticate only at its terminal `execute`; never mid-flow. Mount it `public: true` (the default for `anonymous`). |

## Branching — `condition:`

Subtractive: a falsy `condition:` removes the step from the visible path.

```ruby
step :billing, label: "Billing", condition: -> { data.plan.plan == "pro" } do
  attribute :card_token, :string
  input :card_token
  validates :card_token, presence: true
end
```

`condition:` can also read `anchor`. Branch-hidden steps' data is pruned before `execute`. **Must be nil-safe** (see Critical).

## Field reuse — `using:` a model

`using:` is a **step option** (not a block method) and targets a **model only**.

```ruby
# Whole-step import — no block needed.
step :branding, label: "Branding", using: Company, fields: %i[logo brand_color]

# Mix imported + wizard-local fields.
step :details, using: Company, only: %i[tagline] do
  attribute :referral_code, :string
  input :referral_code
end
```

Imports: field universe + types from `Model.attribute_names`/`attribute_types`; input styling from the auto-resolved `<Model>Definition`; validations via transient `Model.new(slice).valid?` (errors kept on imported fields + `:base`); inherited `form_layout`.

| Selector / flag | Effect |
|---|---|
| `fields:` (alias `only:`) | Import only these. |
| `except:` | Import all but these. |
| `validate: false` | Skip validation reuse (write inline `validates`). |
| `layout: false` | Skip inherited `form_layout`. |
| `validation_context:` | Run `valid?(context)`. |

**Declaration reuse only** — never the model's persistence. Data stages into `data`; `execute` does the writes.

## Step internals

Inside a `step` block, the field DSL from [[plutonium-resource]] applies verbatim:

```ruby
step :company, label: "Company details" do
  attribute :name, :string                 # typed → feeds data.company.name
  input :name                              # how it renders
  validates :name, presence: true          # ActiveModel, run on Next

  structured_input :invites, repeat: 5 do |f|   # data.company.invites → array of typed sub-objects
    f.input :email, as: :email
    f.input :role, as: :select, choices: %w[admin member]
  end

  form_layout do                            # section THIS step's fields
    section :identity, :name, label: "Identity", columns: 2
  end
end
```

Repeater rows rehydrate from staged `data` on GET (resume / back re-renders filled rows).

## The review step

```ruby
review label: "Review & submit"            # auto-summary + gated finish

review label: "Review & submit" do |wizard|  # custom content after the summary
  "By submitting you agree to the #{wizard.data.plan.plan} plan terms."
end
```

Lists invalid/unvisited steps as fix-this jump links; Finish disabled until all visible steps valid. Declares no fields.

## Per-step writes — `on_submit` / `persist` / `on_rollback`

`execute` is the default (atomic). Use `on_submit` **only** when a real record must exist mid-flow (external handoff, reviewer sees partials, payload too large for the row).

```ruby
step :billing, label: "Billing" do
  attribute :card_token, :string
  input :card_token
  validates :card_token, presence: true

  on_submit do                              # runs when THIS step completes, own transaction
    charge = PaymentApi.authorize!(anchor, data.billing.card_token)
    fail!("Card was declined") unless charge.ok?         # base error; fail!(:field, "msg") for field error
    persist Billing.create!(company: anchor, token: data.billing.card_token)   # → persisted[:billing]
  end

  # on_rollback = ADDITIONAL cleanup of UNTRACKED side effects (refund/external API).
  # The engine ALWAYS destroys persisted[:billing] itself; this runs BEFORE that
  # destroy (record still alive). Don't destroy the persist'd record here.
  on_rollback { PaymentApi.refund!(persisted[:billing].charge_id) }
end
```

**`persist` always cleans up.** On any rollback (Cancel, sweep, branch-prune) the engine **always** destroys every `persist`'d record via `destroy!` (respects a model's soft-delete override). `on_rollback` is **optional, additive** — it compensates side effects the engine can't see, runs **before** the destroy, and a side-effect-only step (no `persist`) still runs its `on_rollback`. To keep a partial record, make the model soft-delete or use `cleanup_after :never`.

`on_submit` is not atomic across steps (HTTP), which is why `cleanup_after` + `SweepJob` exist.

## Accessors

| Accessor | Returns |
|---|---|
| `data` / `data.<field>` | Typed snapshot of everything entered. Not-yet-collected → `nil` / `default:`. Read-only. |
| `anchor` | The launched-against record. Raises `NotAnchoredError` if not `anchored` (never nil). |
| `persisted[:step_key]` | Record(s) registered via `persist` in `on_submit`. Rehydrated on resume. |
| `succeed(v)` / `failed(errs)` | Outcome helpers (alias `success`). `.with_message`, `.with_redirect_response` chainable. |
| `fail!(msg)` / `fail!(:field, msg)` | Raise a `StepError` from `on_submit`/`execute`. |

## Anchoring

```ruby
anchored with: Company              # single type
anchored with: [Company, Org]       # polymorphic
anchored                            # generic — type bound at registration
# omit                              # pure create flow (no anchor)
```

`anchor` raises `Plutonium::Wizard::NotAnchoredError` when the wizard isn't `anchored`. The anchor is read-only context, **not** part of `persisted`.

## One-time wizards + gate

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"

  concurrency_key { current_user }  # stable row to retain (tenant folded in)
  one_time                           # retain on complete → run once

  step :greeting do
    attribute :acknowledged, :string
    input :acknowledged
    validates :acknowledged, presence: true
  end
  review label: "Review"

  def execute = succeed.with_message("Welcome aboard!")

  def authorize?                    # standalone wizards have no resource policy
    current_user.present?
  end
end
```

Gate a controller behind it:

```ruby
module AdminPortal
  class DashboardController < AdminPortal::PlutoniumController
    include Plutonium::Wizard::Gate
    ensure_wizard_completed ::WelcomeWizard
  end
end
```

Un-completed user → redirected into the wizard (destination stashed); on completion → bounced back (PRG). Completed users pass through. The gate recomputes the wizard's `instance_key` from its `concurrency_key` (resolved on the host controller — `current_user`/`current_scoped_entity`/`anchor`/custom available) and checks `completed?(instance_key:)`. Only one-time wizards are gateable. Use `concurrency_key { anchor }` for "set up this record once".

## Registration & launch (portal-hosted)

**(a) On a resource definition** — the `wizard` macro synthesizes the launch action AND auto-mounts the wizard's routes on the resource's own controller. Placement mirrors interactions: anchored → record (member) action, non-anchored → resource (collection) action; no bulk:

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard     # anchored → record action: /companies/:id/wizards/configure/:step
  wizard :onboard,   CompanyOnboardingWizard     # no anchor → resource action: /companies/wizards/onboard/:step
end
```

The anchored member action resolves its anchor through the resource controller's scoped, policy-gated `resource_record!` (IDOR-safe: out-of-scope / non-existent ids 404). Gate it with a policy predicate named after the wizard key (`def configure? = update?`).

**(b) Portal-level** — inside a portal engine's routes, alongside `register_resource`:

```ruby
AdminPortal::Engine.routes.draw do
  register_wizard ::OnboardOrganizationWizard, at: "onboarding"
  register_wizard ::WelcomeWizard, at: "welcome"
end
```

Draws `GET/POST /onboarding(/:token)/:step` within the portal + an `onboarding_wizard_path` helper.

> [!TIP]
> **`with:`-anchored wizards mount on the resource, not portal-level.** Register a `with:`-anchored wizard on the anchored resource's definition with the `wizard` macro — it auto-mounts a record (member) action whose anchor is the scoped `resource_record!`. Passing a `with:`-anchored wizard to `register_wizard` **raises** (no resource record). A **`via:`-anchored** (context) wizard mounts portal-level fine — its anchor is a controller method (e.g. `via: :current_scoped_entity`).

> [!DANGER]
> **A portal-level wizard with no `authorize?` is runnable by ANY authenticated portal user** — it has no resource policy and defaults to allowed. **Always define `def authorize?`** for anything privileged (admin-only, per-user gating, tenant checks).

## Authentication

**Auth is required by default** — entry without a `current_user` is rejected. Authenticated lookups are **owner-scoped**: a run id leaked in a URL can't be resumed by another logged-in user (foreign row → 404).

Opt into guest access with `anonymous`, and mount it on a **public route**:

```ruby
class GuestSignupWizard < Plutonium::Wizard::Base
  anonymous                         # runs pre-login; identity = a server-minted run-id in the Rails session
  step(:account) { attribute :email, :string; input :email; validates :email, presence: true }
  review label: "Review"
  def execute                       # the ONE boundary it may cross
    succeed(Account.create!(email: data.account.email))   # may also sign the user in (host calls Rodauth)
  end
end

# in a portal's routes — drawn on a public (unauthenticated) route automatically
register_wizard ::GuestSignupWizard, at: "signup", public: true
```

The guest run-id lives in the **Rails session** (`session["plutonium_wizards"][<wizard_key>]`) — **no cookie, no TTL** (the row's `cleanup_after` is the lifetime). It's browser-close ephemeral, **auto-cleared on login/logout** (Rodauth `reset_session`), cleared on completion, and **never in a URL**. Authenticated repeatable runs keep their URL `:token` segment instead (owner-scoped). **No mid-flow auth crossing**: a guest wizard never stamps an owner mid-flow or carries a token across login — it only ever authenticates at `execute`.

## Listing in-progress wizards

`Plutonium::Wizard.in_progress_for(view_context)` takes the `view_context` (as interactions do) and derives the run owner (`current_user`) and tenant scope (`current_scoped_entity` when `scoped_to_entity?`, else nil) from it, returning the user's in-progress runs (tenant-narrowed when scoped), newest-first, for a "continue where you left off" dashboard. Each entry exposes the wizard's `label`/`icon`, `current_step` (+ `current_step_label`), `updated_at`, and a `resume_url` (a real route for `register_wizard` and `wizard`-macro **anchored** mounts; `nil` + `resume_unresolved_reason` when the row lacks the identity to rebuild the URL — e.g. a non-anchored `wizard`-macro run). The low-level `Store#in_progress_for(owner, scope:)` takes `scope:` as a **required** keyword (no nil default).

## Storage & config

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.wizards.enabled = true            # false by default — required
  config.wizards.cleanup_after = 14.days   # global default sweep TTL
  config.wizards.database = :primary       # multi-db target
end
```

- One framework table `plutonium_wizard_sessions` (gem-shipped migration, runs in place on `rails db:migrate`). No changes to your models.
- DB-backed → resume across devices, in-progress listing, durable one-time markers.
- **`Plutonium::Wizard::SweepJob`** reaps idle sessions and rolls back tracked records. **Schedule it** (recurring job) — load-bearing for `on_submit` wizards; without it, abandoned mid-flow records accumulate forever.

## Common gotchas

- **Forgot `config.wizards.enabled`** → no table, nothing works.
- **Non-bang `create`/`update` in `execute`/`on_submit`** → silent advance, lost data. Use `create!`/`update!` or `fail!`.
- **`condition:` not nil-safe** → raises on the value before its step is filled.
- **`review` not last** → load-time error.
- **`using:` a definition or interaction** → `using:` is model-only.
- **`one_time` without `concurrency_key`** → raises (no stable row to retain).
- **Gating a non-one-time wizard** (`ensure_wizard_completed` on a repeatable wizard) → raises.
- **`on_submit` wizard without scheduled SweepJob** → abandoned partial records pile up.

## Related Skills

- [[plutonium-resource]] — the `attribute`/`input`/`validates`/`structured_input`/`form_layout` field DSL used inside a step.
- [[plutonium-behavior]] — Outcomes (`succeed`/`failed`), the Action system the `wizard` macro builds on, policies.
- [[plutonium-app]] — portal engines and `register_wizard` placement (alongside `register_resource`).
- [[plutonium-testing]] — integration-testing wizard flows.
