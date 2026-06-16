# Wizards

Build multi-step flows — onboarding, checkout, "create several related records across screens", branching questionnaires — as a single declarative Ruby class.

A wizard collects typed `data` across ordered `step`s, optionally branches with `condition:`, and commits at the end via `execute`. It reuses Plutonium's existing field DSL (`attribute`/`input`/`validates`/`structured_input`/`form_layout`), form rendering, actions, and policies — it does **not** invent a parallel stack.

## Goal

The user lands on the first step, fills it in, clicks Next, and walks through the flow. Branching steps appear or disappear based on earlier answers. A built-in review step recaps everything and gates a Finish button. On finish, `execute` writes the records — atomically by default.

## Prerequisites — enable the subsystem

Wizards are core code, but the storage table is **opt-in** so apps that don't use wizards stay schema-clean. Enable it in your Plutonium initializer:

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.wizards.enabled = true            # false by default; registers the gem migration
  config.wizards.cleanup_after = 14.days   # global default idle TTL for the sweep
  config.wizards.database = :primary       # which DB the wizard table lives on (multi-db)
end
```

Then run the migration (it ships in the gem and runs in place — no copy step):

```bash
rails db:migrate
```

This creates the single framework table `plutonium_wizard_sessions`. See [Storage & config](/reference/wizard/storage-config) for the full story.

::: warning Schedule the SweepJob for save-as-you-go wizards
For plain `execute`-only wizards, leaving the sweep unscheduled only leaves stale session rows (harmless). But if you use per-step `on_submit` (which creates **real records mid-flow**), `Plutonium::Wizard::SweepJob` is the **only** thing that cleans up abandoned partial records. Schedule it as a recurring job. See [Storage & config](/reference/wizard/storage-config#sweepjob).
:::

## A minimal wizard

The common case writes nothing until the end. Steps collect `data`; one `execute` does all the writes in a single transaction.

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
    company = Company.create!(name: data.name, subdomain: data.subdomain, plan: data.plan)
    succeed(company).with_message("You're all set!")
  end
end
```

- A wizard is a plain class — `< Plutonium::Wizard::Base`. There is no generator (just like interactions); author it by hand.
- `presents label:/icon:` sets the launch button's label and icon, exactly like interactions.
- Each `step :key, label: do ... end` is one screen. Inside the block, declare its fields with the same DSL you use on a definition or interaction.
- `data.name` reads the **typed** value the user entered (cast to the declared type), available from any step and from `execute`.
- `review` is a built-in terminal step (auto-summary + gated Finish). It must be **last**.
- `execute` runs once at the end and returns an `Outcome` (`succeed(...)` / `failed(...)`). **Use bang methods** (`create!`/`update!`) — failure is signalled by a raised exception, never a return value.

::: warning Use bang methods in `execute`
The engine detects failure by a **raised exception**. Non-bang `create`/`save`/`update` return `false` on failure without raising — the engine can't see that, treats the step as successful, and advances, silently losing the data. Always use `create!`/`update!`/`save!`, or call `fail!("message")`.
:::

## Branching with `condition:`

A step's `condition:` lambda decides whether the step is included. Branching is **subtractive** — a falsy `condition:` removes the step from the visible path.

```ruby
step :plan, label: "Plan" do
  attribute :plan, :string
  input :plan, as: :radio_buttons, choices: %w[free pro]
  validates :plan, presence: true
end

# Only shown when the user picked "pro".
step :billing, label: "Billing", condition: -> { data.plan == "pro" } do
  attribute :card_token, :string
  input :card_token
  validates :card_token, presence: true
end
```

::: warning `condition:` lambdas must be nil-safe
A `condition:` runs against the typed `data` snapshot at **every** transition — including before its deciding step has been filled, when the value is still `nil`. `-> { data.plan == "pro" }` is fine (`nil == "pro"` is `false`); `-> { data.plan.upcase == "PRO" }` raises on `nil`. Always write conditions that tolerate `nil`.
:::

The condition can also read `anchor` (for [anchored wizards](#anchored-wizards)). Data belonging to branch-hidden steps is pruned before `execute`, so `execute` only ever sees data for steps that actually applied.

## Reusing a model's fields — `using:`

Instead of re-declaring fields a model already defines, import them with `using:`. It is a **step option** (not a block method), and it targets a **model (record class) only**.

```ruby
# Whole-step import — no block needed.
step :branding, label: "Branding", using: Company, fields: %i[logo brand_color]

# Mix imported + wizard-local fields: using: plus a block for the extras.
step :details, label: "Details", using: Company, only: %i[tagline] do
  attribute :referral_code, :string
  input :referral_code
end
```

What `using:` imports from the model:

- **Field universe + types** from `Model.attribute_names` / `Model.attribute_types`. Selectors `fields:` (alias `only:`) and `except:` pick a subset.
- **Input styling** overlaid from the auto-resolved `<Model>Definition` (its `as:`, options, labels) — best-effort; no definition found is fine.
- **Validations** run via a transient `Model.new(slice).valid?`, keeping errors on the imported fields plus `:base`. Pass `validate: false` to skip and write your own inline `validates`.
- **`form_layout`** inherited from the `<Model>Definition` (filtered to imported fields). Pass `layout: false` to opt out.

`using:` is **declaration reuse only** — it never pulls in the model's persistence or callbacks. Data still stages into `data`; your `execute` does the writes. Full detail: [DSL reference › `using:`](/reference/wizard/dsl#using-a-model).

## Sectioning a step — `form_layout`

A step is its own form, so you can group its fields with the same `form_layout` DSL you use on a definition, scoped to that step:

```ruby
step :company, label: "Company details" do
  attribute :name, :string
  attribute :subdomain, :string
  input :name
  input :subdomain
  validates :name, :subdomain, presence: true

  form_layout do
    section :identity, :name, :subdomain, label: "Identity", columns: 2
  end
end
```

## Repeatable / structured fields

Because a step uses the existing form pipeline, `structured_input` works inside a step. The values land in `data.<name>` as an array of typed sub-objects:

```ruby
step :team, label: "Invite your team" do
  structured_input :invites, repeat: 5 do |f|
    f.input :email, as: :email
    f.input :role, as: :select, choices: %w[admin member]
  end
end

def execute
  company = Company.create!(name: data.name)
  data.invites.each { |i| company.invites.create!(email: i.email, role: i.role) }
  succeed(company)
end
```

Repeater rows rehydrate from staged `data` on GET, so navigating back (or resuming) re-renders the rows you already filled.

## The review step

`review` is a built-in terminal step. It:

- Renders a read-only auto-summary of every visible step's data (reusing display components).
- Lists invalid/unvisited visible steps as "fix this" jump links.
- Disables Finish until all visible steps are valid; clicking it runs `execute`.

```ruby
review label: "Review & submit"

# Or with custom content after the auto-summary:
review label: "Review & submit" do |wizard|
  "By submitting you agree to the #{wizard.data.plan} plan terms."
end
```

## Per-step writes — `on_submit` / `persist` / `on_rollback`

`execute` is the default — atomic, no orphans. Reach for per-step `on_submit` **only** when a real record must exist mid-flow (handing off to an external system that webhooks back, a reviewer who must see partial data, a payload too large for the session row).

```ruby
class ConfigureCompanyWizard < Plutonium::Wizard::Base
  anchored with: Company
  cleanup_after 7.days

  step :billing, label: "Billing", condition: -> { anchor.paid_plan? } do
    attribute :card_token, :string
    input :card_token
    validates :card_token, presence: true

    # Runs when THIS step completes (opt-in save-as-you-go), in its own transaction.
    on_submit do
      charge = PaymentApi.authorize!(anchor, data.card_token)
      fail!("Card was declined") unless charge.ok?   # → base error, stays on step
      # `persist` registers the record for resume + cleanup → persisted[:billing]
      persist Billing.create!(company: anchor, token: data.card_token, charge_id: charge.id)
    end

    # ADDITIONAL cleanup on Cancel/abandonment. The engine ALWAYS destroys the
    # persist'd Billing record — on_rollback is only for side effects it can't see
    # (here, refunding the external charge). It runs BEFORE the destroy, so
    # persisted[:billing] is still alive to read.
    on_rollback { PaymentApi.refund!(persisted[:billing].charge_id) }
  end

  def execute
    anchor.update!(configured_at: Time.current)
    succeed(anchor).with_message("Company configured.")
  end
end
```

- `on_submit` runs in its own transaction when the step completes. Inside it, `persist record` registers record(s) the engine tracks for resume and cleanup — reachable later as `persisted[:step_key]`.
- `fail!("msg")` aborts the step with a base (form-level) error; `fail!(:field, "msg")` attaches it to a field. Both roll back the step's transaction and re-render with input intact.
- The engine **always** destroys every `persist`'d record on rollback (Cancel, abandonment-sweep, branch-prune), in reverse order, via `destroy!` (which respects a model's own soft-delete override). `on_rollback` is an **optional, additive** compensating block for side effects the engine can't see — refund a charge, call an external API — and runs **before** the destroy, so `persisted[:key]` is still alive inside it. Don't destroy the tracked record yourself; the engine does.
- Because `on_submit` writes mid-flow, it isn't atomic across steps — that's why `cleanup_after` + the SweepJob exist. See [Storage & config](/reference/wizard/storage-config) and the [DSL reference](/reference/wizard/dsl#per-step-hooks).

## Anchored wizards

An **anchored** wizard runs against an existing record (like `attribute :resource` on an interaction). Read it via `anchor`.

```ruby
class ConfigureCompanyWizard < Plutonium::Wizard::Base
  anchored with: Company      # operate on a Company

  step :branding, label: "Branding", using: Company, fields: %i[logo brand_color]

  def execute
    anchor.update!(configured_at: Time.current)
    succeed(anchor)
  end
end
```

- `anchored with: Company` → a single type. `anchored with: [Company, Organization]` → polymorphic. `anchored` (no `with:`) → generic, bound at registration.
- `anchor` raises `Plutonium::Wizard::NotAnchoredError` if the wizard wasn't declared `anchored` — it never returns `nil`.
- Omit `anchored` for a pure create flow (the wizard creates the records it names itself).

See [Anchoring & resume](/reference/wizard/anchoring-resume).

## One-time onboarding + gate

A one-time wizard is a keyed wizard (`concurrency_key`) that **retains** its completed row as a durable marker. A controller gate redirects users into it until they finish.

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"

  concurrency_key { current_user }   # the stable row to retain (tenant folded in)
  one_time                            # retain on completion → run once

  step :profile, label: "Your profile" do
    attribute :full_name, :string
    input :full_name
    validates :full_name, presence: true
  end

  review label: "All set?"

  def execute
    current_user.update!(full_name: data.full_name, onboarded_at: Time.current)
    succeed.with_message("Welcome aboard!")
  end

  # Standalone wizards have no resource policy — gate entry with `authorize?`.
  def authorize?
    current_user.present?
  end
end
```

Gate a controller behind it with the `Plutonium::Wizard::Gate` concern:

```ruby
module AdminPortal
  class DashboardController < AdminPortal::PlutoniumController
    include Plutonium::Wizard::Gate
    ensure_wizard_completed ::WelcomeWizard
  end
end
```

An un-completed user hitting the gate is redirected into the wizard (their destination stashed); on completion they're bounced back (PRG). Completed users pass straight through. See [One-time wizards](/reference/wizard/one-time).

## Registration & launch

Wizards are **portal-hosted** — they run inside a Plutonium portal, inheriting its auth, tenant scoping, layout, and rendering. There are two ways to reach a user.

### On a resource — the `wizard` macro

Register a wizard on a resource definition with the `wizard` macro. It synthesizes the launching action and **auto-mounts the wizard's routes on the resource's own controller** — placement mirrors interactions: anchored → record (member) action, non-anchored → resource (collection) action. Bulk wizards are not supported.

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard     # anchored → record action (/companies/:id/wizards/configure/:step)
  wizard :onboard,   CompanyOnboardingWizard     # no anchor → resource action (/companies/wizards/onboard/:step)
end
```

::: tip Anchored wizards are IDOR-safe
An anchored (record) wizard resolves its anchor through the resource controller's scoped, policy-gated `resource_record!` — the same lookup CRUD and interactive record actions use. A record outside the portal's authorized scope (another tenant's, or a non-existent id) **404s**; it's never loaded via an unscoped `find_by`. Gate it with a policy predicate named after the wizard key (`def configure? = update?`).
:::

::: danger Portal-level wizards are open to any authenticated user by default
A portal-level wizard with no `authorize?` can be run by **any authenticated portal user** — it has no resource policy. Always define `def authorize?` for anything privileged.
:::

### Portal-level — `register_wizard`

For a wizard not tied to a single resource (onboarding, welcome), register it inside the portal engine's routes, alongside `register_resource`:

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  register_wizard ::OnboardOrganizationWizard, at: "onboarding"
  register_wizard ::WelcomeWizard, at: "welcome"

  register_resource ::Company
end
```

This draws the wizard's step routes within the portal and provides an `<at>_wizard_path` helper. See [Registration & launch](/reference/wizard/registration-launch).

### Authentication & guest wizards

**Wizards require authentication by default** — entering without a `current_user` is rejected, and every resume is **owner-scoped** (a run id leaked in a URL can't be picked up by another logged-in user). A wizard **never crosses the auth boundary mid-flow**.

Opt into guest access with the `anonymous` macro, and mount it on a **public route** (pre-login). The guest run's identity is a server-minted, unguessable id held in the **Rails session**, namespaced per wizard (`session["plutonium_wizards"][<wizard_key>]`) — **not a cookie, and with no TTL**. The row's `cleanup_after` → sweep is the authoritative lifetime; the session id is just a pointer to it. Session storage means the id is browser-close ephemeral, **auto-cleared on login/logout** (Rodauth's `clear_session` → `reset_session`), and cleared on completion — and it never appears in a URL, so there is no leak surface. Its terminal `execute` is the *only* place a guest wizard may authenticate (e.g. a signup that creates the account and logs the user in — the host calls Rodauth, which rotates the session):

```ruby
class GuestSignupWizard < Plutonium::Wizard::Base
  anonymous

  step :account do
    attribute :email, :string
    input :email, as: :email
    validates :email, presence: true
  end
  review label: "Review"

  def execute
    succeed(Account.create!(email: data.email))   # may also sign the user in here
  end
end

# in the portal's routes — public: true is the default for anonymous wizards
register_wizard ::GuestSignupWizard, at: "signup", public: true
```

Because the portal engine is mounted behind the host's auth constraint, an `anonymous` wizard's route is drawn on the **main app** (outside that constraint) so it's reachable before login. See [Authentication](/reference/wizard/anchoring-resume#authentication) and the [public mount](/reference/wizard/registration-launch#public-mount-for-anonymous-wizards).

::: warning v1 scope
v1 hosts wizards **inside portals only**. `with:`-anchored wizards mount on the resource via the `wizard` macro (member action, anchor = scoped `resource_record!`); `register_wizard` raises for a `with:`-anchored wizard (portal-level mounts have no resource record), but a `via:`-anchored (context) wizard mounts portal-level fine. Main-app (non-portal) standalone wizards are out of scope. See [Registration & launch › Known limitations](/reference/wizard/registration-launch#known-limitations).
:::

### Listing in-progress wizards

Build a "continue where you left off" dashboard with `Plutonium::Wizard.in_progress_for`. Like interactions, it takes the `view_context` and derives the run owner (`current_user`) and tenant scope (`current_scoped_entity`, when the portal is entity-scoped) from it — so it stays tenant-aware automatically. It returns the user's in-progress runs, each enriched for a list item:

```ruby
entries = Plutonium::Wizard.in_progress_for(view_context)

entries.each do |entry|
  entry.label               # the wizard's presents label
  entry.icon                # the wizard's presents icon
  entry.current_step        # the step key the run is paused on
  entry.current_step_label  # that step's label (if resolvable)
  entry.updated_at          # last activity (entries are newest-first)
  entry.resume_url          # a route back into the run, or nil (see below)
end
```

`resume_url` is resolved from the run's mount:

- A `register_wizard` (portal/public) wizard resolves to its named route, threading the tenant scope segment and — for a tokened (no `concurrency_key`) run — the per-run `:token`.
- A `wizard`-macro **anchored** wizard resolves to its resource member route, rebuilt from the row's anchor.

When a mount can't be resolved generically — e.g. a non-anchored `wizard`-macro run, whose resource identity isn't recorded on the row — `resume_url` is `nil` and `entry.resume_unresolved_reason` explains why (render those entries without a resume link rather than guessing).

Under the hood, `in_progress_for(view_context)` derives `owner`/`scope` and calls the low-level query `Store#in_progress_for(owner, scope:)`, where `scope:` is a **required** keyword (no `nil` default): a non-nil scope narrows to that tenant, and an explicit `nil` (non-scoped portal) applies no scope filter. Call it directly only when you already have an owner and have decided the scope explicitly.

## Where to go next

- [DSL reference](/reference/wizard/dsl) — every macro and accessor.
- [Anchoring & resume](/reference/wizard/anchoring-resume) — anchors, instance keys, resume.
- [Storage & config](/reference/wizard/storage-config) — the table, config, encryption, the sweep.
- [Registration & launch](/reference/wizard/registration-launch) — the `wizard` macro, `register_wizard`, routes.
- [One-time wizards](/reference/wizard/one-time) — completion markers + the gate.
