# Registration & launch

A wizard reaches a user one of two ways: as a **resource action** (the `wizard` macro on a definition) or as a **route-mounted entry** (`register_wizard`) — inside a portal *or* on the main application. A portal mount inherits the portal's authentication, tenant scoping entity, layout, and Phlex rendering, exactly like a resource; a main-app mount runs standalone (you supply the auth — see [Hosting & the controller override hook](#hosting-the-controller-override-hook)).

## On a resource — the `wizard` macro

A `wizard` macro in a resource definition registers a wizard and synthesizes its launching action — sugar over the Action system.

```ruby
class CompanyDefinition < Plutonium::Resource::Definition
  wizard :configure, ConfigureCompanyWizard            # anchored → record action
  wizard :onboard,   CompanyOnboardingWizard           # no anchor → resource action
  wizard :archive,   ArchiveWithReasonWizard, record_action: true   # override placement
end
```

- **Placement is dictated by the wizard, not chosen** — an **anchored** wizard is a **record** action (it needs a record, the anchor); a **non-anchored** wizard is a collection-level **resource** action (index header). A record-action wizard surfaces on BOTH the record's show page *and* each list row (`collection_record_action`, scoped to that row's record), exactly like `edit`/`destroy`. The only thing you configure is **where a record action shows** (see the table); a flag that doesn't apply to the wizard's kind (e.g. `resource_action:` on an anchored wizard) **raises**.
- **Auto-mounted on the resource controller** — the `wizard` macro's routes are drawn on the resource's own controller, exactly like interactive record/resource actions. There is nothing else to wire up.
- **The anchor is IDOR-safe** — an anchored (record) wizard resolves its anchor through the resource controller's scoped, policy-gated `resource_record!`. A record outside the portal's authorized scope (another tenant's, or a non-existent id) **404s**; it is never loaded via an unscoped `find_by`.
- **Bulk wizards are not supported** — wizards are inherently per-instance flows. Use a bulk interaction instead.
- **Authorization mirrors actions** — a resource policy predicate named after the wizard key gates it (`def configure? = update?`, `def onboard? = create?`).

| Option | Meaning |
|---|---|
| `record_action:` | **(Record wizards only)** show on the record's **show page**. Default `true`; `false` removes it from there. |
| `collection_record_action:` | **(Record wizards only)** show on each **list row** (scoped to that row's record). Default `true`; `false` keeps it on the show page but off the list. |
| `label:` / `icon:` / `position:` / `category:` / `confirmation:` / `turbo_frame:` | Standard action chrome — any `action` option passes through. |

Placement isn't an option — it follows `anchored?`. Passing a flag that doesn't apply (`resource_action:` on a record wizard, or `record_action:`/`collection_record_action:` on a resource wizard) raises.

### Synthesized routes (resource-mounted)

```
# anchored → member route (anchor = the scoped resource_record!)
GET       /companies/:id/wizards/:wizard_name                 → launch (redirect to step)
GET/POST  /companies/:id/wizards/:wizard_name(/:token)/:step

# non-anchored → collection route (create flow)
GET       /companies/wizards/:wizard_name                     → launch (redirect to step)
GET/POST  /companies/wizards/:wizard_name(/:token)/:step
```

The synthesized launch action points at the **bare** wizard URL (no step). A `GET` there resolves the run (minting the per-run `:token` for a tokened wizard, or resolving the keyed identity) and redirects to its current step: the **resumed cursor** for an in-progress keyed run, else the **first step**, with the token already in the URL. So clicking the launch button resumes where the user left off (rather than jumping back to step 1) and never forks a fresh run on a first-step reload.

## Route-mounted — `register_wizard`

For a wizard not tied to a single resource (onboarding, welcome, set-up), register it with `register_wizard` — **inside a portal engine's routes** (most common) or **on the main application's routes**, alongside `register_resource`:

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  register_wizard ::OnboardOrganizationWizard, at: "onboarding"               # in-shell (portal default)
  register_wizard ::SetupOrgWizard, at: "setup", layout: :basic               # bare (BasicLayout)

  register_resource ::Company
end

# config/routes.rb — a main-app (portal-less) wizard
Rails.application.routes.draw do
  register_wizard ::AppOnboardingWizard, at: "onboarding"                     # main-app default → :basic
end
```

| Argument | Meaning |
|---|---|
| `at:` (required) | The host-relative base path for the wizard's steps. |
| `as:` | Override the route helper name prefix (defaults to `at:`, then the wizard's name, e.g. `OnboardOrganizationWizard` → `onboarding`). |
| `public:` | Mount on a **public (unauthenticated) route** for an [`anonymous`](#public-mount-for-anonymous-wizards) wizard. Defaults to the wizard's own `anonymous?` flag. |
| `layout:` | The Rails [layout](#layout) to render in (a layout name, like the controller `layout` macro): `:basic` (bare), `:resource` (shell), or any app layout. Defaults by host — **portal → the resource shell**, **main-app → `:basic`**. |

This draws the wizard's step routes within the host (so a portal mount inherits the portal's scope/auth/layout) and dispatches them to a wizard controller. It provides `<name>_wizard_path` / `_url` helpers.

### Hosting & the controller override hook

`register_wizard` resolves the controller it dispatches to **override-first**: if you've defined the conventional controller it is used as-is; otherwise one is synthesized. This is the same "app owns the controller" contract as `register_resource` — there is no hand-written file unless you want to customize.

| Host | Controller | Base / auth |
|---|---|---|
| **Portal** | `<Portal>::WizardsController` if defined, else synthesized | the portal's `PlutoniumController` (inherits its auth/scope/layout) |
| **Main app, authenticated** | `::WizardsController` — **you define it** | yours: a base + `include Plutonium::Auth::Rodauth(:account)` |
| **Main app, public** (`anonymous`) | `::PublicWizardsController` (synthesized) | a bare base + `Plutonium::Auth::Public` (guest) |

The synthesized **main-app** controller is **bare** — rooted in `ApplicationController`/`ActionController::Base`, deliberately *not* in `::PlutoniumController` (which portals inherit and may carry auth, which would leak into a guest flow). A bare controller has **no `current_user`**, so an **authenticated** main-app wizard requires you to define `::WizardsController` yourself with the auth concern:

```ruby
# app/controllers/wizards_controller.rb
class WizardsController < ApplicationController
  include Plutonium::Wizard::Controller          # the complete include surface
  include Plutonium::Auth::Rodauth(:user)        # supplies current_user
end
```

`Plutonium::Wizard::Controller` is the whole mechanism: including it on any base yields a renderable wizard controller. It pulls in `Plutonium::Core::Controller` (asset/layout machinery) and **contributes the `"plutonium"` view-lookup prefix itself**, so even a bare `ActionController::Base` host resolves the gem's shared partials (`plutonium/_flash`, …). For an app that needs no custom auth base, subclass the ready-made `Plutonium::Wizard::BaseController` (`< ActionController::Base` with the module already included). The module is the contract; the class is sugar.

### Layout

`layout:` is the **Rails layout** the wizard renders in — a layout *name*, exactly like the controller `layout` macro. It's applied at render time, so it works regardless of which controller serves the wizard (without touching the `Page` component):

| `layout:` | Appearance | Layout |
|---|---|---|
| `:basic` | no sidebar/topbar — e.g. "set up your organization" | `basic` (`BasicLayout`) |
| `:resource` | sidebar + topbar + wizard (in-app) | the `resource` shell layout |
| *(any app layout)* | whatever that layout renders | passed straight to Rails |
| *(omitted)* | host default — see below | — |

- **Defaults by host:** portal → the `resource` shell; main-app → `:basic` (a bare main-app host has no shell to embed in). Pass `layout:` to override.
- **Turbo-frame requests are always layout-less** regardless of the setting — that's the embedded/modal path (how resource-anchored `wizard`-macro launches render).
- `layout:` is a **`register_wizard` option only**; it travels with the mount, not the wizard class. Resource-defined wizards take no `layout:` (always embedded).

### Synthesized routes

```
GET  /onboarding                  → launch: resolve/mint the run, redirect to its step
GET  /onboarding(/:token)/:step   → renders the step
POST /onboarding(/:token)/:step   → advances (the `_direction` param carries next/back/cancel)
```

The bare **`/onboarding`** is the canonical entry point (helper `onboarding_wizard_launch_path`). A `GET` there resolves the run (minting the per-run `:token` for a tokened wizard, or resolving the keyed/guest identity) and `303`-redirects to its entry step: the **resumed cursor** for an in-progress keyed/guest run, else the **first visible step**. Because the redirect target already carries the token, the address bar shows a stable, shareable run URL from the first paint (the token no longer "appears" only after the first submit, and reloading the first step can't fork a second run). Link to `/onboarding` from menus/dashboards; the stepped `/onboarding(/:token)/:step` URLs are built for you by the engine.

The POST `_direction` param carries `next` / `back` / `cancel`. **Where Cancel sends the user** is captured at launch from a `?return_to=` query param (or the referer), sanitized to a same-host local path that isn't the wizard's own mount (open-redirect-safe); Cancel returns there, falling back to the host root. So linking to `/onboarding?return_to=/dashboard` lands a cancelled run back on the dashboard.

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
- The public route dispatches to a synthesized top-level `::PublicWizardsController` (a **distinct** const from an authenticated main-app `::WizardsController`, so the two never collapse onto each other) that renders **full-page** with a standalone layout (no resource sidebar / user menu) and treats the request as a guest via `Plutonium::Auth::Public`.

## One-time gating

To make a wizard run once and gate a controller behind it, see [One-time wizards](/reference/wizard/one-time) — a `concurrency_key` + `one_time` + the `Plutonium::Wizard::Gate` concern (`ensure_wizard_completed`).

For a **one-time** wizard, the launch action this macro synthesizes also **hides itself once the current user has completed it** (via a render-time action `condition:`); a custom `condition:` composes with that check. See [The launch action hides itself once completed](/reference/wizard/one-time#the-launch-action-hides-itself-once-completed).

## Constraints

- **`with:`-anchored wizards mount on the resource, not route-level.** Register a `with:`-anchored wizard on the anchored resource's definition with the `wizard` macro (it auto-mounts a member action whose anchor is the scoped `resource_record!`). Passing a `with:`-anchored wizard to **`register_wizard`** raises: a route-level mount has no resource record to anchor to. A **`via:`-anchored** (context-anchored) wizard *does* mount route-level; its anchor is resolved by a controller method, not a URL `:id`.
- **An authenticated main-app wizard needs an app-defined controller.** The synthesized main-app controller is bare (no `current_user`); supply your own `::WizardsController` with an auth concern (see [Hosting & the controller override hook](#hosting-the-controller-override-hook)). Portal mounts and `anonymous` public mounts need nothing.
- **Route-helper names must be unique across public mounts.** A public (`anonymous`) wizard's route is drawn on the main app, keyed by its helper name (`as:` → `at:` → class-derived). Two distinct public wizards resolving to the **same** helper name **raise** at draw time — give one an explicit `as:`. (Re-drawing the *same* wizard on a route reload is a no-op, not a collision.)

## Related

- [DSL reference](/reference/wizard/dsl) — `authorize?`, the wizard body.
- [Anchoring & resume](/reference/wizard/anchoring-resume) — anchors, instance keys.
- [One-time wizards](/reference/wizard/one-time) — completion + gating.
- [Custom actions guide](/guides/custom-actions) — the Action system the `wizard` macro builds on.
