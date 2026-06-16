# Registration & launch

Wizards are **portal-hosted** — they run inside a Plutonium portal, exactly like resources, inheriting the portal's authentication, tenant scoping entity, layout, and Phlex rendering. There are two ways a wizard reaches a user.

## On a resource — the `wizard` macro

A `wizard` macro in a resource definition registers a wizard and synthesizes its launching action — sugar over the Action system.

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard            # anchored → record action
  wizard :onboard,   CompanyOnboardingWizard           # no anchor → resource action
  wizard :archive,   ArchiveWithReasonWizard, record_action: true   # override placement
end
```

- **Placement mirrors interactions** — an **anchored** wizard becomes a **record** (member) action, a **non-anchored** wizard becomes a **resource** (collection) action (index header). Use `record_action:` / `collection:` to override placement.
- **Auto-mounted on the resource controller** — the `wizard` macro's routes are drawn on the resource's own controller, exactly like interactive record/resource actions. There is nothing else to wire up.
- **The anchor is IDOR-safe** — an anchored (record) wizard resolves its anchor through the resource controller's scoped, policy-gated `resource_record!`. A record outside the portal's authorized scope (another tenant's, or a non-existent id) **404s**; it is never loaded via an unscoped `find_by`.
- **Bulk wizards are not supported** — wizards are inherently per-instance flows. Use a bulk interaction instead.
- **Authorization mirrors actions** — a resource policy predicate named after the wizard key gates it (`def configure? = update?`, `def onboard? = create?`).

| Option | Meaning |
|---|---|
| `record_action:` | Force record (member) placement. |
| `collection:` | Force resource (collection) placement. |
| `label:` / `icon:` / `position:` / `category:` / `confirmation:` | Standard action chrome. |

### Synthesized routes (resource-mounted)

```
# anchored → member route (anchor = the scoped resource_record!)
GET/POST  /companies/:id/wizards/:wizard_name(/:token)/:step

# non-anchored → collection route (create flow)
GET/POST  /companies/wizards/:wizard_name(/:token)/:step
```

The synthesized action's URL resolves the wizard's first-step GET route at render time, on these auto-mounted routes.

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
| `public:` | Mount on a **public (unauthenticated) route** for an [`anonymous`](#public-mount-for-anonymous-wizards) wizard. Defaults to the wizard's own `anonymous?` flag. |

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

A falsy return → `ActionPolicy::Unauthorized` (403). Resource-attached wizards instead use their action's policy predicate (`def onboard?` etc.).

::: danger A portal-level wizard with no `authorize?` is open to ANY authenticated portal user
A portal-level wizard (registered with `register_wizard`) has **no resource policy** and **defaults to allowed** — so if you omit `authorize?`, every authenticated user of that portal can run it. **Always define `def authorize?`** for anything privileged (admin-only flows, per-user gating, tenant checks). The default-allow is only safe for flows that are genuinely fine for any signed-in portal user (e.g. self-service onboarding).
:::

::: warning As-built: `authorize?` is an instance method
Define `def authorize?` on the wizard. The controller checks it only when the wizard responds to it (default: allowed).
:::

## Public mount for `anonymous` wizards

**Wizards require authentication by default.** A guest ([`anonymous`](/reference/wizard/anchoring-resume#authentication)) wizard needs a route reachable **before** login. Because a portal engine is mounted *inside* the host's authentication constraint (`constraints Rodauth::Rails.authenticate(:user) { mount ... }`), a route drawn in the portal is unreachable pre-login. So `register_wizard` draws an `anonymous` wizard's route on the **main application's** route set, outside that constraint:

```ruby
# in the portal engine's routes (register_wizard is available there)
register_wizard ::GuestSignupWizard, at: "signup", public: true
#   → GET/POST /signup(/:token)/:step  (a top-level, unauthenticated route)
```

- `public: true` is the **default for an `anonymous` wizard**; you can pass it explicitly for clarity.
- A **non-`anonymous`** wizard may **not** be mounted public (raises) — and an **`anonymous`** wizard may **not** be mounted authenticated (it would be unreachable pre-login).
- The public route dispatches to a synthesized top-level `WizardsController` that renders **full-page** with a standalone layout (no resource sidebar / user menu) and treats the request as a guest (no `current_user`).

## One-time gating

To make a wizard run once and gate a controller behind it, see [One-time wizards](/reference/wizard/one-time) — a `concurrency_key` + `one_time` + the `Plutonium::Wizard::Gate` concern (`ensure_wizard_completed`).

For a **one-time** wizard, the launch action this macro synthesizes also **hides itself once the current user has completed it** (via a render-time action `condition:`); a custom `condition:` composes with that check. See [The launch action hides itself once completed](/reference/wizard/one-time#the-launch-action-hides-itself-once-completed).

## Known limitations

v1 hosts wizards inside portals only. A few surfaces are deliberate follow-ups:

- **`with:`-anchored wizards mount on the resource, not portal-level.** Register a `with:`-anchored wizard on the anchored resource's definition with the `wizard` macro (it auto-mounts a member action whose anchor is the scoped `resource_record!`). Passing a `with:`-anchored wizard to **`register_wizard`** raises — portal-level mounts have no resource record to anchor to. A **`via:`-anchored** (context-anchored) wizard *does* mount portal-level — its anchor is resolved by a controller method, not a URL `:id`.
- **Main-app (non-portal) standalone wizards** are out of scope for v1 — authenticated wizards inherit a portal's auth/scoping/layout/rendering. The one exception is an [`anonymous` wizard's public mount](#public-mount-for-anonymous-wizards), which is drawn on the main app outside the portal's auth constraint precisely because it must be reachable pre-login.

## Related

- [DSL reference](/reference/wizard/dsl) — `authorize?`, the wizard body.
- [Anchoring & resume](/reference/wizard/anchoring-resume) — anchors, instance keys.
- [One-time wizards](/reference/wizard/one-time) — completion + gating.
- [Custom actions guide](/guides/custom-actions) — the Action system the `wizard` macro builds on.
