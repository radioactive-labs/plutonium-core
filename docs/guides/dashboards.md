# Dashboards

A dashboard is a page of cards: headline numbers, charts and free-form panels, declared in one Ruby class and mounted with a single routes line. Every card loads in its own lazy turbo frame, so the page paints immediately and each card's queries run in a separate request as it scrolls into view.

![A dashboard with four metric cards, an area chart of signups per day, a donut chart and a full-width welcome card](/images/guides/dashboard-overview.png)

## What you get

- A `Plutonium::Dashboard::Base` subclass with a class-level DSL: `metric`, `chart` and `card`.
- `register_dashboard` in a portal's routes draws the page, the per-card endpoint and a synthesized controller that inherits the portal's auth, tenant scoping and layout.
- Metric cards format numbers (delimited, currency, percentage, human) and show a change indicator against a previous value.
- Chart cards render with [Chart.js](https://www.chartjs.org/) through [Chartkick](https://chartkick.com/), using Plutonium's design tokens in light and dark mode. The chart bundle loads on demand, so pages without a chart never download it.
- Cards can refresh themselves on an interval, span several grid columns, link somewhere, and hide behind a condition.
- Registered dashboards appear in the portal sidebar.

## Worked example

### 1. Generate the dashboard

```bash
rails g pu:dashboard Sales --dest=admin_portal
```

This writes `packages/admin_portal/app/dashboards/admin_portal/sales_dashboard.rb` and adds `register_dashboard AdminPortal::SalesDashboard, at: "sales"` to the portal's routes. Pass `--at=/` to mount the dashboard as the portal root instead; the generator then replaces the portal's `root to: "dashboard#index"` line.

### 2. Declare the cards

```ruby
module AdminPortal
  class SalesDashboard < Plutonium::Dashboard::Base
    presents label: "Sales", description: "Orders and revenue at a glance",
      icon: Phlex::TablerIcons::ChartBar

    columns 4
    refresh 60

    metric(:orders, icon: Phlex::TablerIcons::ShoppingCart,
      href: -> { resource_url_for(Order, parent: nil) }) do
      {value: orders.where(created_at: 30.days.ago..).count,
       previous: orders.where(created_at: 60.days.ago...30.days.ago).count,
       change_label: "vs. previous 30 days"}
    end

    metric(:revenue, format: :currency) { orders.sum(:total) }

    metric(:refund_rate, format: :percentage, precision: 1, positive: :down) do
      {value: refund_rate, previous: previous_refund_rate}
    end

    metric(:customers, format: :human) { Customer.count }

    chart(:revenue_by_day, type: :area, span: 2) do
      orders.group_by_day(:created_at, last: 30).sum(:total)
    end

    chart(:by_channel, type: :donut, span: 2) do
      orders.group(:channel).count
    end

    card(:latest, span: :full) do
      ul(class: "divide-y divide-[var(--pu-border-muted)]") do
        latest_orders.each do |order|
          li(class: "py-2 flex justify-between") do
            span { order.number }
            span(class: "text-[var(--pu-text-muted)]") { helpers.number_to_currency(order.total) }
          end
        end
      end
    end

    private

    def orders = authorized_resource_scope(Order)
    def latest_orders = orders.order(created_at: :desc).limit(5)
    def refund_rate = 100.0 * orders.refunded.count / [orders.count, 1].max
    def previous_refund_rate = 1.8
  end
end
```

`group_by_day` comes from the [groupdate](https://github.com/ankane/groupdate) gem, which pairs well with chart cards but is not required.

### 3. Visit it

The page is at `/admin/sales`. Each card is a `<turbo-frame src="/admin/sales/cards/<key>" loading="lazy">` holding a skeleton until its response lands.

## Cards

All three kinds share the same options:

| Option | Meaning |
|---|---|
| `label:` | Card title. Defaults to a locale convention, then the key titleized. |
| `description:` | Caption under the title. |
| `icon:` | A `Phlex::TablerIcons::*` class shown beside the title. |
| `span:` | Grid columns to span: `1` to `6`, or `:full`. A span wider than the grid collapses to the full row. |
| `lazy:` | `true` (default) loads the card in its own turbo frame; `false` renders it inline with the page. |
| `refresh:` | Seconds between automatic reloads of the card's frame. Needs `lazy: true`. |
| `condition:` | A proc or a symbol naming a dashboard method. When false the card is left out of the page and its endpoint responds 404. |
| `href:` | A path, or a proc returning one, that links the title. |

Blocks run on the dashboard instance, which exposes `current_user`, `current_scoped_entity`, `params`, `authorized_resource_scope`, `resource_url_for`, `allowed_to?`, `helpers` (the view context) and the dashboard's own private methods. A one-argument block receives the dashboard instead.

### Metric

The block returns a value, or a hash with a change:

```ruby
metric(:signups) { User.count }                                       # just the number
metric(:mrr, format: :currency) { {value: 12_400, previous: 11_000} } # +12.7%
metric(:latency, suffix: " ms") { {value: 182, change: "-14 ms", trend: :down} }
metric(:churn, format: :percentage, positive: :down) { {value: 1.2, previous: 1.0} }
```

| Key | Meaning |
|---|---|
| `value` | The number (or string) to show. `nil` renders an em dash. |
| `previous` | Computes the percentage change from this value. |
| `change` | A number in percentage points (`2.5` renders `+2.5%`) or a string shown verbatim. |
| `trend` | `:up`, `:down` or `:flat`. Inferred from the sign of `change` when omitted. |
| `change_label` | Caption after the change, such as "vs. last month". Also a card option. |

Metric options: `format:` (`:number`, `:currency`, `:percentage`, `:human`, or a proc receiving the value), `precision:`, `unit:` (currency symbol), `prefix:`, `suffix:`, `positive:` (`:up` by default; `:down` when a falling number is good) and `change_label:`.

### Chart

The block returns [Chartkick data](https://chartkick.com/#data): a `{label => value}` hash, an array of pairs, or an array of `{name:, data:}` series. Date and time keys become a time axis.

```ruby
chart(:signups, type: :line) { User.group_by_day(:created_at, last: 30).count }
chart(:plans, type: :pie) { Subscription.group(:plan).count }
chart(:traffic, type: :column, stacked: true) do
  [{name: "Web", data: web_by_week}, {name: "Mobile", data: mobile_by_week}]
end
```

`type:` is one of `:line`, `:area`, `:column`, `:bar`, `:pie`, `:donut` or `:scatter`; `height:` sets the drawing area (default `"240px"`). Every other option (`colors:`, `stacked:`, `min:`, `max:`, `prefix:`, `suffix:`, `xtitle:`, `ytitle:`, `legend:`, `curve:`, `points:`, `library:`, ...) is passed straight through to Chartkick. Series colours default to the `--pu-chart-1` to `--pu-chart-8` design tokens.

### Custom

The block renders Phlex markup inside the card body. It is evaluated in the card component, so `div`, `ul`, `render` and the rest are available, and any method it calls that the component lacks is forwarded to the dashboard.

```ruby
card(:onboarding, description: "Where new tenants are") do
  Plutonium::Wizard.in_progress_for(view_context).each do |entry|
    a(href: entry.resume_url, class: "block py-1") { entry.label }
  end
end
```

## Layout

`columns n` sets the grid on large screens (1 to 6, default 3); tablets get two columns and phones one. `width` takes the same tokens as resource pages (`:sm` to `:full`) and defaults to `:full`.

## Refreshing

`refresh 60` on the dashboard reloads every lazy card once a minute; `refresh: 10` on a card overrides it. Reloads pause while the tab is hidden and catch up when it becomes visible. A chart re-renders in place when its data changes.

## Authorization

A portal dashboard sits behind the portal's authentication like every other page. To restrict it further, override `authorize?`; a false answer is a 403 on the page and on every card endpoint:

```ruby
def authorize? = current_user.admin?
```

Use `condition:` to hide an individual card. The condition gates the card's endpoint as well, so a hidden card cannot be fetched by URL.

## Errors

When `config.consider_all_requests_local` is off (production), a card whose block raises reports the error through `Rails.error` and renders a short notice in its place. The rest of the dashboard is unaffected. In development and test the error is raised so it is visible.

## Multi-tenancy

On an entity-scoped portal the page and card URLs carry the tenant segment, and `current_scoped_entity` is available in every block:

```ruby
class TeamDashboard < Plutonium::Dashboard::Base
  metric(:members) { current_scoped_entity.memberships.count }
end
```

## Sidebar

Dashboards registered with `register_dashboard` are listed in the portal sidebar after the Dashboard link, using `presents icon:`. A dashboard mounted at the root is the Dashboard link. Portals generated before this feature carry an ejected `_resource_sidebar.html.erb`; add the loop from the gem's partial to list dashboards there:

```erb
registered_dashboards.each do |dashboard|
  url = dashboard_path_for(dashboard)
  next if url == root_path

  m.item dashboard.label, url: url, icon: dashboard.icon
end
```

## Translations

Titles resolve by convention, layered per portal like every other derived label:

```yaml
en:
  plutonium:
    dashboards:
      admin_portal/sales:
        label: "Ventes"
        description: "Commandes et chiffre d'affaires"
        cards:
          orders:
            label: "Commandes"
```

The dashboard key is the class name underscored without the `Dashboard` suffix. See the [i18n reference](/reference/i18n).

## Customizing the page

The page is `Plutonium::UI::Page::Dashboard`, a `Page::Base` with the usual `render_before_*` and `render_after_*` hooks. To take it over, define `<Portal>::DashboardsController` yourself, include `Plutonium::Dashboard::Controller`, and override `show`:

```ruby
module AdminPortal
  class DashboardsController < PlutoniumController
    include Plutonium::Dashboard::Controller

    def show
      authorize_dashboard!
      render CustomDashboardPage.new(dashboard: current_dashboard)
    end
  end
end
```
