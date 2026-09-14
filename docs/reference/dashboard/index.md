# Dashboard Reference

Reference documentation for Plutonium dashboards: pages of metric, chart and free-form cards, each loaded in its own lazy turbo frame.

## In this section

| Page | What it covers |
|------|---------------|
| [DSL](/reference/dashboard/dsl) | `Plutonium::Dashboard::Base`, `presents`, `columns`, `refresh`, `width`, and the `metric` / `chart` / `card` macros with every option |
| [Registration](/reference/dashboard/registration) | `register_dashboard`, the routes it draws, the synthesized controller, the sidebar, and the `pu:dashboard` generator |

## Quick start

```ruby
# packages/admin_portal/app/dashboards/admin_portal/sales_dashboard.rb
module AdminPortal
  class SalesDashboard < Plutonium::Dashboard::Base
    presents label: "Sales", icon: Phlex::TablerIcons::ChartBar

    metric(:orders) { {value: Order.this_month.count, previous: Order.last_month.count} }
    chart(:revenue, type: :area, span: 2) { Order.group_by_day(:created_at).sum(:total) }
  end
end

# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  register_dashboard AdminPortal::SalesDashboard, at: "sales"
end
```

See the [Dashboards guide](/guides/dashboards) for a full walkthrough.
