# Railless portal support — design

**Date:** 2026-06-14
**Status:** Approved (pending spec review)
**Source:** Bug report — "Plutonium 0.60.0 — railless portal gets phantom icon-rail offsets"

## Problem

A portal that intentionally omits the icon rail (a supported customization)
still inherits layout offsets that assume the 56px icon rail is always present
on desktop (≥1024px). Symptoms:

1. Main content pushed ~15.5rem right (empty left gutter / "tilt").
2. Form sticky action footer has a 56px dead gap on its left edge.

Both stem from one assumption — *the icon rail always exists* — leaking into
four places, with no first-class "no rail" opt-out:

| # | Source | Footprint |
|---|--------|-----------|
| 1 | `ResourceLayout#render_pre_paint_scripts` adds `pu-rail-pinned` on initial load (gated only on a `localStorage` flag) → CSS `html.pu-rail-pinned main { padding-left: 15.5rem !important }` | 15.5rem main offset |
| 2 | `ResourceLayout#main_attributes` `lg:pl-20` (collapsed-rail 80px offset, applied even when unpinned) | 5rem main offset |
| 3 | `Topbar` `lg:left-14` | 56px topbar inset |
| 4 | `StickyFooter` `lg:left-14` | 56px footer inset |

Key existing asymmetry: the `turbo:before-render` listener in
`Base#render_pre_paint_scripts` *already* keys `pu-rail-pinned` on
`newBody.querySelector('[data-controller~="icon-rail"]')` — i.e. on actual rail
presence. Only the **initial-load** path and the static CSS/utility classes
hardcode the assumption.

## Goals

- First-class "no rail" mode, resolvable globally **and** per-portal/per-controller.
- One source of truth so all four offsets stay consistent.
- Stable hooks on `Topbar`/`StickyFooter` for consumer overrides (the report's ask).
- Zero behavior change for existing `:modern` (railed) apps. Low regression risk.

## Non-goals

- No full CSS refactor of the rail system (rejected Approach C — largest/riskiest diff).
- No branding solution for the rail-less topbar (the brand mark lives in
  `IconRail`'s `with_brand` slot today; `:plain`-shell users add branding to
  their ejected header). Flagged as a follow-up, out of scope here.
- `:classic` shell behavior is preserved unchanged (see Classic shell note).

## Design — Approach A: `rail?` predicate as single source of truth

A single boolean, `rail?`, resolved through three tiers (each overrides the one
above), drives every offset. Per the decision: implement the **config** tier and
the **engine/controller** tier; the layout simply delegates to the controller.

### Tier 1 — Global: `config.shell`

`lib/plutonium/configuration.rb`

- Recognize a new shell value `:plain` (rail-less modern shell). `:modern`
  keeps today's rail. No validation is added (shell is already a permissive
  `attr_accessor`); `:plain` is just supported everywhere shell is consumed.

```ruby
config.shell = :plain   # whole app rail-less by default
```

### Tier 2 — Controller: `rail` DSL (primary per-scope hook)

`lib/plutonium/core/controller.rb` (the concern that sets `layout "resource"`,
so it is included in every controller that renders `ResourceLayout`).

```ruby
included do
  class_attribute :_rail_enabled, instance_writer: false, default: nil
  helper_method :rail?
end

class_methods do
  def rail(enabled)
    self._rail_enabled = enabled
  end
end

# nil = inherit the shell default; true/false = explicit override
def rail?
  return _rail_enabled unless _rail_enabled.nil?
  Plutonium.configuration.shell == :modern
end
```

Because `_rail_enabled` is a `class_attribute`, it is **inherited**. A portal
opts its whole surface in/out by setting it once in its engine's controller
concern — no view ejection:

```ruby
module CustomerPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      included { rail false }   # entire portal rail-less
    end
  end
end
```

A single controller can flip it for just its resource. `nil` means "inherit",
so leaving it unset falls through to the shell default with no accidental
override.

### Tier 3 — Layout: delegate to the controller

`lib/plutonium/ui/layout/resource_layout.rb`

```ruby
def rail? = controller.rail?
```

`controller` is already available in the layout component (used for
`@page_title`). A layout subclass *can* still override `rail?` for pure
view-level logic, but the controller tier covers the portal and per-resource
cases without ejecting a layout view.

### What `rail?` gates

`ResourceLayout`:

```ruby
def render_before_main
  super
  render partial("resource_header")
  render partial("resource_sidebar") if rail?   # skip the IconRail when rail-less
end

def render_pre_paint_scripts
  super
  return unless rail?                            # no initial pu-rail-pinned when rail-less
  script { ... existing initial-load pin ... }
end

def main_attributes
  classes = case Plutonium.configuration.shell
  when :modern
    rail? ? "pt-16 pb-6 px-6 lg:pl-20" : "pt-16 pb-6 px-6"
  when :plain
    "pt-16 pb-6 px-6"
  else # :classic — unchanged
    "pt-20 lg:ml-64"
  end
  mix(super, {class: classes})
end

# add a server-rendered root class (no FOUC) so decoupled fixed components
# can cancel their rail insets. Scoped to the modern family so :classic is
# byte-for-byte unchanged.
def html_attributes
  attrs = super
  return attrs if Plutonium.configuration.shell == :classic
  rail? ? attrs : mix(attrs, {class: "pu-no-rail"})
end
```

### Decoupled components — stable hooks + CSS cancel

`Topbar` and `StickyFooter` are rendered outside the layout's reach (Topbar from
a partial, StickyFooter from every form), so they can't read `rail?` directly.
They keep their `lg:left-14` inset and gain a **stable class** so CSS keyed on
the root `pu-no-rail` class can cancel the inset — this also satisfies the
report's "stable hook" request.

- `lib/plutonium/ui/layout/topbar.rb` — add `pu-topbar` to the `nav` class.
- `lib/plutonium/ui/form/components/sticky_footer.rb` — add `pu-sticky-footer`
  to the `div` class.

`src/css/components.css`:

```css
@media (min-width: 1024px) {
  html.pu-no-rail .pu-topbar,
  html.pu-no-rail .pu-sticky-footer {
    left: 0 !important;
  }
}
```

No CSS change is needed for `main`: the 15.5rem pinned padding only applies when
`pu-rail-pinned` is present (never added when rail-less), and the collapsed
`lg:pl-20` is dropped in `main_attributes`.

> **Asset build:** `src/css/components.css` is the source; the shipped
> `app/assets/plutonium.css` (and `.min`) must be rebuilt with `yarn build`
> (`yarn dev` while developing).

### Cross-navigation correctness (already handled)

The `turbo:before-render` listener in `Base` keys `pu-rail-pinned` on
`querySelector('[data-controller~="icon-rail"]')`. A rail-less page renders no
`icon-rail` controller, so navigating rail → rail-less correctly drops the pin,
matching the server-rendered `pu-no-rail`. No JS change required.

### Classic shell note

`:classic` is preserved unchanged: its `main_attributes` branch is untouched,
`pu-no-rail` is never emitted for it, and the initial-load pin is now gated on
`rail?` (false for classic) — which also removes a previously latent spurious
`pu-rail-pinned` emission for classic apps. Net: strictly equal or better.

## Auth: named `current_<account>` accessor (folds in the report appendix)

**Finding:** the report's appendix is *not* a generator bug. The portal
generator (`concerns/controller.rb.tt`) never emits `current_admin` /
`require_admin_role`, and `Plutonium::Auth::Rodauth(name)`
(`lib/plutonium/auth/rodauth.rb`) deliberately exposes `current_user`
(= `rodauth(name).rails_account`) regardless of account name. The `current_admin`
in the report is hand-written app code; calling it raises `NoMethodError`.

**Improvement:** expose a **named** accessor alongside `current_user` so
multi-account code reads naturally and an admin session is distinguishable from
a user session.

`lib/plutonium/auth/rodauth.rb` — in addition to `current_user`, define
`current_<name>` aliased to the same `rails_account`, and register it as a
helper method:

```ruby
included do
  helper_method :current_user, :current_#{name}
  helper_method :logout_url, :profile_url
end

def current_user
  rodauth.rails_account
end
alias_method :current_#{name}, :current_user
```

So `include Plutonium::Auth::Rodauth(:admin)` yields both `current_user` and
`current_admin`. Additive, backward-compatible. (When `name == :user`,
`current_#{name}` is just `current_user` — harmless re-definition.)

Docs: note the correct pattern and the new named accessor in the auth guide /
`plutonium-auth` skill.

## Files touched

- `lib/plutonium/configuration.rb` — support `:plain` shell (doc/comments).
- `lib/plutonium/core/controller.rb` — `rail` DSL + `rail?` + `helper_method`.
- `lib/plutonium/ui/layout/resource_layout.rb` — `rail?` delegate; gate
  `render_before_main`, `render_pre_paint_scripts`, `main_attributes`,
  `html_attributes`.
- `lib/plutonium/ui/layout/topbar.rb` — `pu-topbar` class.
- `lib/plutonium/ui/form/components/sticky_footer.rb` — `pu-sticky-footer` class.
- `src/css/components.css` — `html.pu-no-rail` inset cancel; rebuild assets.
- `lib/plutonium/auth/rodauth.rb` — named `current_<account>` accessor.
- Docs: shell/`:plain` + `rail` DSL (UI/app guide, `plutonium-ui`/`plutonium-app`
  skills); named accessor (`plutonium-auth` skill).

## Testing strategy

- **Controller resolution** (unit): `rail?` returns `true` for `:modern`,
  `false` for `:plain`/`:classic`; `rail true`/`rail false` override the shell
  default; `nil` inherits; the class_attribute inherits to subclasses.
- **Layout rendering** (component/integration): with `rail?` false — sidebar
  partial absent, no `pu-rail-pinned` script, no `lg:pl-20` on `main`,
  `pu-no-rail` present on `<html>`. With `rail?` true — current markup unchanged.
- **Dummy app**: add a controller/portal that sets `rail false`; assert the
  rendered page has `pu-no-rail` and the form's sticky footer carries
  `pu-sticky-footer` (so the CSS cancel applies). Use the existing
  `plutonium-testing` toolkit.
- **Auth** (unit): `Plutonium::Auth::Rodauth(:admin)` exposes both
  `current_user` and `current_admin` returning the same account.
- Run across Rails 7 / 8.0 / 8.1 via Appraisal.

## Rollout / compatibility

Fully additive. Existing `:modern` apps emit no `pu-no-rail` and render
identical markup. `:plain` is opt-in via config; `rail false` is opt-in per
controller/portal. Asset rebuild required for the CSS rule to ship.
