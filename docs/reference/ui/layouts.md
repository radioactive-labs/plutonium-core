# Layouts

The overall page chrome — topbar, sidebar, footer, body wrapping. Plutonium ships three shells; you can eject the templates or write a custom `ResourceLayout` for total control.

## Shell

```ruby
Plutonium.configure do |config|
  config.shell = :modern     # default — topbar + icon rail
  # config.shell = :plain    # topbar, no icon rail (rail-less app)
  # config.shell = :classic  # legacy header + sidebar (only when upgrading)
end
```

::: tip `:classic` is only for upgrade paths
If you're starting fresh, use `:modern`. `:classic` exists so apps upgrading from pre-`:modern` versions can preserve their chrome while migrating.
:::

## Shell variants & the icon rail

The shell variant selects the page chrome:

- `:modern` (default) — Topbar plus the desktop icon rail.
- `:plain` — Topbar but **no** icon rail. The Topbar is kept; only the rail is removed, so the surface is rail-less.
- `:classic` — legacy Header/Sidebar (upgrade paths only).

### Resolving the shell (global → engine → controller)

The shell resolves across three layers, each overriding the one above it:

```ruby
# 1. Global default (config/initializers/plutonium.rb)
Plutonium.configure { |config| config.shell = :modern }

# 2. Per-engine — set it on a portal engine (lib/engine.rb)
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      shell :plain   # this whole portal is rail-less
    end
  end
end

# 3. Per-controller — overrides the engine/global default for one controller (and subclasses)
class DashboardController < ResourceController
  shell :modern   # opt this controller back into the rail
end
```

`shell` takes a plain symbol, so it's safe in the class body too — but the generated engine already has a `config.after_initialize` block (where `scope_to_entity` lives), so keeping it there is the consistent home.

An unset engine/controller value (`nil`) falls through to the next layer. Read the resolved value with the `shell` helper (`controller.shell`).

### `rail` — a controller-level rail toggle

Alongside `shell`, any resource controller exposes a class-level `rail` DSL that flips just the icon rail without changing the shell. It's a `class_attribute`, so it's inherited — a portal opts its entire surface in or out by calling `rail false` (or `rail true`) once in its controller concern:

```ruby
module CustomerPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      included { rail false }  # entire portal rail-less
    end
  end
end
```

`rail nil` (the default) inherits the resolved shell — the rail shows when the resolved `shell == :modern`. Read the resolved value with the `rail?` predicate.

### Stable CSS hooks

Rail-less rendering exposes a few stable hooks for custom overrides:

- `pu-topbar` — class on the Topbar nav.
- `pu-sticky-footer` — class on the form sticky-footer div.
- `html.pu-no-rail` — root class present whenever the current page is rail-less.

A built-in rule cancels the desktop rail inset on `.pu-topbar` and `.pu-sticky-footer` under `html.pu-no-rail`; target these hooks to layer your own CSS.

## Eject the chrome for per-portal customization

```bash
rails generate pu:eject:shell --dest=admin_portal
rails generate pu:eject:layout
```

`pu:eject:shell` copies `_resource_header.html.erb` and `_resource_sidebar.html.erb` into the portal's `app/views/plutonium/`. The eject is independent of `shell` — you can run it on either.

`pu:eject:layout` copies `layouts/resource.html.erb` for layout-level edits.

## Navigation menu

The sidebar/icon-rail navigation is built with `Phlexi::Menu::Builder` in the ejected `_resource_sidebar.html.erb`. Each `item` takes a `label`, plus `url:`, `icon:`, and optional `leading_badge:` / `trailing_badge:`:

```erb
<%= render Plutonium::UI::Layout::IconRail.new(
      menu: Phlexi::Menu::Builder.new do |m|
        m.item "Dashboard", url: root_path, icon: Phlex::TablerIcons::Home

        m.item "Resources", icon: Phlex::TablerIcons::GridDots do |n|
          registered_resources.each do |resource|
            n.item resource_label(resource), url: resource_url_for(resource, parent: nil)
          end
        end
      end
    ) %>
```

### Per-item link attributes

Any extra options you pass to `item` are spread straight onto the rendered `<a>` — so a menu entry can opt into `target`, `rel`, `data-*`, `aria-*`, etc. Useful for items that open in their own tab or drive a Stimulus/Turbo behavior:

```ruby
m.item "Inbox",
  url: inbox_path,
  icon: Phlex::TablerIcons::Mail,
  target: "_blank",
  rel: "noopener",
  data: {turbo_frame: "_top"}
```

This works across both shells — the `:modern` icon-rail (leaf items, parent flyout triggers, and flyout children) and the `:classic` sidebar. Framework attributes always win on conflict: a custom `class:` is **merged** with the component's base classes, and on a parent trigger your `data:` / `aria:` merge with the flyout's own wiring (so you can't accidentally break the toggle). The `:active` key is reserved by Phlexi for [custom active-state logic](https://github.com/radioactive-labs/phlexi-menu) and is never emitted as an attribute.

## Custom layout class

For full Phlex-level control over the layout:

```ruby
module AdminPortal
  class ResourceLayout < Plutonium::UI::Layout::ResourceLayout
    private

    def body_attributes
      {class: "antialiased bg-[var(--pu-body)]"}
    end

    def render_before_main
      super
      render AnnouncementBanner.new if Announcement.active.any?
    end

    def render_body_scripts
      super
      script(src: "/custom-analytics.js")
    end
  end
end
```

### Layout hooks

| Hook | Position |
|---|---|
| `render_before_main` / `_after_main` | around the main content area |
| `render_before_content` / `_after_content` | inside main, around content |
| `render_flash` | flash messages |
| `render_head`, `render_title`, `render_metatags`, `render_assets` | head section |
| `render_body_scripts` | end-of-body scripts |
| `render_fonts` | font links |

## Typography

Plutonium uses Lato by default. Override via `render_fonts`:

```ruby
class MyLayout < Plutonium::UI::Layout::ResourceLayout
  def render_fonts
    link(rel: "preconnect", href: "https://fonts.googleapis.com")
    link(href: "https://fonts.googleapis.com/css2?family=Inter&display=swap", rel: "stylesheet")
  end
end
```

Then configure Tailwind to match:

```javascript
// tailwind.config.js
theme: plutoniumTailwindConfig.merge(plutoniumTailwindConfig.theme, {
  fontFamily: {
    body: ['Inter', 'sans-serif'],
    sans: ['Inter', 'sans-serif']
  }
})
```

See [Assets › Tailwind config](./assets#tailwind-config) for the full merge story.

## Dark mode

`selector` strategy — toggle by adding/removing `dark` on `<html>`. The bundled `color-mode` Stimulus controller handles toggling; Plutonium ships a switcher.

```javascript
// Manual toggle if needed
document.documentElement.classList.toggle('dark')
```

## Related

- [Assets](./assets) — Tailwind config, design tokens, `.pu-*` classes
- [Components](./components) — custom components used in layout hooks (`AnnouncementBanner`, etc.)
- [Pages](./pages) — page-level hooks (a lighter alternative for per-page chrome)
