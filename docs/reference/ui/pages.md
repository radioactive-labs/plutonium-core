# Pages

Each definition has nested page classes for index / show / new / edit / interactive-action. Override the ones you need.

## Architecture

```
Definition
├── IndexPage              → renders Table
├── ShowPage               → renders Display
├── NewPage                → renders Form
├── EditPage               → renders Form
└── InteractiveActionPage  → renders Form
```

## Page classes

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

## Page titles, descriptions, breadcrumbs

```ruby
class PostDefinition < ResourceDefinition
  index_page_title       t("blog.posts.index.title")         # lazy: resolved per request, in its locale
  index_page_description t("blog.posts.index.description")
  show_page_title        "Article Details"                   # a literal also works (fixed, untranslated)
  new_page_title         t("blog.posts.new.title")

  breadcrumbs              true     # global default
  index_page_breadcrumbs   false    # per-page override
  show_page_breadcrumbs    true
  new_page_breadcrumbs     true
  edit_page_breadcrumbs    true
  interactive_action_page_breadcrumbs true
end
```

The class-level `t` in a definition returns a lazy proc; calling `I18n.t` directly in the class body would resolve once, at load time. A title that depends on the record belongs in a `page_title` override on the nested page class (see the hooks example below), not in a lambda here: the setter's proc is called with no record context.

## Page hooks (preferred over `view_template`)

Every page inherits these, use them instead of overriding `view_template` to preserve breadcrumbs, header, and DynaFrame behavior:

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
    "#{object.title}, #{object.author.name}"
  end

  def render_before_content
    div(class: "pu-alert pu-alert-info", role: "status") do
      div(class: "pu-alert-message") { t("blog.posts.show.comment_count", count: object.comments.count) }
    end
  end

  def render_after_content
    render RelatedPostsComponent.new(post: object)
  end

  def render_toolbar
    div(class: "flex gap-2") do
      button(class: "pu-btn pu-btn-md pu-btn-secondary") { "Preview" }
      button(class: "pu-btn pu-btn-md pu-btn-primary")   { "Publish" }
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

Mix, keep the default and add chrome around it:

```erb
<div class="announcement-banner">Special announcement</div>
<%= render current_definition.show_page_class.new %>
<div class="related"><%= render partial: "related" %></div>
```

## Detecting render context

| Helper | True when |
|---|---|
| `in_frame?` | Request targets a turbo-frame |
| `in_modal?` | Request renders inside a modal/slideover (primary or secondary) |
| `in_secondary_modal?` | Request renders inside the stacked secondary modal |

Use to pin action strips, omit nav chrome, or swap layouts.

### Stacked modals (secondary frame)

Association inputs include an inline `+` button. When the parent form is itself rendered in a modal, the `+` opens a **second stacked modal** in `Plutonium::REMOTE_MODAL_SECONDARY_FRAME` instead of replacing the primary modal. On successful create, the secondary closes and the primary frame reloads so the new record appears in the select, no developer wiring.

For custom flows, controllers can call `helpers.turbo_stream_close_frame(frame_id)` and `helpers.turbo_stream_reload_frame(frame_id)`.

See [Forms › Association inputs](./forms#association-inputs).

## Modals & slideovers

The framework's `:new` / `:edit` actions and any interactive action render inline inside a modal. Choose the chrome (and optional width) per-resource via the definition, interactive actions inherit the same default:

```ruby
class PostDefinition < ResourceDefinition
  modal :slideover               # default, slide-in panel from the right
  # modal :centered              # centered dialog
  # modal :centered, size: :lg   # centered, wider container
  # modal false                  # full standalone pages (no modal)
end
```

`size:` accepts `:sm`, `:md` (default), `:lg`, `:xl`, `:auto` (hugs content width), or `:full`. Per-action `modal:` / `size:` on an interactive action overrides the definition's default. See [Resource › Actions](/reference/resource/actions#action-options).

## Tabs on the show page

Show pages with `permitted_associations` (see [Behavior › Policy](/reference/behavior/policies#association-permissions)) render a tablist: **Details** tab first, then one tab per association. The active tab is reflected in the URL hash (`#products`, `#refund-requests`) so the page deep-links and the active state survives reload / back navigation. Tab rows scroll horizontally on narrow viewports, they don't wrap.

If the policy permits **no fields**, the empty Details tab is dropped and the first association tab leads instead.

## Portal-specific overrides

Each portal can override page classes independently. The portal definition inherits from the base definition, and its nested classes inherit from the base's nested classes:

```ruby
class AdminPortal::PostDefinition < ::PostDefinition
  class ShowPage < ShowPage     # inherits from ::PostDefinition::ShowPage
    def render_after_content
      super
      render AdminOnlySection.new(post: object)
    end
  end
end
```

## Available context

Inside any page / form / display / Phlex component, the same set of helpers is available (model accessors, definition/policy methods, URL helpers, `current_user`; for the full list, see [Behavior › Controllers › Key methods](/reference/behavior/controllers#key-methods)). Pages inherit the same surface.

In Phlex components, call Rails helpers that return a value through `view_context`, and include a phlex-rails adapter for helpers that return HTML:

```ruby
class MyComponent < Plutonium::UI::Component::Base
  include Phlex::Rails::Helpers::LinkTo

  def view_template
    link_to(...)
    span { view_context.number_to_currency(...) }
  end
end
```

See [Components › Accessing Rails helpers](./components#accessing-rails-helpers).

## Related

- [Forms](./forms): Form class, field builder, themes
- [Displays](./displays): show-page Display class
- [Tables](./tables): index-page Table class
- [Components](./components): built-in component kit, custom Phlex components, DynaFrame
- [Layouts](./layouts): overall shell, eject, ResourceLayout
- [Resource › Definition](/reference/resource/definition): page titles, breadcrumbs, modal mode, metadata panel
