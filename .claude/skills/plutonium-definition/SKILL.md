---
name: plutonium-definition
description: Use when configuring resource definitions - field types, inputs, displays, columns, conditional rendering, nested inputs, or definition structure
---

# Plutonium Resource Definitions

**Definitions are generated automatically** - never create them manually:
- `rails g pu:res:scaffold` creates the base definition
- `rails g pu:res:conn` creates portal-specific definitions
- `rails g pu:field:input NAME` creates custom field input components
- `rails g pu:field:renderer NAME` creates custom field display components

Resource definitions configure **HOW** resources are rendered and interacted with. They are the central configuration point for UI behavior.

## Key Principle

**All model attributes are auto-detected** - you only declare when overriding defaults.

Plutonium automatically detects from your model:
- Database columns (string, text, integer, boolean, datetime, etc.)
- Associations (belongs_to, has_many, has_one)
- Active Storage attachments (has_one_attached, has_many_attached)
- Enums
- Virtual attributes (with accessor methods)

## File Location

- Main app: `app/definitions/model_name_definition.rb`
- Packages: `packages/pkg_name/app/definitions/pkg_name/model_name_definition.rb`

## Definition Structure

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # Fields, inputs, displays, columns
  field :content, as: :markdown
  input :title, hint: "Be descriptive"
  display :content, as: :markdown
  column :title, align: :center

  # Search, filters, scopes, sorting (see definition-query skill)
  search { |scope, q| scope.where("title ILIKE ?", "%#{q}%") }
  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq
  scope :published
  sort :created_at

  # Actions (see definition-actions skill)
  action :publish, interaction: PublishInteraction
end
```

## Definition Hierarchy

Definitions exist at multiple levels:

### Main App (created by generators)

```ruby
# app/definitions/resource_definition.rb (base - created during install)
class ResourceDefinition < Plutonium::Resource::Definition
  action :archive, interaction: ArchiveInteraction, color: :danger, position: 1000
end

# app/definitions/post_definition.rb (resource-specific - created by scaffold)
class PostDefinition < ResourceDefinition
  scope :published
  input :content, as: :markdown
end
```

### Portal-Specific Overrides

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  input :internal_notes, as: :text  # Only admins see this field
  scope :pending_review             # Admin-specific scope
end
```

## Separation of Concerns

| Layer | Purpose | Example |
|-------|---------|---------|
| **Definition** | HOW fields render | `input :content, as: :markdown` |
| **Policy** | WHAT is visible/editable | `permitted_attributes_for_read` |
| **Interaction** | Business logic | `resource.update!(state: :archived)` |

## Core Methods

| Method | Applies To | Use When |
|--------|-----------|----------|
| `field` | Forms + Show + Table | Universal type override |
| `input` | Forms only | Form-specific options |
| `display` | Show page only | Display-specific options |
| `column` | Table only | Table-specific options |

## Basic Usage

```ruby
class PostDefinition < ResourceDefinition
  # field - changes type everywhere
  field :content, as: :markdown

  # input - form-specific
  input :title,
    label: "Article Title",
    hint: "Enter a descriptive title",
    placeholder: "e.g. Getting Started"

  # display - show page specific
  display :content,
    as: :markdown,
    description: "Published content",
    wrapper: {class: "col-span-full"}

  # column - table specific
  column :title, label: "Article", align: :center
  column :view_count, align: :end
end
```

## Available Field Types

### Input Types (Forms)

| Category | Types |
|----------|-------|
| **Text** | `:string`, `:text`, `:email`, `:url`, `:tel`, `:password` |
| **Rich Text** | `:markdown` (EasyMDE editor) |
| **Numeric** | `:number`, `:integer`, `:decimal`, `:range` |
| **Boolean** | `:boolean` |
| **Date/Time** | `:date`, `:time`, `:datetime` |
| **Selection** | `:select`, `:slim_select`, `:radio_buttons`, `:check_boxes` |
| **Files** | `:file`, `:uppy`, `:attachment` |
| **Associations** | `:association`, `:secure_association`, `:belongs_to`, `:has_many`, `:has_one` |
| **Special** | `:hidden`, `:color`, `:phone` |

### Display Types (Show/Index)

`:string`, `:text`, `:email`, `:url`, `:phone`, `:markdown`, `:number`, `:integer`, `:decimal`, `:boolean`, `:date`, `:time`, `:datetime`, `:association`, `:attachment`

## Field Options

### Field-Level Options (wrapper)

```ruby
input :title,
  label: "Custom Label",           # Custom label text
  hint: "Help text for forms",     # Form help text
  placeholder: "Enter value",      # Input placeholder
  description: "For displays"      # Display description
```

### Tag-Level Options (HTML element)

```ruby
input :title,
  class: "custom-class",           # CSS class
  data: {controller: "custom"},    # Data attributes
  required: true,                  # HTML required
  readonly: true,                  # HTML readonly
  disabled: true                   # HTML disabled
```

### Wrapper Options

```ruby
display :content, wrapper: {class: "col-span-full"}
input :notes, wrapper: {class: "bg-gray-50"}
```

## Select/Choices

### Static Choices

```ruby
input :category, as: :select, choices: %w[Tech Business Lifestyle]
input :status, as: :select, choices: Post.statuses.keys
```

### Dynamic Choices (requires block)

```ruby
# Basic dynamic
input :author do |f|
  choices = User.active.pluck(:name, :id)
  f.select_tag choices: choices
end

# With context access
input :team_members do |f|
  choices = current_user.organization.users.pluck(:name, :id)
  f.select_tag choices: choices
end

# Based on object state
input :related_posts do |f|
  choices = if object.persisted?
    Post.where.not(id: object.id).published.pluck(:title, :id)
  else
    []
  end
  f.select_tag choices: choices
end
```

## Conditional Rendering

```ruby
class PostDefinition < ResourceDefinition
  # Show based on object state
  display :published_at, condition: -> { object.published? }
  display :rejection_reason, condition: -> { object.rejected? }

  # Show based on environment
  field :debug_info, condition: -> { Rails.env.development? }
end
```

**Note:** Use `condition` for UI state logic. Use **policies** for authorization.

## Dynamic Forms (pre_submit)

Use `pre_submit: true` to create forms that dynamically show/hide fields based on other field values. When a `pre_submit` field changes, the form re-renders server-side and conditions are re-evaluated.

### Basic Pattern

```ruby
class PostDefinition < ResourceDefinition
  # Trigger field - causes form to re-render on change
  input :send_notifications, pre_submit: true

  # Dependent field - only shown when condition is true
  input :notification_channel,
    as: :select,
    choices: %w[Email SMS],
    condition: -> { object.send_notifications? }
end
```

### How It Works

1. User changes a `pre_submit: true` field
2. Form submits via Turbo (no page reload)
3. Server re-renders the form with updated `object` state
4. Fields with `condition` procs are re-evaluated
5. Newly visible fields appear, hidden fields disappear

### Multiple Dependent Fields

```ruby
class QuestionDefinition < ResourceDefinition
  # Primary selector
  input :question_type, as: :select,
    choices: %w[text choice scale date boolean],
    pre_submit: true

  # Conditional fields based on question_type
  input :max_length,
    as: :integer,
    condition: -> { object.question_type == "text" }

  input :choices,
    as: :text,
    hint: "One choice per line",
    condition: -> { object.question_type == "choice" }

  input :min_value,
    as: :integer,
    condition: -> { object.question_type == "scale" }

  input :max_value,
    as: :integer,
    condition: -> { object.question_type == "scale" }
end
```

### Cascading Dependencies

```ruby
class PropertyDefinition < ResourceDefinition
  input :property_type, as: :select,
    choices: %w[residential commercial],
    pre_submit: true

  input :residential_type, as: :select,
    choices: %w[apartment house condo],
    condition: -> { object.property_type == "residential" },
    pre_submit: true

  input :commercial_type, as: :select,
    choices: %w[office retail warehouse],
    condition: -> { object.property_type == "commercial" },
    pre_submit: true

  input :apartment_floor,
    as: :integer,
    condition: -> { object.residential_type == "apartment" }
end
```

### Dynamic Choices with pre_submit

```ruby
class SurveyResponseDefinition < ResourceDefinition
  input :category, as: :select,
    choices: Category.pluck(:name, :id),
    pre_submit: true

  input :subcategory do |f|
    choices = if object.category.present?
      Category.find(object.category).subcategories.pluck(:name, :id)
    else
      []
    end
    f.select_tag choices: choices
  end
end
```

### Tips

- Only add `pre_submit: true` to fields that control visibility of other fields
- Keep dependencies simple - deeply nested conditions are hard to debug
- The form submits on change, so avoid `pre_submit` on frequently-changed fields

## Custom Rendering

### Block Syntax

**For Display (can return any component):**
```ruby
display :status do |field|
  StatusBadgeComponent.new(value: field.value, class: field.dom.css_class)
end

display :metrics do |field|
  if field.value.present?
    MetricsChartComponent.new(data: field.value)
  else
    EmptyStateComponent.new(message: "No metrics")
  end
end
```

**For Input (must use form builder methods):**
```ruby
input :birth_date do |f|
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

### phlexi_tag (Advanced Display)

```ruby
# With component class
display :status, as: :phlexi_tag, with: StatusBadgeComponent

# With inline proc
display :priority, as: :phlexi_tag, with: ->(value, attrs) {
  case value
  when 'high'
    span(class: "badge badge-danger") { "High" }
  when 'medium'
    span(class: "badge badge-warning") { "Medium" }
  else
    span(class: "badge badge-info") { "Low" }
  end
}
```

### Custom Component Class

```ruby
input :color_picker, as: ColorPickerComponent
display :chart, as: ChartComponent
```

## Column Options

### Alignment

```ruby
column :title, align: :start    # Left (default)
column :status, align: :center  # Center
column :amount, align: :end     # Right
```

### Value Formatting

```ruby
# Truncate long text
column :description, formatter: ->(value) { value&.truncate(30) }

# Format numbers
column :price, formatter: ->(value) { "$%.2f" % value if value }

# Transform values
column :status, formatter: ->(value) { value&.humanize&.upcase }
```

**formatter vs block:** Use `formatter` when you only need the value. Use a block when you need the full record:

```ruby
# formatter - receives just the value
column :name, formatter: ->(value) { value&.titleize }

# block - receives the full record
column :full_name do |record|
  "#{record.first_name} #{record.last_name}"
end
```

## Nested Inputs

Render inline forms for associated records. Requires `accepts_nested_attributes_for` on the model.

### Model Setup

```ruby
class Post < ResourceRecord
  has_many :comments
  has_one :metadata

  accepts_nested_attributes_for :comments, allow_destroy: true, limit: 10
  accepts_nested_attributes_for :metadata, update_only: true
end
```

### Basic Declaration

```ruby
class PostDefinition < ResourceDefinition
  # Block syntax
  nested_input :comments do |n|
    n.input :body, as: :text
    n.input :author_name
  end

  # Using another definition
  nested_input :metadata, using: PostMetadataDefinition, fields: %i[seo_title seo_description]
end
```

### Options

| Option | Description |
|--------|-------------|
| `limit` | Max records (auto-detected from model, default: 10) |
| `allow_destroy` | Show delete checkbox (auto-detected from model) |
| `update_only` | Hide "Add" button, only edit existing |
| `description` | Help text above the section |
| `condition` | Proc to show/hide section |
| `using` | Reference another Definition class |
| `fields` | Which fields to render from the definition |

```ruby
nested_input :amenities,
  allow_destroy: true,
  limit: 20,
  description: "Add property amenities" do |n|
    n.input :name
    n.input :icon, as: :select, choices: ICONS
  end
```

### Singular Associations

For `has_one` and `belongs_to`, limit is automatically 1:

```ruby
nested_input :profile do |n|  # has_one
  n.input :bio
  n.input :website
end
```

### Gotchas

- Model must have `accepts_nested_attributes_for`
- For custom class names, use `class_name:` in both model and `using:` in definition
- `update_only: true` hides the Add button
- Limit is enforced in UI (Add button hidden when reached)

## File Uploads

```ruby
input :avatar, as: :file
input :avatar, as: :uppy

input :documents, as: :file, multiple: true
input :documents, as: :uppy,
  allowed_file_types: ['.pdf', '.doc'],
  max_file_size: 5.megabytes
```

## Runtime Customization Hooks

Override these methods for dynamic behavior:

```ruby
class PostDefinition < ResourceDefinition
  def customize_fields
    field :debug_info if Rails.env.development?
  end

  def customize_inputs
    # Add/modify inputs at runtime
  end

  def customize_displays
    # Add/modify displays at runtime
  end

  def customize_filters
    # Add/modify filters at runtime
  end

  def customize_actions
    # Add/modify actions at runtime
  end
end
```

## Form Configuration

```ruby
class PostDefinition < ResourceDefinition
  # Controls "Save and add another" / "Update and continue editing" buttons
  # nil (default) = auto-detect (hidden for singular resources, shown for plural)
  # true = always show
  # false = always hide
  submit_and_continue false
end
```

## Page Customization

```ruby
class PostDefinition < ResourceDefinition
  # Titles (static or dynamic)
  index_page_title "All Posts"
  show_page_title -> { "#{current_record!.title} - Details" }

  # Breadcrumbs
  breadcrumbs true
  show_page_breadcrumbs false

  # Custom page classes (inherit from parent's nested class)
  class IndexPage < IndexPage
    def view_template(&block)
      div(class: "custom-header") { h1 { "Custom" } }
      super(&block)
    end
  end

  class Form < Form
    def form_template
      div(class: "grid grid-cols-2") do
        render field(:title).input_tag
        render field(:content).easymde_tag
      end
      render_actions
    end
  end
end
```

## Context in Blocks

Inside `condition` procs and `input` blocks:
- `object` - The record being edited/displayed
- `current_user` - The authenticated user
- `current_parent` - Parent record for nested resources
- `request`, `params` - Request information
- All helper methods

## When to Declare

```ruby
class PostDefinition < ResourceDefinition
  # 1. Override auto-detected type
  field :content, as: :markdown      # text -> rich_text
  input :published_at, as: :date      # datetime -> date only

  # 2. Add custom options
  input :title, hint: "Be descriptive", placeholder: "Enter title"

  # 3. Configure select choices
  input :category, as: :select, choices: %w[Tech Business]

  # 4. Add conditional logic
  display :published_at, condition: -> { object.published? }

  # 5. Custom rendering
  display :status do |field|
    StatusBadgeComponent.new(value: field.value)
  end
end
```

## Best Practices

1. **Let auto-detection work** - Don't declare unless overriding
2. **Use portal-specific definitions** - Override per-portal when needed
3. **Keep definitions focused** - Configuration only, no business logic
4. **Use policies for authorization** - Not `condition` procs
5. **Group related declarations** - Use comments to organize sections

## Related Skills

- `plutonium-definition-actions` - Actions and interactions
- `plutonium-definition-query` - Search, filters, scopes, sorting
- `plutonium-views` - Custom page, form, display, and table classes
- `plutonium-forms` - Custom form templates and field builders
