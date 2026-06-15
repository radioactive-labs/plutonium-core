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

    # How to undo this step on Cancel/abandonment. Omit it and the engine just
    # destroys the tracked record(s).
    on_rollback { persisted[:billing].destroy! }
  end

  def execute
    anchor.update!(configured_at: Time.current)
    succeed(anchor).with_message("Company configured.")
  end
end
```

- `on_submit` runs in its own transaction when the step completes. Inside it, `persist record` registers record(s) the engine tracks for resume and cleanup — reachable later as `persisted[:step_key]`.
- `fail!("msg")` aborts the step with a base (form-level) error; `fail!(:field, "msg")` attaches it to a field. Both roll back the step's transaction and re-render with input intact.
- `on_rollback` is the compensating block run on Cancel or abandonment-sweep. Omitted, the engine destroys the tracked records (reverse order).
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

A one-time wizard runs once per user (or per anchor) and records a durable completion marker. A controller gate redirects users into it until they finish.

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"
  one_time once_per: :user      # :user (default) | :anchor

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

Register a wizard on a resource definition with the `wizard` macro. It synthesizes the launching action; placement mirrors interactions (anchored → record action, no anchor → resource/collection action). Bulk wizards are not supported.

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard      # anchored → record action
  wizard :onboard,   CompanyOnboardingWizard      # no anchor → resource action
end
```

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

::: warning v1 scope
v1 hosts wizards **inside portals only**. Anchored *resource member routes* (`/companies/:id/wizards/...`) are a follow-up — the portal-level path is the primary one. `once_per: :anchor` gating needs a host-provided anchor resolver (override `wizard_gate_anchor`). Main-app (non-portal) standalone wizards are out of scope. See [Registration & launch › Known limitations](/reference/wizard/registration-launch#known-limitations).
:::

## Where to go next

- [DSL reference](/reference/wizard/dsl) — every macro and accessor.
- [Anchoring & resume](/reference/wizard/anchoring-resume) — anchors, instance keys, resume.
- [Storage & config](/reference/wizard/storage-config) — the table, config, encryption, the sweep.
- [Registration & launch](/reference/wizard/registration-launch) — the `wizard` macro, `register_wizard`, routes.
- [One-time wizards](/reference/wizard/one-time) — completion markers + the gate.
