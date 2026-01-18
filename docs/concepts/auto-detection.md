# Auto-Detection

Plutonium automatically detects configuration from your models, reducing boilerplate code. You only write configuration when you need to override the defaults.

## How Auto-Detection Works

When Plutonium renders a resource, it examines:
1. Database columns (types, constraints)
2. Model validations
3. Model associations
4. Existing configuration

From this, it determines sensible defaults for forms, tables, and displays.

## Field Detection

### From Column Types

| Column Type | Default Input | Default Display |
|-------------|---------------|-----------------|
| `string` | Text input | Text |
| `text` | Textarea | Formatted text |
| `integer` | Number input | Number |
| `float`/`decimal` | Decimal input | Formatted number |
| `boolean` | Checkbox | Yes/No badge |
| `date` | Date picker | Formatted date |
| `datetime` | Datetime picker | Formatted datetime |
| `time` | Time picker | Formatted time |
| `json`/`jsonb` | JSON editor | JSON display |

### From Constraints

```ruby
# Schema
t.string :email, null: false

# Auto-detects: required field
field :email  # Marked as required in form
```

### From Validations

```ruby
# Model
validates :title, presence: true, length: { maximum: 100 }

# Auto-detects:
# - Required field
# - Max length constraint
```

## Association Detection

### belongs_to

```ruby
# Model
belongs_to :user

# Auto-detects:
# - Select input with user options
# - Link to user in display
# - Automatic eager loading in queries
```

### has_many

```ruby
# Model
has_many :comments

# Auto-detects:
# - Association panel on detail page
# - Count display in tables (optional)
# - Nested forms support (if configured)
```

### has_one

```ruby
# Model
has_one :profile

# Auto-detects:
# - Inline display on detail page
# - Nested form support
```

## Validation Detection

| Validation | Effect |
|------------|--------|
| `presence` | Field marked required |
| `length` | Min/max constraints |
| `numericality` | Number input with constraints |
| `inclusion` | Select input with options |
| `format` | Pattern attribute on input |

```ruby
# Model
validates :status, inclusion: { in: %w[draft published archived] }

# Auto-detects: Select with options
field :status  # Renders as select with draft/published/archived options
```

## Overriding Defaults

Auto-detection provides a starting point. Override when needed:

### Field Type Override

```ruby
# Auto-detected: text input
# Override: rich text editor
field :body, as: :rich_text
```

### Field Options

```ruby
# Auto-detected: select with model options
# Override: custom collection
field :user, collection: -> { User.active.pluck(:name, :id) }
```

### Hiding Fields

```ruby
# Exclude from forms
exclude_from_form :created_at, :updated_at

# Or per-field
field :user, as: :hidden
```

### Required Override

```ruby
# Model allows null, but form requires it
field :nickname, required: true
```

## Table Column Detection

By default, tables show a subset of fields. Plutonium prioritizes:
1. Non-association fields
2. Non-text fields (text is too long for tables)
3. Fields with meaningful data

### Override Columns

```ruby
# Explicitly set columns
column :title
column :published
column :user
column :created_at
```

## Search Detection

Plutonium can auto-detect searchable fields:
- String columns are searchable by default
- Text columns can be included

### Override Search

```ruby
# Custom search implementation
search do |scope, query|
  scope.where("title ILIKE ?", "%#{query}%")
end
```

## Filter Detection

For associations, Plutonium can auto-generate filters:

```ruby
# Auto-detected from belongs_to :user
filter :user  # Select filter with user options
```

### Override Filters

```ruby
filter :status, as: :select, collection: %w[draft published archived]
filter :created_at, as: :date_range
```

## When Auto-Detection Runs

Auto-detection happens at render time, not definition time. This means:

1. Changes to models are reflected immediately
2. New columns appear in forms automatically
3. Removed columns disappear from forms

## Caching

In production, auto-detection results are cached for performance. Clear the cache after schema changes:

```ruby
Rails.cache.clear
```

## Best Practices

### 1. Start with Defaults
Let auto-detection do its job. Only configure what you need to change.

### 2. Be Explicit When It Matters
For important forms, explicitly declare fields to prevent surprise changes:

```ruby
# Explicit field list
field :title
field :body
field :published

# vs relying on auto-detection
# (new columns would appear automatically)
```

### 3. Use Models as Documentation
Your model's validations and associations document the expected UI:

```ruby
class Post < ResourceRecord
  belongs_to :user                    # Select input
  validates :title, presence: true    # Required field
  validates :status, inclusion: {...} # Select options
end
```

### 4. Test After Schema Changes
After adding/removing columns, verify forms still work correctly.

## Debugging Auto-Detection

To see what Plutonium detected:

```ruby
definition = PostDefinition.new
puts definition.detected_fields.inspect
puts definition.detected_columns.inspect
```

## Related Topics

- [Fields Reference](/reference/definition/fields) - All field options
- [Model Reference](/reference/model/) - Model configuration
- [Resources](./resources) - Understanding resources
