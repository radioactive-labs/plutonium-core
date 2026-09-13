---
name: plutonium-dashboard
description: Use BEFORE building a dashboard, KPI page, metrics overview or chart page in a Plutonium app — Plutonium::Dashboard::Base, the metric / chart / card DSL, register_dashboard, lazy turbo-frame cards, refresh, conditions, authorize?, and the pu:dashboard generator. The single source for "how do I add a dashboard with metric cards and charts".
---

# Plutonium Dashboards

A dashboard is a class of cards (`metric`, `chart`, `card`) mounted in a portal with one routes line. Every card loads in its own lazy turbo frame, so the page paints at once and each card's queries run in a separate request. Charts render with Chart.js through Chartkick, styled by Plutonium's design tokens.

For resources and their definitions see [[plutonium-resource]]; for portals and routes see [[plutonium-app]]; for custom Phlex markup inside a card see [[plutonium-ui]].

## 🚨 Critical (read first)

- **Generate, don't hand-write:** `rails g pu:dashboard Sales --dest=admin_portal` writes the class AND the `register_dashboard` line. `--at=/` mounts it as the portal root and replaces the generated `root to: "dashboard#index"` (two roots clash).
- **Dashboards live in `app/dashboards/`** (`packages/<portal>/app/dashboards/<portal>/` in a package). Class name ends in `Dashboard`; the label drops the suffix.
- **Card blocks run on the dashboard instance**, not the controller: use `current_user`, `current_scoped_entity`, `authorized_resource_scope(Model)`, `resource_url_for`, `helpers`, and the dashboard's own private methods. Scope queries with `authorized_resource_scope`, never `Model.all`, on a multi-tenant portal.
- **`metric` and `chart` blocks return data; `card` blocks render Phlex markup.** A `card` block is `instance_exec`ed in a Phlex component: `div`, `ul`, `render` work, and unknown methods forward to the dashboard.
- **`condition:` gates the card endpoint too** (404 when false), unlike a field `condition:`. Page-level access is `authorize?` on the dashboard (403).
- **`refresh:` needs `lazy: true`** (the default). It reloads the frame; an inline card has no frame.
- **Chart options other than `type:` / `height:` pass straight to Chartkick.** Unknown metric options raise.
- **Ejected sidebars don't list dashboards automatically.** Portals generated before this feature have their own `_resource_sidebar.html.erb`; add the `registered_dashboards` loop (below).

## Minimal dashboard

```ruby
# packages/admin_portal/app/dashboards/admin_portal/sales_dashboard.rb
module AdminPortal
  class SalesDashboard < Plutonium::Dashboard::Base
    presents label: "Sales", description: "Orders and revenue", icon: Phlex::TablerIcons::ChartBar
    columns 4        # lg grid columns, 1..6 (default 3)
    refresh 60       # seconds, every lazy card (default off)

    metric(:orders, icon: Phlex::TablerIcons::ShoppingCart, href: -> { resource_url_for(Order, parent: nil) }) do
      {value: orders.where(created_at: 30.days.ago..).count,
       previous: orders.where(created_at: 60.days.ago...30.days.ago).count,
       change_label: "vs. previous 30 days"}
    end
    metric(:revenue, format: :currency) { orders.sum(:total) }
    metric(:refund_rate, format: :percentage, precision: 1, positive: :down) { {value: 2.1, previous: 1.8} }

    chart(:revenue_by_day, type: :area, span: 2) { orders.group_by_day(:created_at, last: 30).sum(:total) }
    chart(:by_channel, type: :donut, span: 2) { orders.group(:channel).count }

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
  register_dashboard AdminPortal::SalesDashboard, at: "sales"   # GET /admin/sales, /admin/sales/cards/:card
end
```

## Card options (all kinds)

| Option | Meaning |
|---|---|
| `label:` / `description:` | Text; default from `plutonium.dashboards.<key>.cards.<card>.label`, then the key titleized |
| `icon:` | `Phlex::TablerIcons::*` class |
| `span:` | `1`..`6` or `:full`; wider than `columns` collapses to the row |
| `lazy:` | `true` (own turbo frame, default) / `false` (inline) |
| `refresh:` | seconds; overrides the dashboard's |
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
card(:onboarding, span: 2) do
  Plutonium::Wizard.in_progress_for(view_context).each do |entry|
    a(href: entry.resume_url, class: "block py-1") { entry.label }
  end
end
```

## Registration

```ruby
register_dashboard HomeDashboard, at: "/"                       # root: replaces `root to: "dashboard#index"`
register_dashboard SalesDashboard, at: "sales"                  # sales_dashboard_path
register_dashboard Reports::WeeklyDashboard, at: "reports/weekly", as: "weekly"
```

- Synthesizes `<Portal>::DashboardsController < <Portal>::PlutoniumController` (auth, tenancy, layout inherited). Define that class yourself, including `Plutonium::Dashboard::Controller`, to customize.
- Entity-scoped portals: URLs carry the scope segment; use `dashboard_path_for(Klass)` rather than a hand-built helper.
- Errors in a card: raised in development/test, reported via `Rails.error` and replaced by a notice in production.

## Sidebar (ejected partial)

```erb
registered_dashboards.each do |dashboard|
  url = dashboard_path_for(dashboard)
  next if url == root_path
  m.item dashboard.label, url: url, icon: dashboard.icon
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

Integration-test the page (`get "/admin/sales"`, expect one `<turbo-frame ... loading="lazy">` per card) and each card endpoint with the frame header: `get "/admin/sales/cards/orders", headers: {"Turbo-Frame" => "pu-dashboard-card-orders"}`. Hidden cards are `:not_found`; a denied `authorize?` is `:forbidden`.

## Full docs

- Guide: `/guides/dashboards`
- Reference: `/reference/dashboard/dsl`, `/reference/dashboard/registration`
