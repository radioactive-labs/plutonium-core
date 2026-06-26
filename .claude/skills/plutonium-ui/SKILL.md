---
name: plutonium-ui
description: Use BEFORE building or customizing any Plutonium UI — page classes, forms, displays, tables, custom Phlex components, layouts, Stimulus controllers, Tailwind config, design tokens, themes, or component classes. Covers the full view + asset toolchain.
---

# Plutonium UI — Pages, Forms, Components, Assets

Plutonium uses Phlex for all view components and TailwindCSS 4 + Stimulus for the frontend. This skill covers everything from overriding a single page to writing custom Phlex components, configuring Tailwind, and theming via design tokens.

For field-level rendering (`field :foo, as: :markdown`, `display :status do |f| ... end`), see [[plutonium-resource]] › Custom Rendering. For controller render-context hooks (`present_parent?`, `submit_parent?`), see [[plutonium-behavior]].

## 🚨 Critical (read first)

- **Override via nested classes in the definition.** `class ShowPage < ShowPage; end`, `class Form < Form; end`. Don't replace the entire view layer.
- **Use render hooks, not `view_template`.** `render_before_content`, `render_after_content`, `render_before_toolbar`, etc. exist so you don't reimplement the whole page.
- **All pages inherit `DynaFrameContent`** — turbo-frame requests render only the content. Don't fight it; modals and frame nav "just work".
- **Custom components inherit `Plutonium::UI::Component::Base`** — gives you the component kit (`PageHeader`, `Panel`, `Block`), resource helpers, and the `helpers` proxy for Rails helpers.
- **`render_actions` is mandatory in custom `form_template`** — without it, the form has no submit button.
- **Always `registerControllers(application)`** in `app/javascript/controllers/index.js`. Without it, Plutonium's Stimulus controllers (color-mode, form, slim-select, flatpickr, easymde, etc.) are dead.
- **Use `plutoniumTailwindConfig.merge`** when extending Tailwind theme — plain object merge drops Plutonium's defaults.
- **Prefer `.pu-*` classes and `var(--pu-*)` tokens** over hardcoded `gray-X/dark:gray-Y` pairs — they switch with dark mode automatically.
- **Configure inputs in the definition; render them with `render_resource_field` in the form.** Don't reimplement field widgets from scratch.

---

# Part 1 — Pages

Each definition has nested page classes. Override the ones you need to customize:

```ruby
class PostDefinition < ResourceDefinition
  class IndexPage              < IndexPage; end
  class ShowPage               < ShowPage; end
  class NewPage                < NewPage; end
  class EditPage               < EditPage; end
  class InteractiveActionPage  < InteractiveActionPage; end
  class Form                   < Form; end
  class Table                  < Table; end
  class Display                < Display; end
end
```

Architecture:

```
Definition
├── IndexPage   → renders Table
├── ShowPage    → renders Display
├── NewPage     → renders Form
├── EditPage    → renders Form
└── InteractiveActionPage → renders Form
```

## Page titles, descriptions, breadcrumbs

```ruby
class PostDefinition < ResourceDefinition
  index_page_title       "Blog Posts"
  index_page_description "Manage all published articles"
  show_page_title        "Article Details"
  show_page_title        -> { "#{current_record!.title} — Details" }   # dynamic

  breadcrumbs              true     # global default
  index_page_breadcrumbs   false    # per-page override
end
```

## Page hooks (preferred over `view_template`)

Every page inherits these:

| Hook | Position |
|---|---|
| `render_before_header` / `_after_header` | wraps the entire header section |
| `render_before_breadcrumbs` / `_after_breadcrumbs` | around the breadcrumb row |
| `render_before_page_header` / `_after_page_header` | around the title + actions block |
| `render_before_toolbar` / `_after_toolbar` | around the action toolbar |
| `render_before_content` / `_after_content` | around main content |
| `render_before_footer` / `_after_footer` | around footer/pagination |

Example:

```ruby
class ShowPage < ShowPage
  private

  def page_title
    "#{object.title} — #{object.author.name}"
  end

  def render_before_content
    div(class: "alert alert-info") do
      plain "This post has #{object.comments.count} comments"
    end
  end

  def render_after_content
    render RelatedPostsComponent.new(post: object)
  end

  def render_toolbar
    div(class: "flex gap-2") do
      button(class: "pu-btn pu-btn-md pu-btn-secondary") { "Preview" }
      button(class: "pu-btn pu-btn-md pu-btn-primary") { "Publish" }
    end
  end
end
```

## Custom ERB views (full replacement)

For total control, drop the page class entirely with an ERB view at the controller path:

```
app/views/posts/show.html.erb
packages/admin_portal/app/views/admin_portal/posts/show.html.erb
```

The default view simply renders the page class:

```erb
<%= render current_definition.show_page_class.new %>
```

Mix: keep the default and add chrome around it:

```erb
<div class="announcement-banner">Special announcement</div>
<%= render current_definition.show_page_class.new %>
<div class="related"><%= render partial: "related" %></div>
```

## Detecting render context

| Helper | True when |
|---|---|
| `in_frame?` | Request targets a turbo-frame |
| `in_modal?` | Request renders inside a modal/slideover |

Use to pin action strips, omit nav chrome, or swap layouts.

---

# Part 2 — Forms

Forms are built on [Phlexi::Form](https://github.com/radioactive-labs/phlexi-form). Hierarchy:

```
Phlexi::Form::Base
└── Plutonium::UI::Form::Base
    ├── Plutonium::UI::Form::Resource         # CRUD
    │   └── Plutonium::UI::Form::Interaction  # action forms
    └── Plutonium::UI::Form::Query            # search/filter
```

## Override the form

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    def form_template
      render_fields       # render every permitted field
      render_actions      # submit buttons — REQUIRED
    end
  end
end
```

### Form methods

| Method | Purpose |
|---|---|
| `form_template` | Main override point |
| `render_fields` | All permitted fields in default layout |
| `render_resource_field(name)` | One field, using the definition's `input` config |
| `render_actions` | Submit + secondary buttons |
| `fields_wrapper { ... }` | Grid wrapper div (themeable) |
| `actions_wrapper { ... }` | Button wrapper div (themeable) |
| `object` / `record` | The form record |
| `resource_fields` | Array of permitted field names |
| `resource_definition` | The definition instance |

## Custom layouts

### Sectioned — prefer the `form_layout` DSL

**For grouping fields into sections, don't hand-roll a `Form` subclass — declare `form_layout` in the definition.** It handles headings, descriptions, collapsible `<details>`, per-section `columns:`, `condition:`-based visibility, and **auto-drops sections that resolve to zero fields** (so `+ New` doesn't sprout empty headings). See [[plutonium-resource]] › Form Layout.

```ruby
class PostDefinition < ResourceDefinition
  form_layout do
    section :basic, :title, :slug, label: "Basic"
    section :publishing, :published_at, :category, label: "Publishing", columns: 2
    ungrouped label: "Other"
  end
end
```

Only drop to a custom `Form#form_template` when you need layout the DSL can't express (arbitrary wrapper markup, interleaved non-field content). The escape hatch:

```ruby
class Form < Form
  def form_template
    section("Basic") do
      render_resource_field :title
      render_resource_field :slug
    end

    section("Publishing") do
      render_resource_field :published_at
      render_resource_field :category
    end

    render_actions
  end

  private

  def section(title, &)
    div(class: "mb-8") do
      h3(class: "text-lg font-semibold mb-4 text-[var(--pu-text)]") { title }
      fields_wrapper(&)
    end
  end
end
```

A hand-rolled `section` like this renders its heading unconditionally — that's exactly the empty-heading problem `form_layout` avoids. If you must hand-roll, guard empty sections yourself.

### Two-column

```ruby
def form_template
  div(class: "grid grid-cols-1 lg:grid-cols-3 gap-6") do
    div(class: "lg:col-span-2") do
      fields_wrapper do
        render_resource_field :title
        render_resource_field :content
      end
    end

    div(class: "space-y-4") do
      Panel do
        h4(class: "font-medium mb-2") { "Settings" }
        render_resource_field :status
        render_resource_field :visibility
      end
    end
  end
  render_actions
end
```

## Field builder (`field(:foo).input_tag`)

`render_resource_field` uses the input config from the definition. For ad-hoc rendering, use `field(...)` directly:

```ruby
render field(:title).wrapped { |f| f.input_tag }                # wrapped: label + hint + errors
render field(:title).input_tag                                  # bare element only
render field(:title).wrapped(class: "col-span-full") { |f| f.input_tag }
```

### Tag methods

| Tag | Input |
|---|---|
| `input_tag` | text (auto-detected type) |
| `string_tag`, `text_tag`, `number_tag`, `email_tag`, `password_tag`, `url_tag`, `tel_tag`, `hidden_tag` | standard HTML inputs |
| `checkbox_tag`, `select_tag`, `radio_button_tag` | standard |
| `toggle_tag` / `switch_tag` | switch-styled boolean (`as: :toggle` / `:switch`) — default for boolean columns; `as: :boolean` for a plain checkbox |

### Plutonium-enhanced tags

| Tag | Component |
|---|---|
| `easymde_tag` / `markdown_tag` | EasyMDE markdown editor |
| `slim_select_tag` | Slim Select |
| `flatpickr_tag` | Flatpickr date/time picker |
| `phone_tag` / `int_tel_input_tag` | intl-tel-input phone field |
| `uppy_tag` / `file_tag` | Uppy file upload |
| `secure_association_tag` | Association with policy-checked options |
| `belongs_to_tag` / `has_many_tag` / `has_one_tag` | Association selects |
| `key_value_store_tag` | Key/value pairs editor |

```ruby
render field(:published_at).wrapped { |f| f.flatpickr_tag(min_date: Date.today, enable_time: true) }
render field(:avatar).wrapped       { |f| f.uppy_tag(allowed_file_types: %w[.jpg .png], max_file_size: 5.megabytes) }
```

### Password & secret fields

`password_tag` masks the stored value — it **never emits the secret into the DOM**. A stored secret renders a sentinel; an untouched submit keeps it, an edit-to-new-value then failed re-render comes back blank + `required` (re-type — secrets are never echoed back), a *cleared* field comes back blank but **not** `required` (the clear may be intentional), a deliberately emptied field clears it (clear-by-blank), a typed value sets it. The sentinel is guarded by the `password-sentinel` Stimulus controller — the first edit (incl. **backspace**) wipes the whole field so a partial edit can't corrupt it.

Auto-detected by name: `password`/`token`/`salt`, `encrypted_*`, `*_password`/`*_digest`/`*_hash`/`*_token`/`*_key`/`*_salt`, or any name containing `secret`. A convenience, **not** a guarantee — odd-named secrets (`recovery_phrase`, `pin`) still leak unless masked explicitly.

```ruby
field :api_token,   as: :string     # opt OUT — show a readable value (token to copy, checksum)
field :recovery_phrase, as: :password   # opt IN  — mask a secret the heuristic misses
```

## Submit buttons

Default `render_actions` produces the primary submit, plus an optional "Save and add another" / "Update and continue editing" secondary button.

Control the secondary button via the definition:

```ruby
class PostDefinition < ResourceDefinition
  submit_and_continue false   # nil (default — auto), true (always show), false (always hide)
end
```

Singular resources auto-hide it.

Custom action strip:

```ruby
def render_actions
  actions_wrapper do
    a(href: resource_url_for(resource_class), class: "pu-btn pu-btn-md pu-btn-secondary") { "Cancel" }
    button(type: :submit, name: "draft", value: "1", class: "pu-btn pu-btn-md") { "Save Draft" }
    render submit_button
  end
end
```

## Pre-submit, nested inputs, interaction forms

These all live in the definition layer:

- **Pre-submit / dynamic forms** — see [[plutonium-resource]] › Dynamic Forms.
- **Nested inputs** (`nested_input :variants`) — association-backed inline forms; see [[plutonium-resource]] › Nested Inputs.
- **Structured inputs** (`structured_input :payload`, `structured_input :rows, repeat: 5`) — classless hash / array-of-hashes into a JSON column (resources) or an attribute (interactions); reuses the repeater chrome. See [[plutonium-resource]] › Structured Inputs.
- **Interaction forms** — interactions define their own `attribute` / `input` and inherit `Plutonium::UI::Form::Interaction`; see [[plutonium-behavior]] › Interactions.

---

# Part 3 — Display & Table

## Custom Display

```ruby
class PostDefinition < ResourceDefinition
  class Display < Display
    def display_template
      div(class: "bg-gradient-to-r from-primary-500 to-secondary-600 p-8 rounded-lg text-white mb-6") do
        h1(class: "text-3xl font-bold") { object.title }
        p(class: "mt-2 opacity-90") { object.excerpt }
      end

      Block do
        fields_wrapper do
          render_resource_field :author
          render_resource_field :published_at
        end
      end

      Block do
        div(class: "prose max-w-none") { raw object.content }
      end

      render_associations if present_associations?
    end
  end
end
```

| Method | Purpose |
|---|---|
| `render_fields` | All permitted fields |
| `render_resource_field(name)` | One field |
| `render_associations` | Association tabs (driven by `permitted_associations` — see [[plutonium-behavior]]) |
| `object` | The record |
| `resource_fields`, `resource_associations` | Permitted lists |

## Custom Table

```ruby
class PostDefinition < ResourceDefinition
  class Table < Table
    def view_template
      render_toolbar
      render_scopes_pills

      if collection.empty?
        render_empty_card
      else
        # Replace the table with a card grid
        div(class: "grid grid-cols-3 gap-4") do
          collection.each { |post| render PostCardComponent.new(post:) }
        end
      end

      render_footer
    end
  end
end
```

| Method | Purpose |
|---|---|
| `render_toolbar`, `render_scopes_pills`, `render_filter_pills`, `render_bulk_actions_toolbar` | Toolbar pieces |
| `render_table` | Default table |
| `render_empty_card` | Empty state |
| `render_footer` | Pagination |
| `collection` | Paginated records |
| `resource_fields` | Column field names |

---

# Part 4 — Component Kit & Custom Components

## Built-in shorthand kit

Inside any `Plutonium::UI::Component::Base` (or any page/form/display):

```ruby
PageHeader(title: "Dashboard", description: "...", actions: [...])
Panel(class: "mt-4") { p { "Content" } }
Block { TabList(items: tabs) }
Avatar(user)                      # profile image: src → Navii fallback → icon
EmptyCard("No items found")
ActionButton(action, url: "/posts/new")
DynaFrameHost(src: "/some/path", loading: :lazy)
DynaFrameContent(content) { |frame| frame.render_content }
TableSearchBar()
TableScopesBar()
TableInfo(pagy)
TablePagination(pagy)
Breadcrumbs()
```

## Avatar

`Avatar(subject = nil, src: nil, size: :md, alt: nil, **attrs)` — profile image with a deterministic [Navii](https://navii.dev) fallback. Registered in the kit.

```ruby
Avatar(user)                      # Navii fallback seeded from the record
Avatar(user, src: :avatar)        # user.avatar if present, else Navii fallback
Avatar(user, src: user.avatar)    # pass the attachment/uploader/URL directly
Avatar("acme-team")               # String subject = deterministic seed
Avatar("https://.../p.png")       # URL-shaped subject is shown as the image
Avatar(src: avatar_url)           # bare image, no subject/fallback
```

- **subject** (positional): record → PII-free hashed seed + default `alt` (display name); String → seed. A URL-shaped String (`http(s)://…` or `/…`) is routed to `src` (shown as the image), not used as a seed.
- **src**: a Symbol is sent to the subject (`:avatar` → `subject.avatar`, a **contract** — raises if absent); otherwise an ActiveStorage attachment, active_shrine/Shrine uploader, or URL string. ActiveStorage resolves via `helpers.url_for`; everything else via its own `#url`.
- **size**: `:xs 24 / :sm 32 / :md 40 / :lg 48 / :xl 64`, or a raw Integer.
- **Privacy**: the value sent to Navii is **always** a SHA256 hash — no ids, emails, or seed strings leave the app. Deterministic per subject.
- **Resolution order**: resolved `src` → Navii (from subject) → generic user icon.
- **Config**: `config.navii_host_url` (default `https://api.navii.dev`); the component appends `/avatar/:seed`.

🚨 Ejected shells: `Avatar` only shows a Navii avatar when `NavUser` is passed `record:`. The gem's `_resource_header.html.erb` passes `record: (current_user if current_user.respond_to?(:id))`; portals that **ejected** the header before this must re-eject (`rails g pu:eject:shell --dest=<portal>`) or add the `record:` line, otherwise they keep the icon fallback. Pass a record only — a String `current_user` (e.g. a guest) would otherwise be seeded as a literal identity.

## Custom Phlex components

```ruby
class PostCardComponent < Plutonium::UI::Component::Base
  def initialize(post:)
    @post = post
  end

  def view_template
    div(class: "bg-[var(--pu-card-bg)] border border-[var(--pu-card-border)] rounded-[var(--pu-radius-lg)] p-4") do
      h3(class: "font-bold text-[var(--pu-text)]") { @post.title }
      p(class: "text-[var(--pu-text-muted)] mt-2") { @post.excerpt }
      a(href: resource_url_for(@post), class: "text-primary-600") { "Read more" }
    end
  end
end
```

Use in a definition:

```ruby
display :card, as: PostCardComponent     # custom display component
input   :color, as: ColorPickerComponent # custom input component

display :metrics do |field|
  MetricsChartComponent.new(data: field.value)
end
```

## `DynaFrameContent` pattern

Enables frame-aware rendering: regular requests get the full page (header + content + footer); turbo-frame requests get only the content inside the frame.

```ruby
def view_template(&block)
  DynaFrameContent(page_content(block)) do |frame|
    render_header        # skipped for frame requests
    frame.render_content # always rendered
    render_footer        # skipped for frame requests
  end
end
```

All pages inherit this. Modals and frame navigation work without special handling.

---

# Part 5 — Modals, Slideovers, Tabs

## Modal/slideover for `:new` / `:edit` + interactive actions

```ruby
class PostDefinition < ResourceDefinition
  modal :slideover               # default — slide-in panel from the right
  # modal :centered              # centered dialog
  # modal :centered, size: :lg   # centered, wider container
  # modal false                  # full standalone page
end
```

Drives both framework `:new` / `:edit` and every interactive action on the definition. `size:` accepts `:sm`, `:md` (default), `:lg`, `:xl`, `:auto` (hugs content), or `:full`. Per-action `modal:` / `size:` overrides win. See [[plutonium-resource]] › Action Options.

## Tabs on the show page

Show pages with `permitted_associations` (see [[plutonium-behavior]]) render a tablist: **Details** tab first, then one tab per association. The active tab is reflected in the URL hash (`#products`, `#refund-requests`) so the page deep-links and the active state survives reload / back navigation. Tab rows scroll horizontally on narrow viewports — they don't wrap.

If the policy permits **no fields**, the empty Details tab is dropped and the first association tab leads instead.

---

# Part 6 — Layout (Chrome) & Eject

## Shell

```ruby
Plutonium.configure do |config|
  config.shell = :modern    # default — topbar + icon rail
  # config.shell = :plain   # topbar, no icon rail (whole app rail-less)
  # config.shell = :classic # legacy header + sidebar (only when upgrading)
end
```

`:plain` keeps the Topbar but drops the icon rail. **Shell resolves global → engine → controller**, each overriding the one above (`nil` falls through); read it with `controller.shell`:

```ruby
config.shell = :plain                        # 1. global default
# 2. per-engine — inside the engine's config.after_initialize (with scope_to_entity)
class CustomerPortal::Engine
  config.after_initialize { shell :plain }
end
class DashboardController; shell :modern; end # 3. per-controller (overrides engine/global)
```

`shell` takes a symbol so the class body works too, but the generated engine already has a `config.after_initialize` block (home of `scope_to_entity`) — keep it there for consistency.

Alongside `shell`, the controller-only `rail` DSL flips just the rail (inherited `class_attribute`, so a portal opts in/out once in its concern) — `rail false` / `rail true`; `rail nil` (default) inherits the resolved shell, `rail?` reads the resolved value:

```ruby
module CustomerPortal::Concerns::Controller
  extend ActiveSupport::Concern
  included { rail false }  # entire portal rail-less
end
```

Stable CSS hooks for rail-less overrides: `pu-topbar` (Topbar nav), `pu-sticky-footer` (form footer), and the `html.pu-no-rail` root class. A built-in rule cancels the desktop rail inset on the first two under `html.pu-no-rail`.

## Eject the chrome for per-portal customization

```bash
rails generate pu:eject:shell --dest=admin_portal
rails generate pu:eject:layout
```

These copy `_resource_header.html.erb`, `_resource_sidebar.html.erb`, and `layouts/resource.html.erb` into the portal so you can edit them directly.

## Navigation menu items

The sidebar/icon-rail menu is built with `Phlexi::Menu::Builder` in `_resource_sidebar.html.erb`. Extra options on `item` are spread onto the rendered `<a>`, so an item can opt into `target` / `rel` / `data:` / `aria:`:

```ruby
m.item "Inbox", url: inbox_path, icon: Icon, target: "_blank", rel: "noopener", data: {turbo_frame: "_top"}
```

Applies to both shells (icon-rail leaf, parent flyout trigger, and flyout children; classic sidebar). Framework `class`/`data`/`aria` win on conflict — `class:` merges with the base classes, and on a parent trigger `data:`/`aria:` merge with the flyout wiring so options can't break the toggle. Phlexi's reserved `:active` key is never emitted as an attribute.

## Custom layout class (Phlex)

```ruby
module AdminPortal
  class ResourceLayout < Plutonium::UI::Layout::ResourceLayout
    private

    def body_attributes = {class: "antialiased bg-[var(--pu-body)]"}

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

| Hook | Position |
|---|---|
| `render_before_main` / `_after_main` | around the main content area |
| `render_before_content` / `_after_content` | inside main, around content |
| `render_flash` | flash messages |
| `render_head`, `render_title`, `render_metatags`, `render_assets` | head section |
| `render_body_scripts` | end-of-body scripts |
| `render_fonts` | font links |

---

# Part 7 — Assets, Tailwind, Stimulus

## Asset configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0
  config.assets.stylesheet = "application"
  config.assets.script     = "application"
  config.assets.logo       = "my_logo.png"
  config.assets.favicon    = "my_favicon.ico"
end
```

## Generator

```bash
rails generate pu:core:assets
```

This installs npm packages, creates `tailwind.config.js` extending Plutonium's config, imports Plutonium CSS, registers Stimulus controllers, and points the Plutonium config at your asset files.

## Tailwind config (generated)

```javascript
// tailwind.config.js
const { execSync } = require('child_process');
const plutoniumGemPath = execSync("bundle show plutonium").toString().trim();
const plutoniumTailwindConfig = require(`${plutoniumGemPath}/tailwind.options.js`);

module.exports = {
  darkMode: plutoniumTailwindConfig.darkMode,                       // selector
  plugins:  [].concat(plutoniumTailwindConfig.plugins),
  theme:    plutoniumTailwindConfig.merge(
              plutoniumTailwindConfig.theme,
              { /* your overrides */ },
            ),
  content: [
    `${__dirname}/app/**/*.{erb,haml,html,slim,rb}`,
    `${__dirname}/app/javascript/**/*.js`,
    `${__dirname}/packages/**/app/**/*.{erb,haml,html,slim,rb}`,
  ].concat(plutoniumTailwindConfig.content),
};
```

🚨 Always use `plutoniumTailwindConfig.merge(...)`. A plain spread drops Plutonium's defaults.

## Default color palette

| Color | Use |
|---|---|
| `primary` | Brand primary (turquoise default) |
| `secondary` | Brand secondary (navy default) |
| `success` | Success state (green) |
| `info` | Informational (blue) |
| `warning` | Warning (amber) |
| `danger` | Error (red) |
| `accent` | Highlight (coral pink) |

```javascript
theme: plutoniumTailwindConfig.merge(plutoniumTailwindConfig.theme, {
  extend: {
    colors: {
      primary: { 50: '#eff6ff', 500: '#3b82f6', 900: '#1e3a8a' },
    },
  },
})
```

## CSS imports

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "gem:plutonium/src/css/plutonium.css";

@import "tailwindcss";
@config '../../../tailwind.config.js';

/* your styles */
```

Plutonium CSS includes core utilities, EasyMDE, Slim Select, intl-tel-input, Flatpickr.

## Stimulus

```javascript
// app/javascript/controllers/index.js
import { application } from "./application"
import { registerControllers } from "@radioactive-labs/plutonium"

registerControllers(application)

// Your custom controllers...
import CustomController from "./custom_controller"
application.register("custom", CustomController)
```

Bundled controllers: `color-mode`, `form` (pre-submit), `nested-resource-form-fields`, `slim-select`, `flatpickr`, `easymde`, plus various internal UI controllers.

Custom controller — standard Stimulus:

```javascript
import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  connect() { /* ... */ }
}
```

## Typography

Default font: Lato. Override:

```ruby
class MyLayout < Plutonium::UI::Layout::ResourceLayout
  def render_fonts
    link(rel: "preconnect", href: "https://fonts.googleapis.com")
    link(href: "https://fonts.googleapis.com/css2?family=Inter&display=swap", rel: "stylesheet")
  end
end
```

```javascript
theme: { fontFamily: { body: ['Inter', 'sans-serif'], sans: ['Inter', 'sans-serif'] } }
```

## Dark mode

`selector` strategy — toggle by adding/removing `dark` on `<html>`. The `color-mode` Stimulus controller handles it; Plutonium ships a switcher.

---

# Part 8 — Design Tokens & `.pu-*` Component Classes

Plutonium uses CSS custom properties for surfaces, text, borders, forms, cards, shadows, radii, spacing, and transitions. Tokens auto-switch with dark mode. Source: `src/css/tokens.css`.

## Key tokens

| Token | Purpose |
|---|---|
| `--pu-body`, `--pu-surface`, `--pu-surface-alt`, `--pu-surface-raised`, `--pu-surface-overlay` | Backgrounds |
| `--pu-text`, `--pu-text-muted`, `--pu-text-subtle` | Text colors |
| `--pu-border`, `--pu-border-muted`, `--pu-border-strong` | Borders |
| `--pu-input-bg`, `--pu-input-border`, `--pu-input-focus-ring`, `--pu-input-placeholder` | Form inputs |
| `--pu-card-bg`, `--pu-card-border` | Cards |
| `--pu-shadow-sm/md/lg` | Shadows |
| `--pu-radius-sm/md/lg/xl/full` | Border radius |
| `--pu-space-xs/sm/md/lg/xl` | Spacing |
| `--pu-transition-fast/normal/slow` | Transitions |

🚨 Tokens are CSS variables — use `bg-[var(--pu-surface)]`, not `bg-pu-surface`.

## Customizing tokens

```css
:root {
  --pu-surface: #fafafa;
  --pu-border:  #d1d5db;
}

.dark {
  --pu-surface: #111827;
  --pu-border:  #374151;
}
```

## `.pu-*` component classes

Ready-to-use styled components in `src/css/components.css`. **Prefer these over hardcoded `gray-X/dark:gray-Y` pairs.**

### Buttons

```
.pu-btn                            (base)
.pu-btn-md / -sm / -xs             (size)
.pu-btn-primary / -secondary / -danger / -success / -warning / -info / -accent
.pu-btn-ghost / -outline
.pu-btn-soft-primary / -soft-danger / ...
```

```erb
<%= form.submit "Save", class: "pu-btn pu-btn-md pu-btn-primary" %>
```

### Inputs, cards, panels, tables, toolbars, empty states

```
.pu-input / -invalid / -valid          .pu-label / -required          .pu-hint / .pu-error          .pu-checkbox / .pu-toggle
.pu-badge / -neutral / -primary / -secondary / -success / -danger / -warning / -info / -accent
.pu-card / .pu-card-body
.pu-panel-header / -title / -description
.pu-table-wrapper / .pu-table / -header / -header-cell / -body-row / -body-row-selected / -body-cell / .pu-selection-cell
.pu-toolbar / -text / -actions
.pu-empty-state / -icon / -title / -description
```

### Ruby constants

```ruby
ComponentClasses::Button.classes(variant: :primary, size: :default, soft: false)
# => "pu-btn pu-btn-md pu-btn-primary"

ComponentClasses::Form::INPUT      # "pu-input"
ComponentClasses::Form::LABEL      # "pu-label"
ComponentClasses::Table::WRAPPER   # "pu-table-wrapper"
ComponentClasses::Card::BASE       # "pu-card"
```

## Migration from hardcoded classes

| Old | New |
|---|---|
| `text-gray-900 dark:text-white` | `text-[var(--pu-text)]` |
| `text-gray-500 dark:text-gray-400` | `text-[var(--pu-text-muted)]` |
| `bg-gray-50 dark:bg-gray-700` | `bg-[var(--pu-surface)]` |
| `border-gray-300 dark:border-gray-600` | `border-[var(--pu-border)]` |
| Long input class chain | `pu-input` |
| Long button class chain | `pu-btn pu-btn-md pu-btn-primary` |

## `tokens` and `classes` helpers

For conditional class composition in Phlex components:

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def initialize(active:) = @active = active

  def view_template
    div(class: tokens(
      "base-class",
      active?:   "bg-primary-500 text-white",
      inactive?: "bg-gray-200 text-gray-700"
    )) { "Content" }
  end

  private

  def active?   = @active
  def inactive? = !@active
end

# `classes` returns the class as a kwarg-friendly hash
div(**classes("p-4 rounded", active?: "ring-2"))
# => <div class="p-4 rounded ring-2">

# Then/else branches
tokens("base", condition?: {then: "if-true", else: "if-false"})
```

---

# Part 9 — Phlexi Component Themes

Themes are Ruby classes nested under a Form/Display/Table override. They merge into Plutonium's defaults — never replace wholesale, always `super.merge(...)`.

## Form theme

```ruby
class PostDefinition < ResourceDefinition
  class Form < Form
    class Theme < Plutonium::UI::Form::Theme
      def self.theme
        super.merge(
          base:            "bg-[var(--pu-card-bg)] shadow-md rounded-lg p-6",
          fields_wrapper:  "grid grid-cols-2 gap-6",
          actions_wrapper: "flex justify-end mt-6 space-x-2",
          label:           "block mb-2 text-base font-bold",
          input:           "pu-input",
          error:           "pu-error",
          button:          "pu-btn pu-btn-md pu-btn-primary"
        )
      end
    end
  end
end
```

### Form theme keys

`base`, `fields_wrapper`, `actions_wrapper`, `wrapper`, `inner_wrapper`, `label`, `invalid_label`, `valid_label`, `neutral_label`, `input`, `invalid_input`, `valid_input`, `neutral_input`, `hint`, `error`, `button`, `checkbox`, `select`.

## Display theme

```ruby
class Display < Display
  class Theme < Plutonium::UI::Display::Theme
    def self.theme
      super.merge(
        fields_wrapper: "grid grid-cols-3 gap-8",
        label:          "text-sm font-bold text-[var(--pu-text-muted)] mb-1",
        string:         "text-lg text-[var(--pu-text)]",
        markdown:       "prose dark:prose-invert max-w-none"
      )
    end
  end
end
```

### Display theme keys

`fields_wrapper`, `label`, `description`, `string`, `text`, `link`, `email`, `phone`, `markdown`, `json`, `boolean`, `badge`, `currency`, `color`.

## Table theme

```ruby
class Table < Table
  class Theme < Plutonium::UI::Table::Theme
    def self.theme
      super.merge(
        wrapper:      "pu-table-wrapper",
        base:         "pu-table",
        header:       "pu-table-header",
        header_cell:  "pu-table-header-cell",
        body_row:     "pu-table-body-row",
        body_cell:    "pu-table-body-cell"
      )
    end
  end
end
```

### Table theme keys

`wrapper`, `base`, `header`, `header_cell`, `body_row`, `body_cell`, `sort_icon`.

---

## Available context

Inside any page / form / display / Phlex component, the same set of helpers is available — model accessors, definition/policy methods, URL helpers, `current_user`. For the full list, see [[plutonium-behavior]] › Key methods (controllers expose the same surface; pages inherit it).

In Phlex components, Rails helpers are accessed via the `helpers` proxy:

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def view_template
    helpers.link_to(...)
    helpers.number_to_currency(...)
  end
end
```

---

## Portal-specific overrides

Each portal can override page classes independently. The portal definition inherits from the base definition, and its nested classes inherit from the base's nested classes:

```ruby
class AdminPortal::PostDefinition < ::PostDefinition
  class ShowPage < ShowPage      # inherits from ::PostDefinition::ShowPage
    def render_after_content
      super
      render AdminOnlySection.new(post: object)
    end
  end
end
```

---

## Gotchas

- **Don't override `view_template` in pages** when a render hook fits — you lose breadcrumbs / header / DynaFrame behavior.
- **Always register Stimulus controllers.** Without `registerControllers(application)` the entire UI's interactive layer is dead.
- **Use `plutoniumTailwindConfig.merge`** — plain object merge drops Plutonium's defaults.
- **Dark mode is `selector`, not `class`.** Toggle via `document.documentElement.classList.toggle('dark')`.
- **Tokens are CSS variables, not Tailwind keys** — `bg-[var(--pu-surface)]`, not `bg-pu-surface`.
- **`render_actions` is mandatory in custom `form_template`** — otherwise no submit button.
- **Dropdowns (`resource-drop-down`) teleport their menu to `<body>` while open.** popper's `fixed` strategy alone is still clipped by a transformed + `overflow:hidden` ancestor (e.g. grid cards, app shells), so the controller reparents the open menu to `<body>` and restores it on close. Don't rely on the menu being a DOM child of its trigger while open.

---

## Related skills

- [[plutonium-resource]] — field/input/display config (`as:`, `condition:`, blocks); modal options for actions.
- [[plutonium-behavior]] — controller presentation hooks (`present_parent?`), available helpers (`resource_record!`, `current_scoped_entity`).
- [[plutonium-app]] — `pu:eject:layout`, `pu:eject:shell`, portal package overrides.
- [[plutonium-tenancy]] — `permitted_associations` drives the show-page tablist.
