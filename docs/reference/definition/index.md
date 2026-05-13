# Definition Reference

Complete reference for resource definitions.

## Overview

Definitions control how resources render - which fields appear in forms, how tables display data, what actions are available.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Field configuration
  field :title
  field :body, as: :markdown

  # Form-specific
  input :title, placeholder: "Enter title"

  # Display-specific
  display :body, as: :markdown

  # Table columns
  column :title

  # Custom actions
  action :publish, interaction: PublishPost

  # Search
  search do |scope, query|
    scope.where("title ILIKE ?", "%#{query}%")
  end

  # Sorting
  sort :title
  sort :created_at
  default_sort :created_at, :desc
end
```

## Definition Files

### Location

```
app/definitions/post_definition.rb
packages/blogging/app/definitions/blogging/post_definition.rb
```

### Naming Convention

| Model | Definition |
|-------|------------|
| `Post` | `PostDefinition` |
| `Blogging::Post` | `Blogging::PostDefinition` |

### Portal-Specific

Override for specific portals:

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
module AdminPortal
  class PostDefinition < ::PostDefinition
    # Admin-specific customizations
    field :internal_notes
  end
end
```

## Auto-Detection

By default, Plutonium auto-detects fields from the model:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Empty definition = all fields auto-detected
end
```

Override selectively:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Override just body field
  field :body, as: :markdown

  # Other fields still auto-detected
end
```

## Core Methods

### Field Declaration

| Method | Purpose |
|--------|---------|
| `field` | Universal type/options for forms, displays, tables |
| `input` | Form-specific configuration |
| `display` | Show page configuration |
| `column` | Table configuration |

### Query Configuration

| Method | Purpose |
|--------|---------|
| `search` | Full-text search block |
| `filter` | Sidebar filter inputs |
| `scope` | Quick filter buttons |
| `sort` / `sorts` | Sortable columns |
| `default_sort` | Default sort order |

### Actions

| Method | Purpose |
|--------|---------|
| `action` | Define custom actions |
| `nested_input` | Nested forms for associations |

## Page Configuration

Configure page titles and descriptions:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  index_page_title "All Posts"
  index_page_description "Manage your blog posts"

  new_page_title "Create Post"
  new_page_description "Add a new blog post"

  show_page_title { |record| record.title }
  show_page_description "View post details"

  edit_page_title { |record| "Edit: #{record.title}" }
  edit_page_description "Update post content"
end
```

## Breadcrumbs

Control breadcrumb display:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Disable breadcrumbs globally
  breadcrumbs false

  # Or per-page
  index_page_breadcrumbs true
  new_page_breadcrumbs true
  show_page_breadcrumbs true
  edit_page_breadcrumbs true
  interactive_action_page_breadcrumbs true
end
```

## Form Configuration

Control form behavior:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Controls "Save and add another" / "Update and continue editing" buttons
  # nil (default) = auto-detect (hidden for singular resources, shown for plural)
  # true = always show
  # false = always hide
  submit_and_continue false

  # How `:new` / `:edit` render. Default is :slideover.
  #   :slideover — slide-in panel from the right (default)
  #   :centered  — centered modal dialog
  #   false      — full standalone pages (no modal)
  modal :centered
end
```

Singular resources (e.g., `resource :profile` routes or `has_one` nested) auto-hide the secondary submit button since creating "another" doesn't make sense.

The `modal` setting only retargets the framework-provided `:new` / `:edit` actions. Custom interactive actions render in their own dialog whose chrome is set on the action via the per-action `modal:` option (`:centered` default, or `:slideover`) — see [Actions](./actions#action-options).

## Show Page Metadata Panel

The `metadata` DSL declares a list of fields that render in a right-side aside on the show page as label/value rows, leaving the main card focused on the record's substance.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  metadata :author, :state, :created_at, :updated_at
end
```

- **Opt-in.** Without a `metadata` call, the show page renders full-width with no aside.
- **Policy-aware.** Fields are intersected with the policy's permitted attributes. The panel auto-hides when nothing is permitted.
- **Deduplicated.** Fields listed in `metadata` are removed from the main card so values aren't shown twice.
- **Responsive.** Side-by-side at `lg+`, stacked single-column below.

Field formatting (label, `as:`, blocks) is shared with the main card — declare once via `field` / `display` and the metadata panel inherits it.

## Index Views (Table & Grid)

Resources can opt into a card-based **Grid** view alongside the default **Table** view. The user can switch between them via the toolbar; the choice is persisted per-resource via cookie.

```ruby
class UserDefinition < Plutonium::Resource::Definition
  grid_fields(
    image:     :avatar,     # ActiveStorage attachment, Shrine, or URL string
    header:    :name,       # falls back to record.to_label
    subheader: :email,
    body:      :bio,
    meta:      [:role, :status],   # rendered as small pills
    footer:    :last_seen_at       # falls back to :created_at
  )

  default_index_view :grid  # optional — initial view if no cookie
  grid_layout :media        # :compact (default) or :media
  grid_columns 3            # pin to 3 cols on lg+; default is 1/2/3/4 responsive
end
```

Declaring `grid_fields` auto-enables the `:grid` view alongside the default `:table`. Only call `index_views` explicitly to **disable** one (e.g. `index_views :grid` to drop the table view).

| Method | Purpose |
|--------|---------|
| `index_views :table, :grid` | Which views are available. Default `[:table]`. Usually unnecessary. |
| `default_index_view :grid` | Initial view when no cookie. Falls back to first declared view. |
| `grid_fields(...)` | Maps card slots to fields. **Implicitly enables `:grid`** if not already declared. |
| `grid_layout :media` | `:compact` (image left of content) or `:media` (full-width image on top). |
| `grid_columns 3` | Override responsive column count on `lg+`. Default is 1 / 2 / 3 / 4 at sm/md/lg/xl. |

Grid slots — `:image`, `:header`, `:subheader`, `:body`, `:meta`, `:footer` — are all optional. `:meta` accepts an array; the rest are single fields. Slots that point at fields not permitted by the user's policy collapse silently.

## Custom Page Classes

Override default page components:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Custom page classes
  class IndexPage < Plutonium::UI::Page::Index
    def render_header
      # Custom header
    end
  end

  class Form < Plutonium::UI::Form::Resource
    # Custom form behavior
  end

  class Table < Plutonium::UI::Table::Resource
    # Custom table behavior
  end

  class Display < Plutonium::UI::Display::Resource
    # Custom display behavior
  end
end
```

## Inheritance

Definitions inherit from each other:

```ruby
# Base definition
class PostDefinition < Plutonium::Resource::Definition
  field :title
  field :body
end

# Extended definition
class AdminPortal::PostDefinition < ::PostDefinition
  field :internal_notes
  field :moderation_status
end
```

## Customization Hooks

Override customization methods for dynamic configuration:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  def customize_fields
    field :dynamic_field if some_condition?
  end

  def customize_inputs
    input :special_input, as: :text
  end

  def customize_displays
    display :computed_value
  end

  def customize_columns
    column :extra_column
  end

  def customize_filters
    filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq
  end

  def customize_scopes
    scope :active
  end

  def customize_sorts
    sort :custom_field
  end

  def customize_actions
    action :dynamic_action, interaction: SomeInteraction
  end
end
```

## Sections

- [Fields](./fields) - Form and display field configuration
- [Actions](./actions) - Custom actions and buttons
- [Query](./query) - Search, filters, scopes, and sorting

## Related

- [Fields](./fields) - Field configuration
- [Actions](./actions) - Custom actions
- [Query](./query) - Search, filters, scopes
- [Views Reference](/reference/views/)
