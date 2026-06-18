---
name: plutonium-wizard
description: Use BEFORE building any multi-step Plutonium flow — onboarding, checkout, multi-model create, branching questionnaire. Covers the wizard DSL (steps, branching, using:, review, per-step on_submit/persist/rollback, execute), anchoring & resume, one-time wizards + gate, registration (wizard macro + register_wizard), guest/anonymous flows, at-rest data encryption, and storage/config. The single source for "how do I build a wizard".
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
- **Wizards are portal- *or* main-app-hosted.** A `register_wizard` mount inside a portal inherits the portal's auth/scoping/layout. A `register_wizard` mount on the **main app** runs standalone — for an **authenticated** main-app wizard you MUST define your own `::WizardsController` (include `Plutonium::Wizard::Controller` + your auth concern); the synthesized fallback is **bare (no auth)**. Resource-anchored (`wizard` macro) wizards always run embedded on the resource controller.
- **Schedule `SweepJob`** (a periodic job/cron). It reaps abandoned/expired sessions — always good hygiene (stale `in_progress` rows pile up otherwise), and **load-bearing** for `on_submit`/`persist` wizards: it's the only thing that rolls back the partial domain records an abandoned save-as-you-go run leaves behind.

---

## 🛑 Before you author: confirm the configuration (ASK — don't infer)

Wizard configuration is dense and the dimensions **interact** — guess wrong about mounting, anchoring, or run identity and you get a wizard that compiles but misbehaves: it forks a new run on every visit, 404s on resume, leaks across tenants, or can't be gated. A one-line request ("a checkout wizard", "onboarding") does **not** determine these.

**STOP and ask the user — use `AskUserQuestion` — before writing the class.** Resolve each decision below (skip one only when the user already stated it), then restate the resolved shape in a sentence and confirm:

1. **End result — what does `execute` do?** Create a new record, update an existing one, touch several models, or fire a side effect (email/charge/API)? This drives anchoring *and* persistence.
2. **Anchored or fresh?** Does it operate on an **existing** record or create something new?
   - existing record from the URL → `anchored with: Model` (resource-mounted member route)
   - existing context (the tenant, the current user) → `anchored via: :current_scoped_entity`
   - brand new → non-anchored
3. **Mount, host & shell.** A resource action (`wizard` macro), a **portal** entry (`register_wizard` in a portal engine), or a **main-app** entry (`register_wizard` on the app)? Authenticated, or **public/guest pre-login** (`anonymous`, e.g. signup)? For a route mount, **shelled or shell-less** (`shell: true`/`false` — sidebar/topbar, or a bare standalone screen)? (Resource wizards are always embedded; an authenticated main-app wizard needs an app-defined `::WizardsController`.)
4. **Run identity.** Resume the user's **one** in-progress run (keyed — `concurrency_key`), or start a **fresh** run each launch (tokened/repeatable)? (Anchored wizards default to one run per `[anchor, current_user]`.)
5. **One-time?** Run at most once and keep a completed marker (`one_time`) — e.g. to **gate** a page behind it?
6. **Persistence model.** Write everything atomically at `execute` (default, simplest), or **save-as-you-go** with per-step `on_submit`/`persist` (then `SweepJob` must be scheduled, and `on_rollback` added for any *uncompensated* side effect)?
7. **Steps & branching.** Which steps/fields/validations? Any step shown only under a `condition:`?
8. **Tenancy.** Is the host portal entity-scoped? (The tenant folds into run identity automatically — don't thread it by hand.)

These compound: *anchored ⇒ keyed by default*; *anonymous ⇒ no owner ⇒ tokened*; *one-time ⇒ keyed + gateable*; *save-as-you-go ⇒ SweepJob + rollback*. Surface the implication when you confirm ("public ⇒ guest ⇒ session-keyed, ownerless"). The DSL sections below map each decision to its macro.

## ✅ Before you author: verify the ground truth (CHECK — read it, don't ask for it)

The ASK gate resolves the *design*; this confirms the app can actually *run* it. You have file access — inspect these yourself before writing the class (don't ask the user to confirm what you can read):

| Check | How | Why it matters |
|---|---|---|
| Subsystem enabled | grep `config/initializers/plutonium.rb` for `wizards.enabled = true`; confirm `plutonium_wizard_sessions` exists (`db:migrate`) | **OFF by default — without it nothing works** (the #1 gotcha) |
| Anchor model exists & reachable | Read the model an `anchored` wizard runs against | Missing/unreadable anchor ⇒ 404 / `NotAnchoredError` |
| Host portal exists & its scoping | Read the portal engine (`scope_to_entity`?) + its real module name | Tenant folds into run identity; a guessed portal name breaks `register_wizard` |
| Guest-flow prereqs | AR encryption keys if `encrypt_data`; no `concurrency_key`/`one_time` with `anonymous` | First write raises otherwise |
| `on_submit` ⇒ SweepJob scheduled | The recurring-job config | Abandoned mid-flow records pile up forever |

**Don't author the class until `config.wizards.enabled` is confirmed and the anchor/target model + portal are read.** Until then, any class you show is provisional — say so; don't present a guessed field/column mapping as final.

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
| `stepper false` | Hide the top rail (step indicator). On by default. |
| `on_relaunch :new` | Bare-relaunching a **tokened** wizard with pending runs shows a "resume or start new" chooser by default (`:prompt`) instead of silently forking; `:new` opts out (always fresh). No-op for keyed/`anonymous` (already auto-resume). |
| `anchored with: Model` / `anchored via: :method` | Run against an existing record (read via `anchor`). `with:` = URL `:id` (resource-mounted); `via:` = a controller method (portal-level, context). |
| `cleanup_after <ttl> \| :never` | Idle TTL before the sweep reaps the session + rolls back tracked records. Default `config.wizards.cleanup_after`. |
| `concurrency_key { … }` | Key a run by the returned value(s) (tenant folded in). The keyed `in_progress` row is the lock — a second launch resumes, never forks. Omit → unlimited `wizard_token`-keyed runs — **except `anchored`**, which defaults to `{ [anchor, current_user] }` (one draft per user per record). `{ anchor }` = one per record any-user; `{ wizard_token }` = repeatable. |
| `one_time` | Retain the completed row at the `concurrency_key` → run once (gate-able). **Requires `concurrency_key`.** Omit → row deleted on complete (repeatable). |
| `completed do \|wizard\| … end` | Custom body for the "already completed" page a finished **one-time** wizard shows when re-opened (replaces the default confirmation). |
| `encrypt_data` | Encrypt the staged `data` column at rest via ActiveRecord's encryption keys (PII flows). Requires `active_record.encryption` keys — first write raises (naming the wizard) if unconfigured. Unset inherits `config.wizards.encrypt_data` (global default, off); `encrypt_data false` opts out when that default is on. |
| `anonymous` | Opt into **guest (unauthenticated) access.** Default = auth required. A guest wizard may authenticate only at its terminal `execute`; never mid-flow. Mount it `public: true` (the default for `anonymous`). **Mutually exclusive with `concurrency_key`/`one_time`** — a guest's identity is its session token (already session-keyed/repeatable); whichever macro is declared last raises. |

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

Validations drive the form's field affordances just like a resource form: `presence` → the required marker (`*`); `length`/`numericality`/`format`/`inclusion` → `maxlength`/`min`/`max`/`pattern`/auto-choices. This holds for validations imported via `using:` too. (Structured-input sub-fields are the exception — they carry no validators, so no markers there.)

## The review step

```ruby
review label: "Review & submit"               # auto-summary + gated finish

review label: "Review & submit" do |wizard|   # custom content BELOW the summary
  "By submitting you agree to the #{wizard.data.plan.plan} plan terms."
end

review summary: false, header: false          # fully chromeless → "ready to complete" panel
```

Always lists invalid/unvisited steps as fix-this jump links; Finish disabled until all visible steps valid. Declares no fields. The body is a small state machine:

| State | Body |
|---|---|
| **Incomplete** | outstanding fix-this links **+** auto-summary of what's entered |
| **Complete**, `summary: true` (default) | auto-summary; custom block (if any) renders **below** it |
| **Complete**, `summary: false` + block | block **replaces** the summary |
| **Complete**, `summary: false`, no block | built-in "ready to complete" panel |

- `summary:` (default true) — show the auto-summary of completed steps. `false` hands the complete-state body to your block (or the "ready to complete" panel). The summary always shows in the incomplete state.
- `header:` (default true) — the step-header section (label + the "check everything over" prompt, shown only when the summary is). `false` drops it for a chromeless finish. Pair with `stepper false` for no chrome at all.

The custom block runs **in the Phlex view context** (`self` is the component), so it may return a String, emit Phlex (`div`, `render Component.new(...)`), and reach helpers via `helpers.*`; it's yielded the `wizard` (`data`/`anchor`/`persisted`/`current_user`). Don't both emit markup and return a String — Phlex renders the returned String too, double-rendering it.

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

Un-completed user → redirected into the wizard (destination stashed); on completion → bounced back (PRG). Completed users pass through. The gate recomputes the wizard's `instance_key` from its `concurrency_key` (resolved on the host controller — `current_user`/`current_scoped_entity`/custom available) and checks `completed?(instance_key:)`. Only one-time wizards are gateable. Use `concurrency_key { anchor }` for "set up this record once".

**Gating an anchored wizard:** the gate needs the anchor to recompute the key. A `via:`-anchored wizard is resolved automatically (the gate calls its `anchor_via` method on the controller); otherwise pass `ensure_wizard_completed Wizard, anchor: :method_or_proc`. An anchor it can't resolve raises (no silent loop). Anchor-keyed wizards are only gateable where the anchor is reconstructable.

**Re-opening a completed one-time wizard** doesn't re-run it (the retained row's `data` is cleared) — it renders an "already completed" page (success badge + label + Continue). Override the body with `completed do |wizard| … end`. Repeatable wizards have no completed page (re-launch starts fresh).

## Registration & launch

**(a) On a resource definition** — the `wizard` macro synthesizes the launch action AND auto-mounts the wizard's routes on the resource's own controller. Placement mirrors interactions: anchored → record (member) action, non-anchored → resource (collection) action; no bulk:

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard     # anchored → record action: /companies/:id/wizards/configure/:step
  wizard :onboard,   CompanyOnboardingWizard     # no anchor → resource action: /companies/wizards/onboard/:step
end
```

The anchored member action resolves its anchor through the resource controller's scoped, policy-gated `resource_record!` (IDOR-safe: out-of-scope / non-existent ids 404). Gate it with a policy predicate named after the wizard key (`def configure? = update?`).

**(b) Route-mounted** — `register_wizard`, in a **portal** engine's routes or on the **main app**, alongside `register_resource`:

```ruby
AdminPortal::Engine.routes.draw do
  register_wizard ::OnboardOrganizationWizard, at: "onboarding"               # portal, in-shell (default)
  register_wizard ::SetupOrgWizard, at: "setup", shell: false                 # portal, shell-less
end

Rails.application.routes.draw do
  register_wizard ::AppOnboardingWizard, at: "onboarding"                     # main app, shell-less (default)
end
```

Draws `GET /onboarding` (canonical launch) + `GET/POST /onboarding(/:token)/:step` + an `onboarding_wizard_path` helper, within the host (portal or app).

| `register_wizard` option | Meaning |
|---|---|
| `at:` (required) | Host-relative base path for the steps. |
| `as:` | Override the route-helper prefix (defaults to `at:`, then the wizard's name). |
| `public:` | Mount on a **public (unauthenticated)** route for an `anonymous` wizard. Defaults to the wizard's `anonymous?` flag. |
| `shell:` | Render inside the app shell? `true` (sidebar/topbar) or `false` (shell-less standalone). Default by host — portal → `true`, main-app → `false`. Turbo-frame requests are always layout-less regardless. |

### Hosting & the controller override hook

`register_wizard` dispatches to a wizard controller. **If you've defined one, it's used; otherwise it's synthesized** (same "app owns the controller" contract as `register_resource`):

| Host | Controller used | Auth |
|---|---|---|
| Portal | `<Portal>::WizardsController` if defined, else synthesized on the portal's `PlutoniumController` | the portal's (inherited) |
| Main app, **authenticated** | `::WizardsController` — **you must define it** | **yours** — `include Plutonium::Auth::Rodauth(:account)` |
| Main app, **public** (`anonymous`) | synthesized `::PublicWizardsController` (bare + `Auth::Public`) | none (guest) |

```ruby
# Authenticated main-app wizard ⇒ define the controller yourself.
class WizardsController < ApplicationController
  include Plutonium::Wizard::Controller          # the complete include surface (rendering + driving + view prefix)
  include Plutonium::Auth::Rodauth(:user)        # supplies current_user; the synthesized bare fallback has NONE
end
```

`Plutonium::Wizard::Controller` is the whole contract — including it on any base yields a renderable wizard controller (it pulls in `Core::Controller` and contributes the `"plutonium"` view prefix, so even a bare `ActionController::Base` host renders the shared partials). For an app that needs no custom auth base there's a ready-made `Plutonium::Wizard::BaseController` (`< ActionController::Base` + the module) to subclass. The module is the mechanism; the class is sugar.

> [!TIP]
> **`with:`-anchored wizards mount on the resource, not portal-level.** Register a `with:`-anchored wizard on the anchored resource's definition with the `wizard` macro — it auto-mounts a record (member) action whose anchor is the scoped `resource_record!`. Passing a `with:`-anchored wizard to `register_wizard` **raises** (no resource record). A **`via:`-anchored** (context) wizard mounts portal-level fine — its anchor is a controller method (e.g. `via: :current_scoped_entity`).

> [!DANGER]
> **A portal-level wizard with no `authorize?` is runnable by ANY authenticated portal user** — it has no resource policy and defaults to allowed. **Always define `def authorize?`** for anything privileged (admin-only, per-user gating, tenant checks).

## Authentication

**Auth is required by default** — entry without a `current_user` is rejected. Authenticated lookups are **owner-scoped**: a run id leaked in a URL can't be resumed by another logged-in user (foreign row → 404).

Where `current_user` comes from depends on the host: a **portal** mount inherits the portal's auth concern; a **main-app authenticated** mount needs the auth on your own `::WizardsController` (see *Hosting & the controller override hook* above — a bare synthesized main-app controller has no `current_user`, so a non-anonymous wizard there would be rejected by the auth gate). The wizard module supplies a `current_user` default that **defers to the host's auth concern** when present and is `nil` on a bare host.

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

`Plutonium::Wizard.in_progress_for(view_context)` (→ `Resume.entries_for(view_context)`) takes the `view_context` (as interactions do) and derives the run owner (`current_user`), tenant scope, and **portal** from it — returning that user's in-progress runs **for the current portal**, newest-first, for a "continue where you left off" dashboard. A run is only ever listed (and linked) by the portal it was launched in: a non-scoped portal lists only unscoped runs, a scoped portal narrows to the current tenant. (Two portals can share an entity scope, so the launching portal — the `engine` — is recorded per-run; scope alone can't identify it.)

Each entry exposes the wizard's `label`/`icon`, `current_step` (+ `current_step_label`), `updated_at`, the raw `session` row, and a `resume_url` built through the **current portal's** routes — `resource_url_for(record, wizard:, step:)` for a `wizard`-macro **anchored** mount, the named route for a `register_wizard` mount; `nil` + `resume_unresolved_reason` when the row can't be resolved here (e.g. a non-anchored `wizard`-macro run). **Narrowing.** For the per-record / per-wizard resume widget ("does this record have an unfinished draft of wizard X?"), pass the optional `anchor:`/`wizard:` filters — they narrow **in the query, before enrichment**, so discarded rows are never URL-resolved or anchor-loaded (cheaper than `select`-ing the array, which enriches every row first). They compose, and the `wizard + anchor` pair is index-covered: `…in_progress_for(vc, wizard: ConfigureCompanyWizard, anchor: company).first`. Don't reach into `e.session.anchor` to filter (a polymorphic load per row). For ad-hoc post-filtering the array still works — `e.wizard_class` is already on each entry.

## Storage & config

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.wizards.enabled = true            # false by default — required
  config.wizards.cleanup_after = 14.days   # global default sweep TTL
  config.wizards.encrypt_data = false      # encrypt every wizard's data at rest (needs AR encryption keys)
  config.wizards.database = :primary       # reserved — v1 supports :primary only (else raises at boot)
end
```

- One framework table `plutonium_wizard_sessions` (gem-shipped migration, runs in place on `rails db:migrate`). No changes to your models.
- DB-backed → resume across devices, in-progress listing, durable one-time markers.
- **`Plutonium::Wizard::SweepJob`** (an `ActiveJob`) reaps idle/expired sessions and rolls back their tracked records. **Schedule it** for every wizard app — stale rows pile up otherwise, and for `on_submit`/`persist` wizards it's the *only* thing that rolls back abandoned mid-flow records. In a Solid Queue app (`rails g pu:lite:solid_queue` sets up the backend), add it to `config/recurring.yml`:

  ```yaml
  # config/recurring.yml
  wizard_sweep:
    class: Plutonium::Wizard::SweepJob
    schedule: every 15 minutes
  ```

  (Or any recurring mechanism your app already has — sidekiq-cron, `whenever`, a cron'd rake task. `perform` takes no required args.)

## Common gotchas

- **Forgot `config.wizards.enabled`** → no table, nothing works.
- **Non-bang `create`/`update` in `execute`/`on_submit`** → silent advance, lost data. Use `create!`/`update!` or `fail!`.
- **`condition:` not nil-safe** → raises on the value before its step is filled.
- **`review` not last** → load-time error.
- **`using:` a definition or interaction** → `using:` is model-only.
- **`one_time` without `concurrency_key`** → raises (no stable row to retain).
- **`anonymous` + `concurrency_key`/`one_time`** → raises (a guest is already session-keyed; whichever is declared last raises).
- **`encrypt_data` without AR encryption keys** → first write raises (naming the wizard). Run `bin/rails db:encryption:init`.
- **Gating a non-one-time wizard** (`ensure_wizard_completed` on a repeatable wizard) → raises.
- **`on_submit` wizard without scheduled SweepJob** → abandoned partial records pile up.

## Related Skills

- [[plutonium-resource]] — the `attribute`/`input`/`validates`/`structured_input`/`form_layout` field DSL used inside a step.
- [[plutonium-behavior]] — Outcomes (`succeed`/`failed`), the Action system the `wizard` macro builds on, policies.
- [[plutonium-app]] — portal engines and `register_wizard` placement (alongside `register_resource`).
- [[plutonium-testing]] — integration-testing wizard flows.
