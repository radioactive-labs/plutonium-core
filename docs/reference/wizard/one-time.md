# One-time wizards

A **one-time** wizard runs once — for onboarding, a one-shot setup, a "welcome" flow. It needs a durable completion marker (you can't remember "done forever" in a session), which the DB store provides as a `completed` session row.

## Declaring `one_time`

A one-time wizard is a **keyed** wizard (`concurrency_key`) that **retains** its completed row instead of deleting it. So `one_time` always pairs with a `concurrency_key` — the stable key the retained marker lives at (and the key the gate recomputes).

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  presents label: "Welcome"

  concurrency_key { current_user }   # the stable row to retain (tenant folded in)
  one_time                            # retain the completed row → never again

  step :greeting do
    attribute :acknowledged, :string
    input :acknowledged
    validates :acknowledged, presence: true
  end

  review label: "Review"

  def execute
    succeed.with_message("Welcome aboard!")
  end
end
```

- **Completion** = the instance row reaching `status: completed`, **retained** at the wizard's `instance_key`.
- **`one_time` requires a `concurrency_key`** — declaring `one_time` without one raises (there's no stable row to retain). A wizard without `one_time` deletes its row on completion (repeatable).
- **`concurrency_key { current_user }`** keys completion per user; **`concurrency_key { anchor }`** keys it per anchored record ("set up *this* workspace once"). The **tenant (`current_scoped_entity`) is folded in automatically**, so in a tenant portal it's per-(user, tenant) for free.
- On completion, the row is kept as the marker but its `data` / `tracked_records` are nulled out (privacy + size).

The completion marker is recorded by the wizard's own finalize, the same `execute` → PRG path as any wizard — no extra code in `execute`.

## Re-opening a completed wizard

Navigating back to a finished one-time wizard (its URL, or its bare launch route) doesn't re-run it — the retained `completed` row has had its `data` cleared, so there's nothing to resume or review. Instead the wizard renders a standalone **"already completed" page**: a success badge, the wizard's label, a short message, and a Continue button out.

Supply a [`completed` block](/reference/wizard/dsl#completed) on the wizard to replace that body with your own:

```ruby
completed do |wizard|
  h1 { "You're already set up." }
  a(href: "/dashboard") { "Back to your dashboard" }
end
```

This is a one-time-only concept: a **repeatable** wizard deletes its row on completion, so re-launching simply starts a fresh run — there's no completed page.

## Gating a controller — `ensure_wizard_completed`

The `Plutonium::Wizard::Gate` concern installs a `before_action` that redirects users into the wizard until they complete it.

```ruby
module AdminPortal
  class DashboardController < AdminPortal::PlutoniumController
    include Plutonium::Wizard::Gate
    ensure_wizard_completed ::WelcomeWizard
  end
end
```

Flow:

1. An un-completed user hits the gated page → the gate stashes their destination (`session[:return_to]`) and redirects to the wizard's first step.
2. The user completes the wizard → finalize records the durable completion marker.
3. The gate now passes them through; the controller bounces them back to the stashed destination (PRG).
4. A completed user passes straight through, every time.

Extra options (`only:` / `except:`) are forwarded to `before_action`:

```ruby
ensure_wizard_completed ::WelcomeWizard, only: %i[index show]
```

The entry URL is derived from the `register_wizard` route helper (`<name>_wizard_path(step: <first_step>)`). Override `wizard_entry_path` for a custom mount.

## How the gate keys completion

The gate **recomputes the wizard's `instance_key`** from its `concurrency_key`, resolving the key block against the **host controller**, so `current_user`, `current_scoped_entity` (folded automatically), `anchor`, and any custom host method are available. It then checks `completed?(instance_key:)`. This digest is computed by the same `Plutonium::Wizard.compute_instance_key` the runner uses, so the gate sees exactly the marker the wizard recorded.

### Gating an anchored wizard

An anchor-keyed wizard (explicit `{ anchor }`, or the [implied anchored key](/reference/wizard/anchoring-resume#the-implied-anchored-key)) keys completion by its anchor — so the gate needs that anchor to recompute the key. It resolves it two ways:

- **Automatic** for a `via:`-anchored wizard — the gate calls the wizard's own `anchor_via` method on the host controller. Gating a `via: :current_scoped_entity` wizard inside its own entity-scoped portal is zero-config (`ConfigureOrgWizard` gated on an org-portal controller just works).
- **Explicit** otherwise — pass `anchor:` (a method name or proc, evaluated on the controller) when the anchor isn't auto-resolvable (a `with:`-anchored wizard, or gating from a different context):

  ```ruby
  ensure_wizard_completed ConfigureWizard, anchor: :current_widget
  ensure_wizard_completed ConfigureWizard, anchor: -> { current_account.widget }
  ```

If an anchor-keyed wizard's anchor can't be resolved and no `anchor:` is given, the gate **raises** (rather than silently mis-keying and looping you into the wizard forever). A wizard keyed by a *non-anchor* method the controller doesn't expose still gives the same clear error.

A wizard keyed by an anchor is only gateable **where that anchor can be reconstructed** — a tenant-anchored wizard, within that tenant's context. That's a property of the keying, not a gap in the gate.

::: warning Only one-time wizards are gateable
`ensure_wizard_completed` raises unless the wizard is `one_time` (a `concurrency_key` **plus** `one_time`) — only a retained marker can be checked. Repeatable wizards have nothing durable to gate on.
:::

## The launch action hides itself once completed

When you register a one-time wizard on a resource definition with the [`wizard` macro](/reference/wizard/registration-launch), the synthesized launch action (button/link) is **automatically hidden once the current user has completed it**. The macro attaches a render-time `condition:` to the action that recomputes the wizard's `instance_key` for the current context (the same `Plutonium::Wizard.compute_instance_key` the driving layer and the [gate](#how-the-gate-keys-completion) use) and returns false when a retained `completed` row exists at that key:

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :onboard, CompanyOnboardingWizard   # one_time → button vanishes after completion
end
```

- It keys exactly like the wizard's own completion: per-user for `concurrency_key { current_user }`, per-anchor for `concurrency_key { anchor }` (the anchor is the record the action sits on), with the tenant folded in.
- This is **display-only** — like every action `condition:`, it hides the button but does **not** revoke the route. Keep authorization in the policy (`def onboard? = …`).
- **Repeatable** (non-`one_time`) wizards get **no** completion condition — their launch action always shows.

A custom `condition:` **composes** with the completion check (they're AND-ed) — the action shows only when your condition is met **and** the wizard isn't already completed:

```ruby
wizard :onboard, CompanyOnboardingWizard,
  condition: -> { current_user.admin? }   # admin AND not yet completed
```

## Related

- [DSL reference](/reference/wizard/dsl) — `concurrency_key`, `one_time`, `authorize?`.
- [Storage & config](/reference/wizard/storage-config) — the durable completion row.
- [Registration & launch](/reference/wizard/registration-launch) — mounting the wizard the gate redirects into.
