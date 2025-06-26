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
    StatusBadgeComponent.new(value: field.value, class: field.dom.css_class)
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

### 5. Custom Field Rendering

Plutonium offers three main approaches for rendering fields in a definition. Choose the one that best fits your needs for clarity, flexibility, and control.

**Quick Reference:**
- **`as: :symbol`** - Use built-in components for input and display (e.g., `:rich_text`, `:date`, `:markdown`)
- **`as: ComponentClass`** - Use custom component classes for input and display (new feature)
- **Block syntax** - Use for conditional logic and custom builder method calls
- **`as: :phlexi_tag`** - Advanced inline rendering with maximum flexibility (display only)

#### 1. The `as:` Option (Recommended)

The `as:` option is the simplest and most common way to specify a rendering component for both `input` and `display` declarations. It's ideal for using standard built-in components or overriding auto-detected types.

**New Feature**: You can now pass a component class directly to the `as:` option for custom rendering in both input and display contexts.

**Use When:**
- Using standard or enhanced built-in components for input or display.
- You want clean, readable code with minimal boilerplate.
- Overriding an auto-detected type (e.g., `text` to `rich_text` for input, or `text` to `markdown` for display).
- Using custom component classes for rendering.

::: code-group
```ruby [Standard Input Fields]
# Simple and concise overrides
class PostDefinition < Plutonium::Resource::Definition
  input :content, as: :rich_text
  input :published_at, as: :date
  input :avatar, as: :uppy

  # With options
  input :email, as: :email, placeholder: "Enter email"
end
```
```ruby [Custom Component Classes]
# Using custom component classes
class PostDefinition < Plutonium::Resource::Definition
  # Pass component class to input
  input :color_picker, as: ColorPickerComponent
  input :custom_widget, as: MyCustomInputComponent

  # Pass component class to display
  display :status_badge, as: StatusBadgeComponent
  display :chart, as: ChartComponent
end
```
```ruby [Standard Display Fields]
# Simple and concise overrides
class PostDefinition < Plutonium::Resource::Definition
  display :content, as: :markdown
  display :author, as: :association
  display :documents, as: :attachment

  # With styling options
  display :status, as: :string, class: "badge badge-success"
end
```
:::

#### 2. The Block Syntax

The block syntax offers more control over rendering, allowing for custom components, complex layouts, and conditional logic. The block receives a `field` object that you can use to render custom output.

**Important for Input Blocks**: When using blocks with `input` declarations, you can only use existing form builder methods (like `f.date_tag`, `f.text_tag`, etc.). You cannot return arbitrary components because the form system requires inputs to be registered internally.

**Use When:**
- Integrating custom-built Phlex or ViewComponent components (for `display` only).
- Building complex layouts with multiple components or custom HTML (for `display` only).
- You need conditional logic to determine which component to render.
- You need to call specific form builder methods with custom logic (for `input`).

::: code-group
```ruby [Custom Display Components]
# Custom display component - can return any component
display :chart_data do |field|
  ChartComponent.new(data: field.value, type: :bar)
end
```
```ruby [Custom Input with Builder Methods]
# Custom input - can only use form builder methods
input :birth_date do |f|
  # Can use builder methods with custom logic
  case object.age_category
  when 'adult'
    f.date_tag(min: 18.years.ago.to_date)
  when 'minor'
    f.date_tag(max: 18.years.ago.to_date)
  else
    f.date_tag
  end
end
```
```ruby [Conditional Rendering]
# Conditional display based on value
display :metrics do |field|
  if field.value.present?
    MetricsChartComponent.new(data: field.value)
  else
    EmptyStateComponent.new(message: "No metrics available")
  end
end
```
:::

#### 3. `as: :phlexi_tag` (Advanced)

`phlexi_tag` provides maximum rendering flexibility for `display` declarations. It's a powerful tool for building reusable component libraries and handling highly dynamic or polymorphic data.

**Use When:**
- Building reusable component libraries that need to be highly configurable.
- Working with polymorphic data that requires specialized renderers.
- You need complex rendering logic but want to keep it inline in the definition.

::: code-group
```ruby [With a Component Class]
# Pass a component class for rendering.
# The component's #initialize will receive (value, **attrs).
display :status, as: :phlexi_tag, with: StatusBadgeComponent
```
```ruby [With an Inline Proc]
# Use a proc for complex inline logic.
# The proc receives (value, attrs).
display :priority, as: :phlexi_tag, with: ->(value, attrs) {
  case value
  when 'high'
    span(class: tokens("badge badge-danger", attrs[:class])) { "High" }
  when 'medium'
    span(class: tokens("badge badge-warning", attrs[:class])) { "Medium" }
  else
    span(class: tokens("badge badge-info", attrs[:class])) { "Low" }
  end
}
```
```ruby [Handling Polymorphic Content]
# Dynamically render different components based on content type.
display :rich_content, as: :phlexi_tag, with: ->(value, attrs) {
  # `value` is the rich_content object itself
  case value&.content_type
  when 'markdown'
    MarkdownComponent.new(content: value.body, **attrs)
  when 'image'
    # Must return a proc for inline HTML rendering with Phlex
    proc { img(src: value.url, alt: value.caption, **attrs) }
  else
    nil # Fallback to default rendering: <p>#{value}</p>
  end
}
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

Page titles and descriptions are rendered using `phlexi_render`, which means they can be **strings**, **procs**, or **component instances**:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Static strings
  index_page_title "All Posts"
  index_page_description "Manage your blog posts"

  # Dynamic procs (have access to context)
  show_page_title -> { h1 { "#{current_record!.title} - Post Details" } }
  show_page_description -> { h2 { "Created by #{current_record!.author.name} on #{current_record!.created_at.strftime('%B %d, %Y')}" } }

  # Component instances for complex rendering
  new_page_title -> { PageTitleComponent.new(text: "Create New Post", icon: :plus) }
  edit_page_title -> { PageTitleComponent.new(text: "Edit: #{current_record!.title}", icon: :edit) }

  # Conditional titles based on state
  index_page_title -> {
    case params[:status]
    when 'published' then "Published Posts"
    when 'draft' then "Draft Posts"
    else "All Posts"
    end
  }
end
```

::: tip phlexi_render Context
Title and description procs are evaluated in the page rendering context, giving you access to:
- `current_record!` - The current record (for show/edit pages)
- `params` - Request parameters
- `current_user` - The authenticated user
- All helper methods available in the view context
:::

### Custom Page Classes

Override page classes for complete control over page rendering:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  class IndexPage < Plutonium::UI::Page::Resource::Index
    def view_template(&block)
      # Custom page header
      div(class: "mb-8") do
        h1(class: "text-3xl font-bold") { "Content Management" }
        p(class: "text-gray-600") { "Manage your blog posts and articles" }

        # Custom stats dashboard
        div(class: "grid grid-cols-1 md:grid-cols-4 gap-4 mt-6") do
          render_stat_card("Total Posts", Post.count)
          render_stat_card("Published", Post.published.count)
          render_stat_card("Drafts", Post.draft.count)
          render_stat_card("This Month", Post.where(created_at: 1.month.ago..Time.current).count)
        end
      end

      # Standard table rendering
      super(&block)
    end

    private

    def render_stat_card(title, value)
      div(class: "bg-white p-4 rounded-lg shadow") do
        div(class: "text-sm text-gray-500") { title }
        div(class: "text-2xl font-bold") { value }
      end
    end
  end

  class ShowPage < Plutonium::UI::Page::Resource::Show
    def view_template(&block)
      div(class: "max-w-4xl mx-auto") do
        # Custom breadcrumbs
        nav(class: "mb-6") do
          ol(class: "flex space-x-2 text-sm") do
            li { link_to("Posts", posts_path, class: "text-blue-600") }
            li { span(class: "text-gray-500") { "/" } }
            li { span(class: "text-gray-900") { current_record.title.truncate(50) } }
          end
        end

        # Two-column layout
        div(class: "grid grid-cols-1 lg:grid-cols-3 gap-8") do
          # Main content
          div(class: "lg:col-span-2") do
            super(&block)
          end

          # Sidebar with metadata
          div(class: "lg:col-span-1") do
            render_metadata_sidebar
          end
        end
      end
    end

    private

    def render_metadata_sidebar
      div(class: "bg-gray-50 p-6 rounded-lg") do
        h3(class: "text-lg font-medium mb-4") { "Post Metadata" }

        dl(class: "space-y-3") do
          render_metadata_item("Status", current_record.status.humanize)
          render_metadata_item("Created", time_ago_in_words(current_record.created_at))
          render_metadata_item("Updated", time_ago_in_words(current_record.updated_at))
          render_metadata_item("Views", current_record.view_count)
        end
      end
    end

    def render_metadata_item(label, value)
      div do
        dt(class: "text-sm text-gray-500") { label }
        dd(class: "text-sm font-medium") { value }
      end
    end
  end

  class NewPage < Plutonium::UI::Page::Resource::New
    def page_title
      "Create New #{current_record.class.model_name.human}"
    end

    def page_description
      "Fill out the form below to create a new post. All fields marked with * are required."
    end
  end

  class EditPage < Plutonium::UI::Page::Resource::Edit
    def page_title
      "Edit: #{current_record.title}"
    end

    def page_description
      "Last updated #{time_ago_in_words(current_record.updated_at)} ago"
    end
  end
end
```

### Custom Form Classes

Override form classes for complete control over form rendering:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  class Form < Plutonium::UI::Form::Resource
    def form_template
      # Custom form layout
      div(class: "grid grid-cols-1 lg:grid-cols-3 gap-8") do
        # Main content area
        div(class: "lg:col-span-2") do
          render_main_fields
        end

        # Sidebar
        div(class: "lg:col-span-1") do
          render_sidebar_fields
        end
      end

      render_actions
    end

    private

    def render_main_fields
      # Group related fields
      fieldset(class: "space-y-6") do
        legend(class: "text-lg font-medium") { "Content" }

        render field(:title).input_tag(placeholder: "Enter a compelling title")
        render field(:content).easymde_tag
        render field(:excerpt).input_tag(as: :textarea, rows: 3)
      end
    end

    def render_sidebar_fields
      # Publishing controls
      fieldset(class: "space-y-4") do
        legend(class: "text-lg font-medium") { "Publishing" }

        render field(:status).input_tag(as: :select)
        render field(:published_at).flatpickr_tag
        render field(:featured).input_tag(as: :boolean)
      end

      # Categorization
      fieldset(class: "space-y-4 mt-8") do
        legend(class: "text-lg font-medium") { "Categorization" }

        render field(:category).belongs_to_tag
        render field(:tags).has_many_tag
      end
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

- **[Resource Record](./resource_record.md)** - Resource controllers and CRUD operations
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
