# frozen_string_literal: true

#
# Sample wizards illustrating the Plutonium::Wizard DSL.
# Companion to docs/superpowers/specs/2026-06-15-wizard-dsl-design.md.
# Illustrative only — the subsystem isn't built yet, so this won't load/run.
#
# ── DSL cheatsheet ───────────────────────────────────────────────────────────
#   presents label:/icon:        chrome (button label + icon), like interactions
#   navigation :linear|:free     stepper navigation policy (default :linear)
#   anchored with: Model         wizard runs against an existing record (URL :id); read via `anchor`
#   anchored via: :method        context anchor resolved by a controller method (portal-level)
#   concurrency_key { … }        key a run (tenant folded in); keyed in_progress row is the lock
#   one_time                     retain the completed row at the key → run once (needs concurrency_key)
#   cleanup_after 7.days|:never   idle TTL before abandoned sessions are swept
#   anonymous                    opt into guest (unauthenticated) access; mount public: true.
#                                auth is REQUIRED by default; authed lookups are owner-scoped.
#                                a guest wizard may authenticate ONLY at its terminal execute.
#   def authorize?              entry gate for portal-level wizards (no resource policy)
#   step :key, label:, condition:, using:  do ... end   one screen (block declares its
#                                fields/hooks); condition: gates it (branching). The block
#                                is optional only when `using:` supplies everything.
#     attribute/input/validates/structured_input/form_layout  the existing field DSL (in the block)
#     on_submit { ... }          OPTIONAL per-step write hook (save-as-you-go)
#       persist record           inside on_submit: register record(s) → persisted[:key]
#       fail!("msg")             abort the step with an error (sugar over StepError)
#     on_rollback { ... }        OPTIONAL extra cleanup of untracked side effects on cancel/abandon
#                                (persist'd records are ALWAYS destroyed by the engine regardless)
#   review label:                terminal step: auto-summary + gated Finish
#   def execute                  at-end hook; returns succeed(...) / failed(...) (an Outcome)
#   data.<field>                 typed, dot-accessible snapshot of everything entered so far
#   anchor / persisted[:key]     the launched-against record / records created via persist
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────────────────────────────────────
# 1. Create flow — execute-only, multi-model, branching.
#    Nothing is written until the end; `execute` does all writes in one
#    transaction. Branching is subtractive via `condition:` (nil-safe).
# ─────────────────────────────────────────────────────────────────────────────
class CompanyOnboardingWizard < Plutonium::Wizard::Base
  # `presents` sets the launch button's label + icon (same as interactions).
  presents label: "Onboard a company", icon: Phlex::TablerIcons::BuildingSkyscraper

  # Stepper behaviour. :linear = forward + back to visited steps (default).
  navigation :linear

  # A `step` is one screen. The block declares its fields with the existing
  # field DSL (attribute = typed data, input = how it renders, validates = rules).
  step :company, label: "Company details" do
    attribute :name, :string
    attribute :subdomain, :string
    input :name
    input :subdomain
    validates :name, :subdomain, presence: true

    # Optional: section THIS step's fields (reuses form_layout, scoped to the step).
    form_layout do
      section :identity, :name, :subdomain, label: "Identity", columns: 2
    end
  end

  step :plan, label: "Plan" do
    attribute :plan, :string
    input :plan, as: :radio_buttons, choices: %w[free pro]
    validates :plan, presence: true
  end

  # `condition:` decides whether this step is included (subtractive branching).
  # It runs against the typed `data` snapshot; `data.plan` is nil until the plan
  # step is filled, and `nil == "pro"` is false — so it must be written nil-safe.
  step :billing, label: "Billing", condition: -> { data.plan == "pro" } do
    attribute :card_token, :string
    input :card_token
    validates :card_token, presence: true
  end

  step :team, label: "Invite your team" do
    # `structured_input ..., repeat:` = a repeatable group of sub-fields.
    # Reachable later as data.invites (an array of typed sub-objects).
    structured_input :invites, repeat: 5 do |f|
      f.input :email, as: :email
      f.input :role, as: :select, choices: %w[admin member]
    end
  end

  # `review` is a built-in terminal step: auto-summarises everything entered and
  # gates the Finish button until all visible steps are valid. Must be last.
  review label: "Review & submit"

  # `execute` runs once at the end, in one transaction. Use bang methods so a
  # failure raises → the engine rolls back and re-renders with the error.
  # Return an Outcome: succeed(value) / failed(errors).
  def execute
    company = Company.create!(name: data.name, subdomain: data.subdomain, plan: data.plan)
    Billing.create!(company:, token: data.card_token) if data.plan == "pro"
    data.invites.each { |i| company.invites.create!(email: i.email, role: i.role) }
    succeed(company).with_message("You're all set!")   # with_message → flash
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. Anchored, save-as-you-go flow with field reuse + cleanup.
#    Launched against an existing Company (the `anchor`). Uses `using:` to import
#    a definition's fields/validations/layout instead of re-declaring them, and
#    per-step `on_submit`/`persist`/`on_rollback` to write as it goes.
# ─────────────────────────────────────────────────────────────────────────────
class ConfigureCompanyWizard < Plutonium::Wizard::Base
  presents label: "Configure", icon: Phlex::TablerIcons::Settings

  # `anchored with:` binds the wizard to an existing record; `anchor` returns it.
  # (Calling `anchor` on a non-anchored wizard raises NotAnchoredError.)
  anchored with: Company

  # Idle sessions are swept after this long (records created so far are rolled
  # back). Use :never to keep partial records indefinitely.
  cleanup_after 7.days

  # `using:` imports a field surface from a model (types + validations from the
  # model; input styling from its auto-resolved CompanyDefinition) — no need to
  # re-declare. `fields:` selects a subset. Persistence stays wizard-side; only
  # the declarations are reused.
  step :branding, label: "Branding", using: Company, fields: %i[logo brand_color]

  step :billing, label: "Billing", condition: -> { anchor.paid_plan? } do
    attribute :card_token, :string
    input :card_token
    validates :card_token, presence: true

    # `on_submit` runs when THIS step completes (opt-in save-as-you-go).
    on_submit do
      charge = PaymentApi.authorize!(anchor, data.card_token)
      fail!("Card was declined") unless charge.ok?            # abort with a base error
      # `persist` registers the record for resume + cleanup → persisted[:billing]
      persist Billing.create!(company: anchor, token: data.card_token, charge_id: charge.id)
    end

    # ADDITIONAL cleanup if the wizard is cancelled/abandoned. The engine ALWAYS
    # destroys the persisted Billing record on rollback — on_rollback is only for
    # side effects the engine can't see (here: refunding the external charge). It
    # runs BEFORE the destroy, so `persisted[:billing]` is still alive to read.
    on_rollback { PaymentApi.refund!(persisted[:billing].charge_id) }
  end

  def execute
    anchor.update!(configured_at: Time.current)
    succeed(anchor).with_message("Company configured.")
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. One-time, standalone onboarding (no anchor).
#    Mounted on its own route; gated so a user only sees it until completed.
# ─────────────────────────────────────────────────────────────────────────────
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"

  # Keyed per user (tenant folded in); `one_time` retains the completed row as a
  # durable "done" marker the gate (below) checks — so it never re-runs.
  concurrency_key { current_user }
  one_time

  # Portal-level wizards have no resource policy, so gate entry with `authorize?`.
  def authorize? = current_user.present?

  step :profile, label: "Your profile" do
    attribute :full_name, :string
    attribute :timezone, :string
    input :full_name
    input :timezone, as: :select, choices: ActiveSupport::TimeZone.all.map(&:name)
    validates :full_name, presence: true
  end

  step :preferences, label: "Preferences" do
    attribute :newsletter, :boolean, default: true
    input :newsletter, as: :toggle
  end

  review label: "All set?"

  def execute
    current_user.update!(
      full_name: data.full_name, timezone: data.timezone,
      newsletter: data.newsletter, onboarded_at: Time.current
    )
    succeed.with_message("Welcome aboard!")
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# 4. Guest (anonymous) signup — runs PRE-LOGIN, mounted on a public route.
#    Auth is required by default; `anonymous` opts out. A guest run's identity is
#    a server-minted, unguessable cookie (httponly/secure/same_site, cleared on
#    completion). The wizard NEVER crosses the auth boundary mid-flow — the only
#    boundary it may cross is its terminal `execute` (here: create + sign in).
# ─────────────────────────────────────────────────────────────────────────────
class GuestSignupWizard < Plutonium::Wizard::Base
  presents label: "Sign up"

  anonymous # may run without a current_user

  step :account do
    attribute :email, :string
    attribute :password, :string
    input :email, as: :email
    input :password, as: :password
    validates :email, :password, presence: true
  end

  review label: "Review"

  def execute
    account = Account.create!(email: data.email, password: data.password)
    # A real signup would sign the account in here (the host calls Rodauth, which
    # rotates the Rails session) — no special framework handling is needed.
    succeed(account).with_message("Welcome!")
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Registration
# ─────────────────────────────────────────────────────────────────────────────

# (a) On a resource definition — the `wizard` macro synthesizes the launch
#     action. Placement mirrors interactions: anchored → record action (per row);
#     no anchor → resource/collection action (index header).
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard          # anchored → record action
  wizard :onboard, CompanyOnboardingWizard           # no anchor → collection action
end

# (b) Portal-level — inside a portal engine's routes (alongside register_resource).
#     Runs within the portal (auth/scoping/layout inherited). Portal-relative path.
#   register_wizard WelcomeWizard, at: "welcome"
#
#     A guest (anonymous) wizard mounts on a PUBLIC route (drawn on the main app,
#     outside the portal's auth constraint, so it's reachable pre-login).
#     public: true is the default for an anonymous wizard.
#   register_wizard GuestSignupWizard, at: "signup", public: true

# (c) Gating the one-time wizard — in a portal/ApplicationController. Redirects
#     the user into the wizard until completed, then bounces them back.
#   class DashboardController < PlutoniumController
#     ensure_wizard_completed WelcomeWizard
#   end
