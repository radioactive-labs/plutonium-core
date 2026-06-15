# Registration & launch

Wizards are **portal-hosted** — they run inside a Plutonium portal, exactly like resources, inheriting the portal's authentication, tenant scoping entity, layout, and Phlex rendering. There are two ways a wizard reaches a user.

## On a resource — the `wizard` macro

A `wizard` macro in a resource definition registers a wizard and synthesizes its launching action — sugar over the Action system.

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard            # anchored → record action
  wizard :onboard,   CompanyOnboardingWizard           # no anchor → resource action
  wizard :archive,   ArchiveWithReasonWizard, record_action: true   # override
end
```

- **Placement mirrors interactions** — an anchored wizard becomes a **record** action (per row / show page); a non-anchored wizard becomes a **resource** (collection) action (index header). Use `record_action:` / `collection:` to override.
- **Bulk wizards are not supported** — wizards are inherently per-instance flows. Use a bulk interaction instead.
- **Authorization mirrors actions** — a resource policy predicate gates it (`def configure? = update?`).

| Option | Meaning |
|---|---|
| `record_action:` | Force record (member) placement. |
| `collection:` | Force resource (collection) placement. |
| `at:` | The wizard's portal-relative base path (used to build the launch URL); defaults to the wizard's route name. |
| `label:` / `icon:` / `position:` / `category:` / `confirmation:` | Standard action chrome. |

The synthesized action's URL resolves the wizard's first-step GET route at render time. It relies on the wizard's routes being drawn (via `register_wizard`).

## Portal-level — `register_wizard`

For a wizard not tied to a single resource (onboarding, welcome), register it **inside the portal engine's routes**, alongside `register_resource`:

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  register_wizard ::OnboardOrganizationWizard, at: "onboarding"
  register_wizard ::WelcomeWizard, at: "welcome"

  register_resource ::Company
end
```

| Argument | Meaning |
|---|---|
| `at:` (required) | The portal-relative base path for the wizard's steps. |
| `as:` | Override the route helper name prefix (defaults to the wizard's name, e.g. `OnboardOrganizationWizard` → `onboarding`). |

This draws the wizard's step routes within the portal — so they inherit the portal's scope/auth/layout — and dispatches them to a portal-namespaced wizard controller (synthesized for you; there is no hand-written controller file). It provides `<name>_wizard_path` / `_url` helpers.

### Synthesized routes

```
GET  /onboarding(/:token)/:step   → renders the step
POST /onboarding(/:token)/:step   → advances (the `_direction` param carries next/back/cancel)
```

`scope_gid` (folded into the instance key) comes from the portal's scoping entity when the portal is entity-scoped.

## Entry authorization

A portal-level wizard has no resource policy, so gate entry with an `authorize?` instance method on the wizard — checked before each request:

```ruby
class WelcomeWizard < Plutonium::Wizard::Base
  def authorize?
    current_user.present? && !current_user.onboarded?
  end
end
```

A falsy return → `ActionPolicy::Unauthorized` (403). Resource-attached wizards instead use their action's policy predicate (`def configure?` etc.).

::: warning As-built: `authorize?` is an instance method
Define `def authorize?` on the wizard. The controller checks it only when the wizard responds to it (default: allowed).
:::

## One-time gating

To make a wizard run once and gate a controller behind it, see [One-time wizards](/reference/wizard/one-time) — `one_time once_per:` + the `Plutonium::Wizard::Gate` concern (`ensure_wizard_completed`).

## Known limitations

v1 hosts wizards inside portals only. A few surfaces are deliberate follow-ups:

- **Anchored resource member routes** (`/companies/:id/wizards/configure/:step`) are a follow-up — the **portal-level mount** (`register_wizard`) is the primary, fully-wired path. The `wizard` definition macro synthesizes the action and resolves the launch URL against the drawn wizard routes.
- **`once_per: :anchor` gating** needs a host-provided anchor resolver — override `wizard_gate_anchor` in the gated controller (the default raises). See [One-time wizards](/reference/wizard/one-time#once-per-anchor).
- **Main-app (non-portal) standalone wizards** are out of scope for v1 — wizards inherit a portal's auth/scoping/layout/rendering.

## Related

- [DSL reference](/reference/wizard/dsl) — `authorize?`, the wizard body.
- [Anchoring & resume](/reference/wizard/anchoring-resume) — anchors, instance keys.
- [One-time wizards](/reference/wizard/one-time) — completion + gating.
- [Custom actions guide](/guides/custom-actions) — the Action system the `wizard` macro builds on.
