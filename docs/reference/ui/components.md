# Components

Plutonium ships a Phlex-based component kit. Use the built-in shorthand inside pages/forms/displays, or write your own custom Phlex components by inheriting `Plutonium::UI::Component::Base`.

## Built-in component kit

Inside any `Plutonium::UI::Component::Base` subclass (or any page/form/display class):

```ruby
PageHeader(title: "Dashboard", description: "...", actions: [...])
Panel(class: "mt-4") { p { "Content" } }
Block { TabList(items: tabs) }
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

These are shorthand for `render Plutonium::UI::PageHeader.new(...)` etc. — they work because every component class is exposed as a method on `Plutonium::UI::Component::Base`.

## Writing custom Phlex components

```ruby
# app/components/post_card_component.rb
class PostCardComponent < Plutonium::UI::Component::Base
  def initialize(post:)
    @post = post
  end

  def view_template
    div(class: "bg-[var(--pu-card-bg)] border border-[var(--pu-card-border)] rounded-[var(--pu-radius-lg)] p-4") do
      h3(class: "font-bold text-[var(--pu-text)]") { @post.title }
      p(class: "text-[var(--pu-text-muted)] mt-2") { @post.excerpt }

      div(class: "mt-4 flex justify-between items-center") do
        span(class: "text-sm text-[var(--pu-text-subtle)]") {
          @post.published_at&.strftime("%B %d, %Y")
        }
        a(href: resource_url_for(@post), class: "text-primary-600") { "Read more" }
      end
    end
  end
end
```

::: tip Always inherit `Plutonium::UI::Component::Base`
It gives you:
- The component kit (`PageHeader`, `Panel`, `Block`, …)
- Resource helpers (`resource_url_for`, `current_user`, `current_record!`, `current_definition`)
- A `helpers` proxy for Rails helpers (`helpers.link_to`, `helpers.number_to_currency`)
- Token / class helpers (`tokens`, `classes`)
:::

### Use in a definition

```ruby
class PostDefinition < ResourceDefinition
  display :card, as: PostCardComponent       # custom display component
  input   :color, as: ColorPickerComponent   # custom input component

  display :metrics do |field|
    MetricsChartComponent.new(data: field.value)
  end
end
```

### Use in a page / form / display

```ruby
class ShowPage < ShowPage
  def render_after_content
    render RelatedPostsComponent.new(post: object)
  end
end
```

## `DynaFrameContent` pattern

Enables frame-aware rendering — regular requests get the full page (header + content + footer); turbo-frame requests get only the content inside the frame.

```ruby
def view_template(&block)
  DynaFrameContent(page_content(block)) do |frame|
    render_header        # skipped for frame requests
    frame.render_content # always rendered
    render_footer        # skipped for frame requests
  end
end
```

All pages inherit this automatically. Modals and frame navigation work without special handling.

### When to call `DynaFrameContent` manually

Rarely. Use it when writing a custom non-resource page that needs the same frame-aware rendering as the built-in pages.

For typical custom pages, just inherit `Plutonium::UI::Page::Base` and override hooks like `render_content` — the DynaFrame wrapping happens in `view_template` automatically.

## Conditional class helpers

For class composition in Phlex components:

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def initialize(active:)
    @active = active
  end

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
```

`classes` returns the class as a kwarg-friendly hash:

```ruby
div(**classes("p-4 rounded", active?: "ring-2"))
# => <div class="p-4 rounded ring-2">
```

`tokens` supports then/else branches:

```ruby
tokens("base", condition?: {then: "if-true", else: "if-false"})
```

## Accessing Rails helpers

```ruby
class MyComponent < Plutonium::UI::Component::Base
  def view_template
    helpers.link_to(...)
    helpers.image_tag(...)
    helpers.number_to_currency(...)
  end
end
```

The `helpers` proxy gives you everything `ApplicationController#helpers` exposes — including any custom helpers in `app/helpers/`.

## Available context

Inside any custom component, the same set of helpers as pages/forms/displays — see [Pages › Available context](./pages#available-context).

## Related

- [Pages](./pages) — `render_*` hooks call your components
- [Forms](./forms) — using custom input components via `as: MyComponent`
- [Displays](./displays) — using custom display components
- [Assets](./assets) — design tokens (`var(--pu-*)`) and `.pu-*` component classes
