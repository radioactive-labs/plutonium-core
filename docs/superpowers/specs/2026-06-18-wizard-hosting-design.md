# Wizard hosting: controller resolution, identity, and chrome

Status: **design / agreed direction** (no code yet)
Date: 2026-06-18
Supersedes the "wizards are portal-hosted only (v1)" framing.

## Problem

A wizard renders through the Plutonium controller stack (rendering, view-path
prefix, layout). Today the host controller is **synthesized** at route-draw time,
and the synthesis assumes a portal context. That leaves three things
under-specified once wizards run outside a single portal:

1. **Controller resolution** — which controller serves a wizard, and how an app
   customizes it without a generator.
2. **Identity / auth** — where `current_user` comes from, and how a pre-login
   (guest) wizard avoids requiring it.
3. **Chrome** — whether a wizard renders in the app shell, shell-less full page,
   or embedded as a modal.

The guiding facts (verified against the code):

- **Authentication is enforced at the route constraint**, not the controller:
  `constraints Rodauth::Rails.authenticate(:acct) { mount Engine }`. The gem adds
  **no** `require_authentication` before_action; controller auth concerns
  (`Plutonium::Auth::Rodauth(:acct)`) only *provide* `current_user`
  (= `rodauth.rails_account`, `nil` when unauthenticated).
- **`Plutonium::Auth::Public` is just a `current_user => "Guest"` stub.**
- **The shell lives entirely in the layout** (`resource.html.erb` →
  `ResourceLayout`: sidebar/header/topbar), not in the wizard page. The wizard
  `Page` renders `header → stepper → body` and is layout-agnostic.
  `Plutonium::Core::Controller` sets `layout -> { turbo_frame_request? ? false : "resource" }`.

## Catalogue of supported cases

| Surface | Enforcement | Identity (wizard) | Controller (else synthesize) | Chrome |
|---|---|---|---|---|
| **Portal standalone** (`register_wizard` in a portal) | portal constraint | authed (owner) | `<Portal>::PlutoniumController` | `:shell` (default) / `:standalone` |
| **Main-app standalone, authenticated** (`register_wizard` on the app) | route constraint or `require_wizard_authentication!` | authed (owner) | **app-defined** `::WizardsController` | `:shell`* / `:standalone` |
| **Main-app standalone, public** (`register_wizard public:`/`anonymous`) | none (outside constraints) | `anonymous` (guest token) | bare synthesized | `:standalone` (no shell to embed in) |
| **Resource-anchored** (`wizard` macro on a definition) | inherits the resource controller | authed (owner) | the **resource controller** (WizardActions concern) | **always embedded** (modal) |

\* a bare main-app base has no shell; "in-shell" only applies if the app's
`::WizardsController` provides one.

Two structural truths:

- **Portals are "auth or nothing."** You can't carve a public hole inside an
  engine that's wholly behind a constraint, so a *public* wizard is **main-app
  only**. (A portal *may* be mounted without its constraint — a "public portal" —
  in which case `current_user` is still *available*, just possibly `nil`.)
- **Anchored wizards are not a wizard controller.** They are a concern
  (`WizardActions`) mixed into the resource controller, inheriting its
  auth/scope/layout. They stay out of the wizard-controller hierarchy entirely.

## 1. Controller resolution — override-first, no inheritance chain

There is **no single gem "global wizard controller" in the lineage.** A single
base class can't span portal and main-app contexts: the concrete controller's
superclass is *reserved* for the auth/context base (the portal's
`PlutoniumController`, the app's authenticated base, or a bare
`ActionController::Base`), so wizard behavior must compose via a **module**, not a
superclass.

Resolution per surface:

1. **Use the app's controller if it exists** (const check — works today):
   - Portal: `<Portal>::WizardsController`
   - Main app: `::WizardsController`
2. **Else synthesize:**
   ```ruby
   Class.new(context_base) { include Plutonium::Wizard::Controller }
   ```
   where `context_base` is:
   - Portal → `<Portal>::PlutoniumController` (portal auth/scope/layout)
   - Main-app → a **bare** base (`ActionController::Base`), **no auth** — an
     authenticated main-app wizard therefore requires an app-defined
     `::WizardsController` (same contract as `register_resource` controllers).

### The module is the contract

`Plutonium::Wizard::Controller` becomes the complete include surface. Including it
must yield a fully renderable wizard controller, so it pulls in
`Plutonium::Core::Controller` itself (asset/layout machinery) instead of the
synthesizer bolting Core on separately. Re-including Core on a portal parent that
already has it is a harmless no-op, so one module works everywhere.

**View-prefix note.** The gem's shared partials (`plutonium/_flash`, …) are looked
up by a `"plutonium"` view *prefix*, which normally comes from inheriting a
controller whose `controller_path` is `"plutonium"` (the app's
`PlutoniumController`) — *not* from `Core`'s `append_view_path` (that adds the
directory, not the prefix). A truly bare host lacks the ancestor, so the **module
contributes the `"plutonium"` prefix itself** (overriding `_prefixes`). This is
what makes "main-app can be bare" actually render.

- **Synthesizer:** `Class.new(context_base) { include Plutonium::Wizard::Controller }`
- **User override:** `class WizardsController < MyAuthBase; include Plutonium::Wizard::Controller; end`

### Convenience base class (sugar only)

For apps that need no custom auth base, ship a ready-made class:

```ruby
# Plutonium-provided
class Plutonium::Wizard::BaseController < ActionController::Base
  include Plutonium::Wizard::Controller
end

# app
class WizardsController < Plutonium::Wizard::BaseController; end
```

The class is convenience; the **module is the mechanism**.

## 2. Identity / auth — guest-ness belongs to the wizard

`current_user` has two distinct meanings:

- **Available** = a *controller* property: present wherever a `Rodauth(acct)`
  concern is mixed in (returns `nil` when unauthenticated).
- **Expected** = a *wizard* property: a non-`anonymous` wizard owner-scopes off
  `current_user`; an `anonymous` wizard *ignores it* and keys identity off the
  session token (owner `nil`).

Therefore:

- Guest-ness is enforced **in the driving layer**: an `anonymous` wizard never
  consults `current_user` for identity (it's session-token keyed, owner `nil`).
- A normal wizard with no `current_user` is rejected by the route constraint
  (authenticated mounts) or by `require_wizard_authentication!` (the fallback that
  also covers public mounts hosting a non-anonymous wizard).
- The wizard module supplies a **default `current_user`** that defers to the
  host's auth concern when present (`defined?(super) ? super : nil`) and is `nil`
  on a bare host — so a bare main-app/public controller has the method without
  shadowing a real auth concern.

> **CORRECTION (was: "retire `Auth::Public`").** `Plutonium::Auth::Public` is
> **kept** — it is not wizard-specific: public *portals* (e.g. a storefront) use
> it, and a wizard can run inside one (a resource-anchored wizard on a public
> portal), where `current_user` is the `"Guest"` sentinel. So the driving layer's
> `current_user_present_for_wizard?` **keeps** its `!= "Guest"` check. What changed
> is only that the public *wizard* synthesis no longer *needs* `Auth::Public` for
> correctness (an `anonymous` wizard never reads `current_user`); it's retained
> there for a defined `current_user` and consistency with public portals.

## 3. Chrome — a `register_wizard` option, three modes

> **NAMING (as-built):** the option shipped as **`shell:` (boolean)**, not `chrome:`.
> "Shell" is Plutonium's own word for the sidebar/topbar frame, so `shell: false`
> reads as a plain on/off toggle; `layout:` would collide with Rails' `layout`. The
> three "modes" below collapse to two states + the automatic embedded (turbo-frame)
> path: `shell: true` (in-shell) / `shell: false` (shell-less). Read "chrome" as
> "shell" and `chrome: :standalone` as `shell: false` throughout this section.

The shell is a layout concern, so chrome = layout selection, made by the **driving
layer at render time** (works regardless of which controller serves the wizard,
and without touching the `Page` component):

| Mode | Appearance | Layout |
|---|---|---|
| **Embedded** | overlays the current page (launched from a button) | `layout: false` (turbo-frame) — already automatic |
| **In-shell** (`:shell`) | sidebar + topbar + wizard | inherited `resource` layout |
| **Shell-less** (`:standalone`) | no sidebar/topbar — e.g. "set up your organization" | `plutonium_standalone` (`BasicLayout`) |

Rules:

- **Chrome is toggled only on `register_wizard`** (`chrome: :shell | :standalone`).
  It travels with the mount, not the wizard class.
- **Resource-defined wizards (`wizard` macro) are always embedded** — launched
  from a record/collection action, overlaying the page. No chrome option.
- **Turbo-frame requests are always layout-less** regardless of the setting (the
  embedded path).
- **Default by mount context:** portal standalone → `:shell`; bare main-app
  standalone → `:standalone` (no shell available). Both overridable.

## Resolved decisions

1. **Chrome surface:** `register_wizard` option only; resource wizards always
   embedded. ✔
2. **Default full-page chrome:** portal → `:shell`, main-app → `:standalone`. ✔
3. **Retire `Auth::Public`:** yes — guest-ness moves to the `anonymous` wizard +
   driving layer; guest = `current_user.nil?`. ✔

## Migration / current state

Already on the branch (keep — steps toward this design):

- `PublicWizardsController` split from `::WizardsController` (the const collision
  fix). Under this design the public path is "a bare synthesized controller +
  `anonymous` wizard," but the distinct const remains correct.
- The synthesized controller including `Plutonium::Core::Controller` itself — this
  becomes "the module pulls in Core," i.e. moved into
  `Plutonium::Wizard::Controller`.

To revert before implementing:

- The `Rodauth(:user)` added to the dummy's `::PlutoniumController` (wrong layer —
  leaks auth into every portal base). Replace the dummy demo with an app-defined
  `::WizardsController` that includes the wizard module + its own auth — which also
  exercises the override hook.

## Implementation outline (for the follow-up, not this doc)

1. Fold `Core::Controller` into `Plutonium::Wizard::Controller`; ship
   `Plutonium::Wizard::BaseController` convenience class.
2. Main-app synthesis: bare `ActionController::Base` base (drop the
   `::PlutoniumController` parent); keep the const-check override.
3. `register_wizard … chrome:`; driving layer selects the layout
   (`false` / `plutonium_standalone` / inherited) at render.
4. Remove `Auth::Public`; route guest identity through `anonymous` + the driving
   layer; treat `current_user.nil?` as guest.
5. Dummy: app-defined `::WizardsController` (auth) for the authenticated main-app
   demo; a separate `anonymous` public wizard for the guest demo; revert the
   `::PlutoniumController` change.
6. Tests: override-hook is honored; bare main-app wizard is guest; chrome toggles
   pick the right layout; anchored wizard stays embedded.
