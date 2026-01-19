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
