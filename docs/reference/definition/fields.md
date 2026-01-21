# Definition Fields

Complete reference for field configuration in definitions.

## Core Methods

| Method | Applies To | Use When |
|--------|-----------|----------|
| `field` | Forms + Show + Table | Universal type override |
| `input` | Forms only | Form-specific options |
| `display` | Show page only | Display-specific options |
| `column` | Table only | Table-specific options |

## Basic Usage

```ruby
class PostDefinition < Plutonium::Resource::Definition
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
| **Rich Text** | `:markdown` (uses EasyMDE editor) |
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

### Common Options

```ruby
input :title,
  label: "Custom Label",           # Custom label text
  hint: "Help text for forms",     # Form help text
  placeholder: "Enter value",      # Input placeholder
  description: "For displays"      # Display description
```

### HTML Attributes

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
class PostDefinition < Plutonium::Resource::Definition
  # Show based on object state
  display :published_at, condition: -> { object.published? }
  display :rejection_reason, condition: -> { object.rejected? }

  # Show based on environment
  field :debug_info, condition: -> { Rails.env.development? }
end
```

**Note:** Use `condition` for UI state logic. Use **policies** for authorization.

## Dynamic Forms (pre_submit)

Use `pre_submit: true` to create forms that dynamically show/hide fields based on other field values.

### Basic Pattern

```ruby
class PostDefinition < Plutonium::Resource::Definition
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

## Column Alignment

```ruby
column :title, align: :start    # Left (default)
column :status, align: :center  # Center
column :amount, align: :end     # Right
```

## Value Formatting

Use `formatter` for simple value transformations without a full block:

```ruby
# Truncate long text
column :description, formatter: ->(value) { value&.truncate(30) }

# Format numbers
column :price, formatter: ->(value) { "$%.2f" % value if value }

# Transform values
column :status, formatter: ->(value) { value&.humanize&.upcase }
```

The `formatter` option:
- Receives the field value as its argument
- Returns the transformed value for display
- Works with `column` and `display` declarations
- Is simpler than block syntax when you only need to transform the value

**formatter vs block:** Use `formatter` when you only need the value. Use a block when you need access to the full record:

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
class PostDefinition < Plutonium::Resource::Definition
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

## File Uploads

```ruby
input :avatar, as: :file
input :avatar, as: :uppy

input :documents, as: :file, multiple: true
input :documents, as: :uppy,
  allowed_file_types: ['.pdf', '.doc'],
  max_file_size: 5.megabytes
```

## Common Patterns

### Rich Text Content

```ruby
field :content, as: :markdown     # Form: EasyMDE editor
display :content, as: :markdown   # Show: rendered markdown
```

### Money Fields

```ruby
input :price, as: :decimal, class: "font-mono"
display :price, class: "font-bold text-green-600"
```

### Status Badges

```ruby
display :status do |field|
  color = case field.value
  when 'active' then 'green'
  when 'pending' then 'yellow'
  else 'gray'
  end
  span(class: "badge badge-#{color}") { field.value.humanize }
end
```

### Hidden Fields

```ruby
field :author_id, as: :hidden
input :tenant_id, as: :hidden
```

## Context in Blocks

Inside `condition` procs and `input` blocks:
- `object` - The record being edited/displayed
- `current_user` - The authenticated user
- `current_parent` - Parent record for nested resources
- `request`, `params` - Request information
- All helper methods

## Related

- [Definition Reference](./index)
- [Actions Reference](./actions)
- [Query Reference](./query)
- [Forms Reference](/reference/views/forms)
