# Customizing the UI

Plutonium's UI is built on Phlex, Tailwind 4, and Stimulus. Almost everything you see — pages, forms, displays, tables, components, layouts, even the design tokens — is open for override. This guide is the map. Each section shows the smallest useful example for one kind of customization, then points to the reference for the full surface.

When you're not sure where to start, read this top to bottom. When you know what you need, jump to the right section and follow the link to reference.

## The override pattern

Customization in Plutonium is overrides via **nested classes inside the definition**, never replacement of the root class. The pattern looks the same everywhere:

```ruby
class PostDefinition < ResourceDefinition
  class ShowPage < ShowPage; end   # override show page
  class Form     < Form;     end   # override form
  class Table    < Table;    end   # override index table
  class Display  < Display;  end   # override show display
end
```

Each nested class inherits from Plutonium's defaults and lets you override only the methods you care about. Don't reimplement the whole layer — use the render hooks below.

→ See [Reference › UI › Pages](/reference/ui/pages) for the full hook list.

## Adding chrome to a page

Most page customization is "I want to add something before/after this section." Use the render hooks; don't override `view_template`.

```ruby
class PostDefinition < ResourceDefinition
  class ShowPage < ShowPage
    def render_before_content
      div(class: "pu-card pu-card-body") do
        plain "This post has #{object.comments.count} comments"
      end
    end
  end
end
```

Hooks exist around the header, breadcrumbs, page header, toolbar, content, and footer — pick the one closest to where you want the thing to appear.

→ See [Reference › UI › Pages](/reference/ui/pages) › Page hooks.

## Customizing a form layout

The default form renders every permitted field in a single grid. To group fields into sections or columns, override `form_template`:

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
    render_actions   # REQUIRED — without this, no submit button
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

→ See [Reference › UI › Forms](/reference/ui/forms) for `render_resource_field`, field tags (`flatpickr_tag`, `easymde_tag`, `uppy_tag`, etc.), and Phlexi themes.

## Customizing a display

The show page renders a `Display` for the record. Override `display_template` to add hero blocks, group fields, or interleave custom panels:

```ruby
class Display < Display
  def display_template
    div(class: "pu-card pu-card-body mb-4") do
      h1 { object.title }
      p(class: "text-[var(--pu-text-muted)]") { object.excerpt }
    end
    Block { fields_wrapper { render_fields } }
    render_associations if present_associations?
  end
end
```

→ See [Reference › UI › Displays](/reference/ui/displays).

## Replacing a table with a grid

By default the index page renders a `Table`. To use cards instead, override `view_template` on the nested `Table`:

```ruby
class Table < Table
  def view_template
    render_toolbar
    render_scopes_pills
    if collection.empty?
      render_empty_card
    else
      div(class: "grid grid-cols-3 gap-4") do
        collection.each { |post| render PostCardComponent.new(post:) }
      end
    end
    render_footer
  end
end
```

→ See [Reference › UI › Tables](/reference/ui/tables).

## Writing a custom Phlex component

When you need a piece of UI that's reused across pages, write a Phlex component. Inherit from `Plutonium::UI::Component::Base` and you get the component kit (`PageHeader`, `Panel`, `Block`), resource URL helpers, and a `helpers` proxy for Rails helpers.

```ruby
class PostCardComponent < Plutonium::UI::Component::Base
  def initialize(post:) = @post = post

  def view_template
    div(class: "pu-card pu-card-body") do
      h3(class: "font-bold text-[var(--pu-text)]") { @post.title }
      p(class: "text-[var(--pu-text-muted)] mt-2") { @post.excerpt }
      a(href: resource_url_for(@post), class: "pu-btn pu-btn-sm pu-btn-ghost") { "Read more" }
    end
  end
end
```

Use it directly in a page, or wire it as a field in the definition:

```ruby
display :card, as: PostCardComponent
```

→ See [Reference › UI › Components](/reference/ui/components).

## Phlexi themes (recolor without rewriting)

If all you want is to recolor or restyle the form/display/table, write a `Theme` class instead of overriding the template. Always `super.merge(...)` — never replace wholesale:

```ruby
class Form < Form
  class Theme < Plutonium::UI::Form::Theme
    def self.theme
      super.merge(
        base:           "bg-[var(--pu-card-bg)] shadow-md rounded-lg p-6",
        fields_wrapper: "grid grid-cols-2 gap-6",
        label:          "block mb-2 text-base font-bold",
      )
    end
  end
end
```

→ See [Reference › UI › Forms](/reference/ui/forms) › Theme keys, [Reference › UI › Displays](/reference/ui/displays) › Theme, [Reference › UI › Tables](/reference/ui/tables) › Theme.

## Modals and slideovers

By default `:new` and `:edit` render in a slideover panel. Switch to a centered modal or a full standalone page from the definition:

```ruby
class PostDefinition < ResourceDefinition
  modal :slideover    # default — slide-in from the right
  # modal :centered   # centered dialog
  # modal false       # full standalone page
end
```

→ See [Reference › Resource › Actions](/reference/resource/actions) for per-action `modal:` options on interactive actions.

## Layouts and the shell

The layout is the chrome around every resource page — topbar, sidebar, flash region, scripts. Two ways to customize it:

```bash
# Per-portal: eject the shell partials and edit them directly
rails generate pu:eject:shell --dest=admin_portal
# Or eject the whole layout
rails generate pu:eject:layout
```

For programmatic overrides, subclass `Plutonium::UI::Layout::ResourceLayout` and use its render hooks (`render_before_main`, `render_body_scripts`, etc.).

→ See [Reference › UI › Layouts](/reference/ui/layouts) and [Theming](/guides/theming) for design tokens.

## Tailwind, Stimulus, and assets

Plutonium ships with a Tailwind config, design tokens, and a set of Stimulus controllers. To plug into them in your app:

```bash
rails generate pu:core:assets
```

This installs the npm packages, creates a `tailwind.config.js` that extends Plutonium's defaults via `plutoniumTailwindConfig.merge`, imports Plutonium's CSS, and registers its Stimulus controllers. After that, you can:

- Extend the palette under `theme.extend.colors` (always inside `plutoniumTailwindConfig.merge` — a plain spread drops Plutonium's defaults).
- Use `.pu-btn`, `.pu-card`, `.pu-input`, `.pu-table`, etc. instead of hand-rolling Tailwind chains.
- Reference design tokens directly: `bg-[var(--pu-surface)]`, `text-[var(--pu-text-muted)]`, `border-[var(--pu-border)]`. These auto-switch with dark mode.
- Register your own Stimulus controllers alongside Plutonium's — `registerControllers(application)` is mandatory or the entire interactive layer is dead.

→ See [Reference › UI › Assets](/reference/ui/assets) for the full toolchain, the `.pu-*` class catalog, and design-token reference.

## ERB views (escape hatch)

When the Phlex page class is the wrong tool — you want to keep an existing ERB layout, you're integrating with a designer's HTML, or you just want to surround the generated page with custom markup — drop an ERB view at the controller path:

```
app/views/posts/show.html.erb
packages/admin_portal/app/views/admin_portal/posts/show.html.erb
```

The default page renders the Phlex page class in one line:

```erb
<%= render current_definition.show_page_class.new %>
```

Keep that line and wrap it to add chrome without giving up the generated page:

```erb
<div class="announcement-banner">Special announcement</div>
<%= render current_definition.show_page_class.new %>
<%= render partial: "related" %>
```

Or replace the line entirely for full control. ERB views always win over the Phlex page class when both exist for the same action — reach for this only when Phlex hooks + overrides genuinely can't do the job.

## When to reach for what

| You want to… | Use |
|---|---|
| Add a banner above the show page | Page hook (`render_before_content`) |
| Group form fields into sections | Custom `form_template` |
| Render the index as cards | Custom `Table#view_template` |
| Reuse a UI block across pages | Custom Phlex component |
| Recolor without changing structure | Phlexi `Theme` class |
| Swap the topbar or sidebar | `pu:eject:shell` or custom layout class |
| Change brand color or radius | Design tokens — see [Theming](/guides/theming) |
| Add a custom JS interaction | Stimulus controller registered alongside Plutonium's |

## Gotchas

- **Don't override `view_template` in pages** when a render hook fits — you lose breadcrumbs, header, and DynaFrame (turbo-frame) behavior.
- **`render_actions` is mandatory** when you write a custom `form_template` — otherwise the form has no submit button.
- **Always `registerControllers(application)`** in `app/javascript/controllers/index.js`. Without it, every Plutonium-shipped Stimulus controller is dead (color mode, slim-select, flatpickr, easymde, form pre-submit).
- **Use `plutoniumTailwindConfig.merge`** when extending the Tailwind theme. A plain object spread drops Plutonium's defaults.
- **Prefer `.pu-*` classes and `var(--pu-*)` tokens** over hardcoded `gray-X/dark:gray-Y` pairs — they switch with dark mode automatically.

## Related

- [Theming](/guides/theming) — design tokens, brand colors.
- [Reference › UI](/reference/ui/) — the full surface area for every override above.
