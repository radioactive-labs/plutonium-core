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

The three core methods for defining a resource's attributes are `field`, `display`, and `input`. **All model attributes are automatically detected** - you only need to declare them when you want to override defaults or add custom options.

::: code-group
```ruby [field]
# Field declarations are OPTIONAL - all attributes are auto-detected
# You only need to declare fields when overriding auto-detected behavior
class PostDefinition < Plutonium::Resource::Definition
  # These are all auto-detected from your Post model:
  # - :title (string column)
  # - :content (text column)
  # - :published_at (datetime column)
  # - :published (boolean column)
  # - :author (belongs_to association)
  # - :tags (has_many association)
  # - :featured_image (has_one_attached)

  # Only declare fields when you want to override:
  field :content, as: :rich_text    # Override text -> rich_text
  field :author_id, as: :hidden     # Override integer -> hidden
  field :internal_notes, as: :text  # Add custom field options
end
```
```ruby [display]
# Display declarations are also OPTIONAL for auto-detected fields
# Only declare when you want custom display behavior
class PostDefinition < Plutonium::Resource::Definition
  # All model attributes auto-detected and displayed appropriately

  # Only override when you need custom display:
  display :content, as: :markdown      # Override text -> markdown
  display :published_at, as: :date     # Override datetime -> date only
  display :view_count, class: "font-bold"  # Add custom styling

  # Custom display with block for complex rendering
  display :status do |field|
    field.phlexi_render_tag(with: ->(value, attrs) {
      StatusBadgeComponent.new(value: value, **attrs)
    })
  end
end
```
```ruby [input]
# Input declarations are also OPTIONAL for auto-detected fields
# Only declare when you need custom input behavior
class PostDefinition < Plutonium::Resource::Definition
  # All editable attributes auto-detected with appropriate inputs

  # Only override when you need custom input behavior:
  input :content, as: :rich_text               # Override text -> rich_text
  input :title, placeholder: "Enter title"    # Add placeholder
  input :category, as: :select, collection: %w[Tech Business]  # Add options
  input :published_at, as: :date               # Override datetime -> date only
end
```
:::

## Field Type Auto-Detection

**Plutonium automatically detects ALL model attributes** and creates appropriate field, display, and input configurations. The system inspects your ActiveRecord model to discover:

- **Database columns** (string, text, integer, boolean, datetime, etc.)
- **Associations** (belongs_to, has_many, has_one, etc.)
- **Active Storage attachments** (has_one_attached, has_many_attached)
- **Enum attributes**
- **Virtual attributes** (with proper accessor methods)

::: details Complete Auto-Detection Logic
```ruby
# Database columns are automatically detected:
# CREATE TABLE posts (
#   id bigint PRIMARY KEY,
#   title varchar(255),        # → field :title, as: :string
#   content text,              # → field :content, as: :text
#   published_at timestamp,    # → field :published_at, as: :datetime
#   published boolean,         # → field :published, as: :boolean
#   view_count integer,        # → field :view_count, as: :number
#   rating decimal(3,2),       # → field :rating, as: :decimal
#   created_at timestamp,      # → field :created_at, as: :datetime
#   updated_at timestamp       # → field :updated_at, as: :datetime
# );

# Associations are automatically detected:
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'  # → field :author, as: :association
  has_many :comments                       # → field :comments, as: :association
  has_many :tags, through: :post_tags     # → field :tags, as: :association
end

# Active Storage attachments are automatically detected:
class Post < ApplicationRecord
  has_one_attached :featured_image         # → field :featured_image, as: :attachment
  has_many_attached :documents             # → field :documents, as: :attachment
end

# Enums are automatically detected:
class Post < ApplicationRecord
  enum status: { draft: 0, published: 1, archived: 2 }  # → field :status, as: :select
end
```
:::

## When to Declare Fields

You only need to explicitly declare fields, displays, or inputs in these scenarios:

### 1. **Override Auto-Detected Type**
```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Change text column to rich text editor
  input :content, as: :rich_text

  # Change datetime to date-only picker
  input :published_at, as: :date

  # Change text display to markdown rendering
  display :content, as: :markdown
end
```

### 2. **Add Custom Options**
```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Add placeholder text
  input :title, placeholder: "Enter an engaging title"

  # Add custom CSS classes
  display :title, class: "text-2xl font-bold"

  # Add wrapper styling
  display :content, wrapper: {class: "prose max-w-none"}
end
```

### 3. **Configure Select Options**
```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Provide options for select inputs
  input :category, as: :select, collection: %w[Tech Business Lifestyle]
  input :author, as: :select, collection: -> { User.active.pluck(:name, :id) }
end
```

### 4. **Add Conditional Logic**
```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Conditional logic is for showing/hiding fields based on the application's
  # state or other field values. It is not for authorization. Use policies
  # to control access to data.

  # Conditional fields based on the object's state
  display :published_at, condition: -> { object.published? }
  display :reason_for_rejection, condition: -> { object.rejected? }
  column :published_at, condition: -> { object.published? }

  # Use `pre_submit` to create dynamic forms where inputs appear based on other inputs.
  input :send_notifications, as: :boolean, pre_submit: true
  input :notification_channel, as: :select, collection: %w[Email SMS],
        condition: -> { object.send_notifications? }

  # Show debug fields only in development
  field :debug_info, as: :string, condition: -> { Rails.env.development? }
end
```

::: danger Authorization with Policies
While the rendering context may provide access to `current_user`, it is strongly recommended to use **policies** for authorization logic (i.e., controlling who can see what data). The `condition` option is intended for cosmetic or state-based logic, such as hiding a field based on another field's value or the record's status. JSON requests for example are not affected by this.
:::

::: tip Condition Context & Dynamic Forms
`condition` procs are evaluated in their respective rendering contexts and have access to contextual data.

**For `input` fields** (form rendering context):
- `object` - The record being edited
- `current_parent` - Parent record for nested resources
- `request` and `params` - Request information
- All helper methods available in the form context

**For `display` fields** (display rendering context):
- `object` - The record being displayed
- `current_parent` - Parent record for nested resources
- All helper methods available in the display context

**For `column` fields** (table rendering context):
- `current_parent` - Parent record for nested resources
- All helper methods available in the table context

To create forms that dynamically show/hide inputs based on other form values, pair a `condition` option with `pre_submit: true` on the "trigger" input. This will cause the form to re-render whenever that input's value changes, re-evaluating any conditions that depend on it.
:::

### 5. **Create Custom Display Blocks**
```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Use a component class - gets instantiated with (value, **attrs)
  display :status do |field|
    field.phlexi_render_tag(with: StatusBadgeComponent)
  end

  # Use a proc/lambda for dynamic component creation
  display :metrics do |field|
    field.phlexi_render_tag(with: ->(value, attrs) {
      MetricsChartComponent.new(data: value, **attrs)
    })
  end

  # Pass additional attributes to the component
  display :user_avatar do |field|
    field.phlexi_render_tag(
      with: AvatarComponent,
      size: :large,
      class: "rounded-full"
    )
  end

  # Complex conditional rendering
  display :content do |field|
    field.phlexi_render_tag(with: ->(value, attrs) {
      if value.present?
        MarkdownComponent.new(content: value, **attrs)
      else
        EmptyStateComponent.new(message: "No content available", **attrs)
      end
    })
  end
end
```

::: tip phlexi_render_tag Usage
The `phlexi_render_tag` method allows you to use custom Phlex components for field rendering:

**Component Class**: Pass a component class that will be instantiated with `(value, **attributes)`
```ruby
field.phlexi_render_tag(with: MyComponent)
# Equivalent to: MyComponent.new(value, **attributes)
```

**Proc/Lambda**: Pass a callable that receives `(value, attributes)` and returns a component instance
```ruby
field.phlexi_render_tag(with: ->(value, attrs) {
  MyComponent.new(data: value, **attrs)
})
```

**Additional Attributes**: Any extra options are passed to the component
```ruby
field.phlexi_render_tag(with: MyComponent, size: :large, theme: :dark)
# Component receives: MyComponent.new(value, size: :large, theme: :dark)
```
:::

## Minimal Definition Example

Here's what a typical definition looks like when leveraging auto-detection:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # No field declarations needed! All attributes auto-detected.
  # Post model columns, associations, and attachments are automatically available.

  # Only customize what you need to override:
  input :content, as: :rich_text
  display :content, as: :markdown

  # Add search and filtering:
  search do |scope, query|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{query}%", "%#{query}%")
  end

  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq

  # Add custom actions:
  action :publish, interaction: PublishPostInteraction
end
```

This approach means you can create a fully functional admin interface with just a few lines of configuration, while still having the flexibility to customize anything you need.

## Search, Filters, and Scopes

Configure how users can query the resource index.

::: code-group
```ruby [Search]
# Defines the global search logic for the resource.
class PostDefinition < Plutonium::Resource::Definition
  search do |scope, query|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{query}%", "%#{query}%")
  end
end
```
```ruby [Filters]
# Currently, only Text filter is implemented
class PostDefinition < Plutonium::Resource::Definition
  filter :title, with: Plutonium::Query::Filters::Text, predicate: :contains
  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq
  filter :category, with: Plutonium::Query::Filters::Text, predicate: :eq

  # Available predicates: :eq, :not_eq, :contains, :not_contains,
  # :starts_with, :ends_with, :matches, :not_matches
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
  # All model attributes are auto-detected!
  # No field declarations needed unless overriding

  # Only customize what you need:
  input :content, as: :rich_text    # Override text -> rich_text
  display :content, as: :markdown   # Override text -> markdown

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

### Field Type Philosophy
- **Let auto-detection work**: Don't declare fields unless you need to override
- **Override when needed**: Use declarations to change text to rich_text, datetime to date, etc.
- **Use conditions sparingly**: Prefer policy-based visibility over conditional fields

### Separation of Concerns
- **Definitions**: Configure HOW fields are rendered and processed
- **Policies**: Control WHAT fields are visible and editable
- **Interactions**: Handle business logic and operations

### Minimal Configuration Approach
```ruby
# Preferred: Let auto-detection work, only override what you need
class PostDefinition < Plutonium::Resource::Definition
  # All fields auto-detected from Post model

  # Only declare overrides:
  input :content, as: :rich_text
  display :content, as: :markdown

  search { |scope, search| scope.where("title ILIKE ?", "%#{search}%") }
end

# Avoid: Over-declaring fields that would be auto-detected anyway
class PostDefinition < Plutonium::Resource::Definition
  field :title, as: :string      # Unnecessary - auto-detected
  field :content, as: :text      # Unnecessary - auto-detected
  field :author, as: :association # Unnecessary - auto-detected

  # This creates extra maintenance burden
end
```

The Definition module provides a clean, declarative way to configure resource behavior while maintaining clear separation between configuration (definitions), authorization (policies), and business logic (interactions).

## Related Modules

- **[Resource](./resource.md)** - Resource controllers and CRUD operations
- **[UI](./ui.md)** - User interface components
- **[Query](./query.md)** - Query objects and filtering
- **[Action](./action.md)** - Custom actions and operations
- **[Interaction](./interaction.md)** - Business logic encapsulation

## Available Field Types

### Input Types (Form Components)
- **Text**: `:string`, `:text`, `:email`, `:url`, `:tel`, `:password`
- **Rich Text**: `:rich_text`, `:markdown` (uses EasyMDE)
- **Numeric**: `:number`, `:integer`, `:decimal`, `:range`
- **Boolean**: `:boolean`
- **Date/Time**: `:date`, `:time`, `:datetime` (uses Flatpickr)
- **Selection**: `:select`, `:slim_select`, `:radio_buttons`, `:check_boxes`
- **Files**: `:file`, `:uppy`, `:attachment` (uses Uppy)
- **Associations**: `:association`, `:secure_association`, `:belongs_to`, `:has_many`, `:has_one`
- **Special**: `:hidden`, `:color`, `:phone` (uses IntlTelInput)

### Display Types (Show/Index Components)
- **Text**: `:string`, `:text`, `:email`, `:url`, `:phone`
- **Rich Content**: `:markdown` (renders with Redcarpet)
- **Numeric**: `:number`, `:integer`, `:decimal`
- **Boolean**: `:boolean`
- **Date/Time**: `:date`, `:time`, `:datetime`
- **Associations**: `:association` (auto-links to show page)
- **Files**: `:attachment` (shows previews/downloads)
- **Custom**: `:phlexi_render` (for custom components)

## Available Configuration Options

### Field Options
```ruby
field :name, as: :string, class: "custom-class", wrapper: {class: "field-wrapper"}
```

### Input Options
```ruby
input :title,
  as: :string,
  placeholder: "Enter title",
  required: true,
  class: "custom-input",
  wrapper: {class: "input-wrapper"},
  data: {controller: "custom"},
  condition: -> { current_user.admin? }
```

### Display Options
```ruby
display :content,
  as: :markdown,
  class: "prose",
  wrapper: {class: "content-wrapper"},
  condition: -> { current_user.can_see_content? }
```

### Collection Options (for selects)
```ruby
input :category, as: :select, collection: %w[Tech Business Lifestyle]
input :author, as: :select, collection: -> { User.active.pluck(:name, :id) }

# Collection procs are executed in the form rendering context
# and have access to current_user and other helpers:
input :team_members, as: :select, collection: -> {
  current_user.organization.users.active.pluck(:name, :id)
}

# You can also access the form object being edited:
input :related_posts, as: :select, collection: -> {
  Post.where.not(id: object.id).published.pluck(:title, :id) if object.persisted?
}
```

::: tip Collection Context
Collection procs are evaluated in the form rendering context, which means they have access to:
- `current_user` - The authenticated user
- `current_parent` - Parent record for nested resources
- `object` - The record being edited (in edit forms)
- `request` and `params` - Request information
- All helper methods available in the form context

This is the same context as `condition` procs, allowing for dynamic, user-specific collections.
:::

### File Upload Options
```ruby
input :avatar, as: :file, multiple: false
input :documents, as: :file, multiple: true,
  allowed_file_types: ['.pdf', '.doc', '.docx'],
  max_file_size: 5.megabytes
```

## Dynamic Configuration & Policies

::: danger IMPORTANT
Definitions are instantiated outside the controller context, which means **`current_user` and other controller methods are NOT available** within the definition file itself. However, `condition` and `collection` procs ARE evaluated in the rendering context where `current_user` and the record (`object`) are available.
:::

The `condition` option configures **if an input is rendered**. It does not control if a field's *value* is accessible. For that, you must use policies.

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
