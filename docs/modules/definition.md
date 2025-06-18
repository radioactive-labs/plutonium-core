---
title: Definition Module
---

# Definition Module

The Definition module provides a powerful DSL for declaratively configuring how resources are displayed, edited, filtered, and interacted with. It serves as the central configuration point for resource behavior in Plutonium applications.

::: tip
The Definition module is located in `lib/plutonium/definition/`. Resource definitions are typically placed in `app/definitions/`.
:::

## Overview

- **Field Configuration**: Define how fields are displayed and edited.
- **Display Customization**: Configure field presentation and rendering.
- **Input Management**: Control form inputs and validation.
- **Filter & Search**: Set up filtering and search capabilities.
- **Action Definitions**: Define custom actions and operations.
- **Conditional Logic**: Dynamic configuration based on context.

## Core DSL Methods

### Field, Display, and Input

The three core methods for defining a resource's attributes are `field`, `display`, and `input`.

::: code-group
```ruby [field]
# Defines a basic property of the resource.
# Use `as:` to specify the type.
class PostDefinition < Plutonium::Resource::Definition
  field :title, as: :string
  field :content, as: :text
  field :published_at, as: :datetime
  field :author_id, as: :hidden # Hidden but still processed
end
```
```ruby [display]
# Customizes HOW a field is rendered on show/index pages.
class PostDefinition < Plutonium::Resource::Definition
  display :title, as: :string
  display :content, as: :markdown
  display :author, as: :association

  # With custom rendering block
  display :status do |f|
    f.badge_tag(color: f.value == 'published' ? :green : :gray)
  end
end
```
```ruby [input]
# Configures form inputs for new/edit pages.
class PostDefinition < Plutonium::Resource::Definition
  input :title, as: :string, placeholder: "Enter post title"
  input :content, as: :rich_text
  input :category, as: :select, collection: %w[Tech Business]
end
```
:::

::: details Available Field Types
You can use a wide range of types for inputs and displays.
```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Text fields
  input :title, as: :string
  input :content, as: :text, rows: 10
  input :body, as: :rich_text # or :markdown

  # Numeric fields
  input :view_count, as: :number
  input :rating, as: :number, min: 1, max: 5

  # Boolean fields
  input :published, as: :boolean

  # Date/time fields
  input :published_at, as: :datetime
  input :created_at, as: :date
  input :reminder_time, as: :time

  # Selection fields
  input :category, as: :select, collection: %w[Tech Business]
  input :author, as: :select, collection: -> { User.pluck(:name, :id) }

  # File uploads
  input :avatar, as: :file
  input :documents, as: :file, multiple: true

  # Associations
  input :author, as: :association
  input :tags, as: :association, multiple: true
end
```
:::

## Dynamic Configuration & Policies

::: danger IMPORTANT
Definitions are instantiated outside the controller context, which means **`current_user` and other controller methods are NOT available** within the definition file. Use policies for user-based logic.
:::

The `display` and `input` methods **only configure how a field is rendered**, not *whether* it is visible. Field visibility is controlled by policies.

::: code-group
```ruby [Static Definition]
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # This configuration is static.
  # The :admin_notes field is always defined here.
  def customize_fields
    field :admin_notes, as: :text
  end

  def customize_displays
    display :admin_notes, as: :text
  end

  def customize_inputs
    input :admin_notes, as: :text
  end
end
```
```ruby [Dynamic Policy]
# app/policies/post_policy.rb
class PostPolicy < Plutonium::Resource::Policy
  # The policy determines if the user can SEE the field.
  def permitted_attributes_for_show
    if user.admin?
      [:title, :content, :admin_notes] # Admin sees admin_notes
    else
      [:title, :content]               # Regular users do not
    end
  end
end
```
:::

## Search, Filters, and Scopes

Configure how users can query the resource index.

::: code-group
```ruby [Search]
# Defines the global search logic for the resource.
class PostDefinition < Plutonium::Resource::Definition
  search do |scope, query|
    scope.where("title ILIKE ?", "%#{query}%")
  end
end
```
```ruby [Filters]
# Defines individual, type-aware filters.
class PostDefinition < Plutonium::Resource::Definition
  filter :published, with: Plutonium::Query::Filters::BooleanFilter
  filter :category, with: Plutonium::Query::Filters::SelectFilter,
         choices: %w[Tech Business Lifestyle]
  filter :created_at, with: Plutonium::Query::Filters::DateRangeFilter
end
```
```ruby [Scopes]
# Defines named scopes that appear as buttons.
class PostDefinition < Plutonium::Resource::Definition
  scope :published
  scope :featured
  scope :recent, -> { where('created_at > ?', 1.week.ago) }
end
```
:::

## Actions

Define custom operations that can be performed on a resource.

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Each `action` call defines ONE action.
  action :publish, interaction: PublishPostInteraction
  action :archive, interaction: ArchivePostInteraction, color: :warning

  # Use an icon from Phlex::TablerIcons
  action :feature, interaction: FeaturePostInteraction,
         icon: Phlex::TablerIcons::Star

  # Add a confirmation dialog
  action :delete_permanently, interaction: DeletePostInteraction,
         color: :danger, confirm: "Are you sure?"
end
```

## UI Customization

### Page Titles and Descriptions

```ruby
class PostDefinition < Plutonium::Resource::Definition
  index_page_title "All Posts"
  index_page_description "Manage your blog posts"

  show_page_title "Post Details"
  show_page_description "View post information"

  new_page_title "Create New Post"
  edit_page_title "Edit Post"
end
```

### Custom Page Classes

Override page classes for custom rendering:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  class IndexPage < Plutonium::UI::Page::Index
    def render_content
      # Custom index page rendering
      super
    end
  end

  class ShowPage < Plutonium::UI::Page::Show
    def render_content
      # Custom show page rendering
      super
    end
  end
end
```

### Custom Form Classes

Override form classes for custom form rendering:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  class Form < Plutonium::UI::Form::Resource
    def render_fields
      # Custom form field rendering
      super
    end
  end
end
```

## Policy Integration

**Field visibility is controlled by policies, not definitions:**

```ruby
# app/policies/post_policy.rb
class PostPolicy < Plutonium::Resource::Policy
  def permitted_attributes_for_show
    if user.admin?
      [:title, :content, :admin_notes]  # Admin sees admin_notes
    else
      [:title, :content]  # Regular users don't
    end
  end

  def permitted_attributes_for_create
    if user.admin?
      [:title, :content, :published, :featured, :admin_notes]
    else
      [:title, :content]
    end
  end

  def permitted_attributes_for_update
    attrs = permitted_attributes_for_create

    # Authors can edit their own posts
    if user == record.author
      attrs + [:draft_notes]
    else
      attrs
    end
  end

  def permitted_associations
    [:author, :tags, :comments]
  end
end
```

## Integration Points

### Resource Integration

Definitions are automatically discovered and used by resource controllers:

```ruby
# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
  # Each method call configures ONE field
  display :title, as: :string
  display :author, as: :association
  display :published_at, as: :datetime

  input :title, as: :string
  input :content, as: :rich_text
  input :published, as: :boolean

  search { |scope, search| scope.where("title ILIKE ?", "%#{search}%") }
end

# app/controllers/posts_controller.rb
class PostsController < ApplicationController
  include Plutonium::Resource::Controller
  # PostDefinition is automatically used
end
```

### Interaction Integration

Actions integrate with the Interaction system:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  action :publish, interaction: PublishPostInteraction
end

class PublishPostInteraction < Plutonium::Interaction::Base
  attribute :resource
  attribute :publish_date, :date

  def execute
    resource.update!(published: true, published_at: publish_date || Time.current)
    succeed(resource).with_redirect_response(resource_url_for(resource))
  end
end
```

## Best Practices

### Separation of Concerns
- **Definitions**: Configure HOW fields are rendered and processed
- **Policies**: Control WHAT fields are visible and editable
- **Interactions**: Handle business logic and operations

### Policy-First Approach
```ruby
# Define what's visible in policy
def permitted_attributes_for_show
  [:title, :content, :author]
end

# Then customize how it's displayed in definition
def customize_displays
  display :title, as: :string
  display :content, as: :markdown
  display :author, as: :association
end
```

The Definition module provides a clean, declarative way to configure resource behavior while maintaining clear separation between configuration (definitions), authorization (policies), and business logic (interactions).

## Related Modules

- **[Resource](./resource.md)** - Resource controllers and CRUD operations
- **[UI](./ui.md)** - User interface components
- **[Query](./query.md)** - Query objects and filtering
- **[Action](./action.md)** - Custom actions and operations
- **[Interaction](./interaction.md)** - Business logic encapsulation
