# Dashboard DSL Reference

::: warning Experimental
Dashboards are experimental: the DSL and behavior may change in a future release.
:::

A dashboard is a subclass of `Plutonium::Dashboard::Base`. Everything is declared at class level; an instance is built per request with the view context and is the receiver of every card block.

## Presentation

```ruby
presents label: "Sales", description: "Orders and revenue", icon: Phlex::TablerIcons::ChartBar
```

| Key | Default |
|---|---|
| `label` | `plutonium.dashboards.<key>.label`, then the class name without `Dashboard` |
| `description` | `plutonium.dashboards.<key>.description`, then nothing |
| `icon` | `Phlex::TablerIcons::LayoutDashboard` (used in the sidebar) |

`<key>` is `Class.i18n_key`: the class name underscored without the suffix (`AdminPortal::SalesDashboard` → `admin_portal/sales`). `label` and `description` accept the class-level lazy `t("...")`.

## Board-level options

### refresh(seconds)

Default reload interval for every lazy card. `nil` (the default) disables it.

### width(token)

Page width, one of `:sm`, `:md`, `:lg`, `:xl`, `:full`. Default `:full`.

## Cards

```ruby
metric(key, **options) { ... }
chart(key, **options) { ... }
card(key, **options) { ... }
```

Keys are unique per dashboard; a duplicate raises at class load. Cards render in declaration order.

### Common options

| Option | Type | Default | Meaning |
|---|---|---|---|
| `label:` | String, lazy `t` | convention, then key titleized | Title |
| `description:` | String, lazy `t` | convention | Caption |
| `icon:` | Phlex icon class | none | Shown beside the title |
| `span:` | `1`..`12`, `:full` | metric `3`, chart `6`, card `6` | Columns of the 12-column grid. `:full` is `12`. On tablets (2 columns) a span of `6` or more takes the row; phones are one column |
| `lazy:` | Boolean | `true` | `true`: own lazy turbo frame, block runs in a separate request. `false`: inline, block runs in the page request; no frame, never refreshes. See the [guide](/guides/dashboards#lazy-and-inline-cards) |
| `refresh:` | Integer seconds, or `false` | dashboard `refresh` | Reload interval; requires `lazy: true`. `false` opts the card out of the dashboard's `refresh` |
| `condition:` | Proc, Symbol | none | Hides the card and 404s its endpoint when false |
| `href:` | String, Proc | none | Links the title |

Procs (`condition:`, `href:`, the block) run on the dashboard instance with `instance_exec`; a one-argument proc receives the instance instead.

### Locale conventions

```
plutonium.dashboards.<key>.cards.<card>.label
plutonium.dashboards.<key>.cards.<card>.description
plutonium.portals.<portal>.dashboards.<key>...
```

### metric

The block returns a value or a hash.

| Hash key | Meaning |
|---|---|
| `value` | The number or string. `nil` renders `plutonium.dashboard.metric.empty` |
| `previous` | Computes `change` as a percentage from this value; a zero previous yields no percentage |
| `change` | Numeric percentage points (`2.5` → `+2.5%`) or a string shown as-is |
| `trend` | `:up`, `:down`, `:flat`; inferred from the sign of `change` |
| `change_label` | Caption after the change |

| Option | Values | Meaning |
|---|---|---|
| `format:` | `:number` (default), `:currency`, `:percentage`, `:human`, Proc | How `value` is rendered. A proc receives the value and runs on the dashboard |
| `precision:` | Integer | Decimal places; defaults per format (2 for currency, 1 for percentage, 3 significant for human) |
| `unit:` | String | Currency symbol for `:currency` |
| `prefix:` / `suffix:` | String | Wrapped around the formatted value |
| `positive:` | `:up` (default), `:down` | Which direction is good; drives the change colour |
| `change_label:` | String | Same as the hash key |

### chart

The block returns Chartkick data: `{label => value}`, `[[label, value], ...]` or `[{name:, data:}, ...]`. `Date` and `Time` keys serialise as ISO strings and draw a time axis.

| Option | Values | Meaning |
|---|---|---|
| `type:` | `:line` (default), `:area`, `:column`, `:bar`, `:pie`, `:donut`, `:scatter` | Chartkick chart class |
| `height:` | CSS length | Drawing area height, default `"240px"` |
| anything else | | Passed to Chartkick unchanged: `colors`, `stacked`, `min`, `max`, `prefix`, `suffix`, `thousands`, `decimal`, `xtitle`, `ytitle`, `legend`, `curve`, `points`, `discrete`, `download`, `library`, ... |

The `chart` Stimulus controller merges these over Plutonium's defaults: series colours from `--pu-chart-1` to `--pu-chart-8`, axis text from `--pu-text-muted`, grid lines from `--pu-border`, and the empty-data message from `plutonium.js.charts.empty`. A colour-mode switch redraws every chart.

### card

No kind-specific options. The block is `instance_exec`ed in `Plutonium::UI::Dashboard::Custom`, a Phlex component: it emits markup directly, and any method the component does not define is forwarded to the dashboard instance.

## Instance API

| Method | Meaning |
|---|---|
| `authorize?` | Override to gate the page and every card. Default `true` |
| `visible_cards` | Cards whose `condition:` passes |
| `visible_card!(key)` | The card, or `Plutonium::Dashboard::UnknownCardError` (404) |
| `refresh_for(card)` | The card's interval, else the dashboard's; `nil` for a card declared `refresh: false` |
| `view_context` / `helpers` | The Rails view context |
| `current_user`, `current_scoped_entity`, `scoped_to_entity?`, `params`, `request`, `controller`, `current_engine`, `resource_url_for`, `authorized_resource_scope`, `allowed_to?`, `policy_for`, `registered_resources`, `root_path` | Delegated to the view context |

## Class API

| Method | Meaning |
|---|---|
| `cards` | All declared cards, in order |
| `find_card(key)` / `find_card!(key)` | Lookup by key |
| `label`, `description`, `icon` | Resolved presentation |
| `i18n_key`, `route_name` | `admin_portal/sales`, `sales` |

Subclasses inherit the parent's cards and options by copy, so a portal-specific subclass can add cards without touching the parent.
