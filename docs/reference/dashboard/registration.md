# Dashboard Registration

## register_dashboard

```ruby
AdminPortal::Engine.routes.draw do
  register_dashboard AdminPortal::HomeDashboard, at: "/"       # the portal root
  register_dashboard AdminPortal::SalesDashboard, at: "sales"  # /admin/sales
  register_dashboard Reports::WeeklyDashboard, at: "reports/weekly", as: "weekly"
end
```

| Argument | Meaning |
|---|---|
| `at:` | Portal-relative path. `"/"` or `""` mounts at the engine root |
| `as:` | Route helper prefix. Defaults to `at:` with slashes replaced, or the class slug for a root mount |

### Routes drawn

```
GET /sales             → DashboardsController#show   sales_dashboard_path
GET /sales/cards/:card → DashboardsController#card   sales_dashboard_card_path
```

A root mount draws `root` for the page and `/<as>/cards/:card` for the cards. Replace the portal's generated `root to: "dashboard#index"` line with the registration; two root routes clash.

On a `:path` entity-scoped portal the routes sit inside the scope segment and the helpers are prefixed (`organization_scoped_sales_dashboard_path`). URLs built by the framework thread the current tenant through; when building your own use `dashboard_path_for(SalesDashboard)`, available in controllers, views and components.

### The controller

`register_dashboard` synthesizes `<Portal>::DashboardsController < <Portal>::PlutoniumController` including `Plutonium::Dashboard::Controller` and the portal's `Concerns::Controller`, so it carries the portal's authentication, entity scoping and layout. On the main app it synthesizes a bare `::DashboardsController < ApplicationController`.

Define the class yourself to take over; the synthesized one is only created when the constant is missing.

```ruby
module AdminPortal
  class DashboardsController < PlutoniumController
    include Plutonium::Dashboard::Controller

    before_action { set_page_title("Reports") }
  end
end
```

The concern provides `show` and `card`, `current_dashboard`, `current_dashboard_class`, `authorize_dashboard!` and `dashboard_card_path(card)`.

### The card endpoint

`GET <mount>/cards/:card` runs `authorize?`, looks the key up among the dashboard's cards, checks its `condition:`, and renders the card inside `<turbo-frame id="pu-dashboard-card-<key>">`. Unknown or hidden cards respond 404 (`Plutonium::Dashboard::UnknownCardError`); a denied `authorize?` responds 403. A request without a `Turbo-Frame` header renders the card inside the full layout.

## Sidebar

`registered_dashboards` (a controller helper, also available in components) lists the dashboards mounted on the current engine, and `dashboard_path_for(klass)` builds each page path. The gem's `_resource_sidebar.html.erb` lists them after the Dashboard link, skipping the one mounted at the root.

## Generator

```bash
rails g pu:dashboard Sales --dest=admin_portal            # /admin/sales
rails g pu:dashboard Home --dest=admin_portal --at=/      # portal root
rails g pu:dashboard Reporting --dest=main_app --at=reports
```

Writes `app/dashboards/<portal>/<name>_dashboard.rb` in the package (or `app/dashboards/` for `main_app`) and adds the `register_dashboard` line to the routes. Idempotent.

## Assets

Chart cards load `plutonium-charts.js` (Chart.js and Chartkick) on demand; the file ships with the gem beside `plutonium.js` and is precompiled with it. `Plutonium.configuration.assets.charts_script` names the asset (`"plutonium-charts.min.js"` by default). When `PLUTONIUM_DEV` is set the file comes from the `src/build` manifest like the main bundle.
