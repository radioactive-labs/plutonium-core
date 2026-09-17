---
name: plutonium-dashboard
description: Use BEFORE building a dashboard, KPI page, metrics overview or chart page in a Plutonium app — Plutonium::Dashboard::Base, the metric / chart / card DSL, register_dashboard, lazy turbo-frame cards, refresh, conditions, authorize?, and the pu:dashboard generator. The single source for "how do I add a dashboard with metric cards and charts".
---

# Plutonium Dashboards

A dashboard is a class of cards (`metric`, `chart`, `card`) mounted in a portal with one routes line. Every card loads in its own lazy turbo frame, so the page paints at once and each card's queries run in a separate request. Charts render with Chart.js through Chartkick, styled by Plutonium's design tokens.

For resources and their definitions see [[plutonium-resource]]; for portals and routes see [[plutonium-app]]; for custom Phlex markup inside a card see [[plutonium-ui]].

## 🚨 Critical (read first)

- **Experimental.** The DSL and behavior may change in a future release, the same status as [[plutonium-wizard]], [[plutonium-kanban]] and [[plutonium-async-interactions]]. Fine to build on; expect to follow the changelog.
- **Generate, don't hand-write:** `rails g pu:dashboard Sales --dest=admin_portal` writes the class AND the `register_dashboard` line.
- **Replacing the portal's default page:** `rails g pu:dashboard Home --dest=admin_portal --at=/` mounts it at the portal root and replaces the generated `root to: "dashboard#index"` line (two roots clash). It does NOT delete the generated `DashboardController` + `dashboard/index.html.erb`; delete them, nothing routes there any more. The sidebar Home link then opens the dashboard, and it is left out of the Dashboards group.
- **Dashboards live in `app/dashboards/`** (`packages/<portal>/app/dashboards/<portal>/` in a package). Class name ends in `Dashboard`; the label drops the suffix.
- **Card blocks run on the dashboard instance**, not the controller: use `current_user`, `current_scoped_entity`, `authorized_resource_scope(Model)`, `resource_url_for`, `helpers`, and the dashboard's own private methods. Scope queries with `authorized_resource_scope`, never `Model.all`, on a multi-tenant portal.
- **Root-qualify packaged models inside a portal dashboard.** Within `module AdminPortal`, `Blogging::Post` resolves to the portal's own `AdminPortal::Blogging` controller namespace and raises `NameError`; write `::Blogging::Post`.
- **`metric` and `chart` blocks return data; `card` blocks render Phlex markup.** A `card` block is `instance_exec`ed in a Phlex component: `div`, `ul`, `render` work, and unknown methods forward to the dashboard.
- **`condition:` gates the card endpoint too** (404 when false), unlike a field `condition:`. Page-level access is `authorize?` on the dashboard (403).
- **`refresh:` needs `lazy: true`** (the default). It reloads the frame; an inline card has no frame. `refresh: false` opts a lazy card out of the dashboard's `refresh`.
- **Chart options other than `type:` / `height:` pass straight to Chartkick.** Unknown metric options raise.
- **Ejected sidebars don't list dashboards automatically.** Portals generated before this feature have their own `_resource_sidebar.html.erb`; add the `registered_dashboards` block (below), which groups them under a "Dashboards" parent after the Home link (`plutonium.resource.nav.home`).

## Minimal dashboard

```ruby
# packages/admin_portal/app/dashboards/admin_portal/sales_dashboard.rb
module AdminPortal
  class SalesDashboard < Plutonium::Dashboard::Base
    presents label: "Sales", description: "Orders and revenue", icon: Phlex::TablerIcons::ChartBar
    refresh 60       # seconds, every lazy card (default off)

    metric(:orders, icon: Phlex::TablerIcons::ShoppingCart, href: -> { resource_url_for(Order, parent: nil) }) do
      {value: orders.where(created_at: 30.days.ago..).count,
       previous: orders.where(created_at: 60.days.ago...30.days.ago).count,
       change_label: "vs. previous 30 days"}
    end
    metric(:revenue, format: :currency) { orders.sum(:total) }
    metric(:refund_rate, format: :percentage, precision: 1, positive: :down) { {value: 2.1, previous: 1.8} }

    chart(:revenue_by_day, type: :area, span: 8) { orders.group_by_day(:created_at, last: 30).sum(:total) }
    chart(:by_channel, type: :donut, span: 4) { orders.group(:channel).count }

    card(:latest, span: :full) do
      ul { latest_orders.each { |o| li { o.number } } }
    end

    def authorize? = current_user.admin?   # optional; default true

    private

    def orders = authorized_resource_scope(Order)
    def latest_orders = orders.order(created_at: :desc).limit(5)
  end
end

# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  register_dashboard AdminPortal::SalesDashboard, at: "sales"   # GET /admin/dashboards/sales, /admin/dashboards/sales/cards/:card
end
```

## Card options (all kinds)

| Option | Meaning |
|---|---|
| `label:` / `description:` | Text; default from `plutonium.dashboards.<key>.cards.<card>.label`, then the key titleized |
| `icon:` | `Phlex::TablerIcons::*` class |
| `span:` | `1`..`12` of a 12-column grid, or `:full` (= 12). Default: metric `3`, chart `6`, card `6`. There is no `columns` macro. Tablet: span >= 6 takes the row, else one of two columns |
| `lazy:` | `true` (own turbo frame, default) / `false` (inline) |
| `refresh:` | seconds, overrides the dashboard's; `false` opts this card out of the dashboard's `refresh` |
| `condition:` | proc (on the instance) or symbol (dashboard method); false hides + 404s |
| `href:` | path or proc; links the title |

## metric

Return a value, or a hash: `value` (required), `previous` (computes % change), `change` (numeric percentage points or a verbatim string), `trend` (`:up`/`:down`/`:flat`, inferred), `change_label`.

Options: `format:` (`:number` default, `:currency`, `:percentage`, `:human`, or `->(v) { ... }`), `precision:`, `unit:` (currency symbol), `prefix:`, `suffix:`, `positive:` (`:up` default, `:down` when falling is good), `change_label:`.

## chart

Return Chartkick data: `{label => value}`, `[[label, value], ...]`, or `[{name:, data:}, ...]`. Date/Time keys draw a time axis. `groupdate` (`group_by_day` etc.) is the natural companion; it is not a dependency.

`type:` `:line` (default), `:area`, `:column`, `:bar`, `:pie`, `:donut`, `:scatter`. `height:` default `"240px"`. Everything else (`colors:`, `stacked:`, `min:`, `max:`, `suffix:`, `xtitle:`, `legend:`, `library:` ...) goes to Chartkick. Colours default to `--pu-chart-1..8`; charts redraw on colour-mode change.

## card

```ruby
card(:onboarding, span: 4) do
  Plutonium::Wizard.in_progress_for(view_context).each do |entry|
    a(href: entry.resume_url, class: "block py-1") { entry.label }
  end
end
```

## Registration

```ruby
register_dashboard HomeDashboard, at: "/"                       # root: replaces `root to: "dashboard#index"`
register_dashboard SalesDashboard, at: "sales"                  # /dashboards/sales, sales_dashboard_path
register_dashboard Reports::WeeklyDashboard, at: "reports/weekly", as: "weekly"
```

- Synthesizes `<Portal>::DashboardsController < <Portal>::PlutoniumController` (auth, tenancy, layout inherited). Define that class yourself, including `Plutonium::Dashboard::Controller`, to customize.
- Entity-scoped portals: URLs carry the scope segment; use `dashboard_path_for(Klass)` rather than a hand-built helper.
- Every non-root mount is drawn under `dashboards/` (`at: "sales"` → `/admin/dashboards/sales`), so it cannot collide with a resource route. Helper names carry no prefix. `prefix: nil` mounts at the bare path (`/admin/sales`, keeping it clear of resource routes is then on you); `prefix: "reports"` swaps the segment.
- Lazy vs inline: see the table below.
- Errors in a card: raised in development/test. In production the card is replaced by a notice, and the error is logged and reported via `Rails.error` (`source: "plutonium.dashboard"`, `context: {dashboard:, card:}`).

## Lazy vs inline (`lazy: false`)

| | `lazy: true` (default) | `lazy: false` (inline) |
|---|---|---|
| Where the block runs | In its own request to `<mount>/cards/<key>`, when the frame scrolls into view | In the page request, before the page is sent |
| What the page response holds | A `<turbo-frame loading="lazy">` with a skeleton | The finished card; no frame, no skeleton, no second request |
| Cost | One extra request per card; the page itself never waits | The page waits for the block, so every inline card adds its query time to the page |
| `refresh` | Reloads on the card's or the dashboard's interval | Never refreshes. A number raises `ArgumentError`; the dashboard's `refresh` skips it |
| `condition:` false | Left out of the page, block never runs, endpoint is 404 | The same |
| Raises in production | Notice in place of the body, logged and reported | The same; the rest of the page still renders |
| Raises in development and test | That card's frame request fails; the page and the other cards are fine | The whole page raises, because the card is part of the page |

Default to lazy. Use `lazy: false` only for a cheap value (cached number, indexed count) near the top of the page; one slow inline card delays the whole page.

## Sidebar (ejected partial)

```erb
dashboards = registered_dashboards.reject { |dashboard| dashboard_path_for(dashboard) == root_path }
if dashboards.any?
  m.item t("plutonium.resource.nav.dashboards"), icon: Phlex::TablerIcons::LayoutDashboard do |n|
    dashboards.each do |dashboard|
      n.item dashboard.label, url: dashboard_path_for(dashboard), icon: dashboard.icon
    end
  end
end
```

## Translations

```yaml
en:
  plutonium:
    dashboards:
      admin_portal/sales:            # Class.i18n_key
        label: "Sales"
        cards:
          orders: { label: "Orders", description: "Last 30 days" }
```

Portal override: `plutonium.portals.<portal>.dashboards...`.

## Testing

Integration-test the page (`get "/admin/dashboards/sales"`, expect one `<turbo-frame ... loading="lazy">` per card) and each card endpoint with the frame header: `get "/admin/dashboards/sales/cards/orders", headers: {"Turbo-Frame" => "pu-dashboard-card-orders"}`. Hidden cards are `:not_found`; a denied `authorize?` is `:forbidden`.

## Full docs

- Guide: `/guides/dashboards`
- Reference: `/reference/dashboard/dsl`, `/reference/dashboard/registration`
