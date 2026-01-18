# Model Reference

Complete reference for Plutonium resource models.

## Base Class

All resource models inherit from `ResourceRecord`:

```ruby
class Post < ResourceRecord
  # Your model code
end
```

In packages, models inherit from the package's ResourceRecord:

```ruby
module Blogging
  class Post < Blogging::ResourceRecord
    # Your model code
  end
end
```

`ResourceRecord` is an abstract class that inherits from `ApplicationRecord` and is created by the Plutonium installer.

## Standard ActiveRecord Features

All standard ActiveRecord features work:

```ruby
class Post < ResourceRecord
  # Associations
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_one :featured_image
  has_many :tags, through: :post_tags

  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validates :slug, uniqueness: true
  validates :status, inclusion: { in: %w[draft published] }

  # Scopes
  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_author, ->(user) { where(user: user) }

  # Callbacks
  before_save :generate_slug
  after_create :notify_subscribers

  # Methods
  def publish!
    update!(status: 'published', published_at: Time.current)
  end
end
```

## Nested Resources

Nesting is automatic via `belongs_to` associations:

```ruby
class Comment < ResourceRecord
  belongs_to :post
end
```

When both `Post` and `Comment` are registered in a portal, Plutonium automatically creates nested routes (`/posts/:post_id/comments`). The `associated_with` scope is automatically available for querying.

See the [Nested Resources Guide](/guides/nested-resources) for details.

## Entity Scoping (Multi-tenancy)

Entity scoping is configured on the **portal engine**, not the model:

```ruby
# packages/customer_portal/lib/engine.rb
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization
    end
  end
end
```

See the [Multi-tenancy Guide](/guides/multi-tenancy) for details.

## Plutonium Features

See [Model Features](./features) for:
- `has_cents` - Store monetary values as integers, expose as decimals
- `to_label` - Human-readable record labels
- `path_parameter` / `dynamic_path_parameter` - Custom URL parameters
- Secure association SGIDs - Auto-generated SGID accessors for associations
- `associated_with` - Scope for nested resource queries
- Field introspection methods

## Field Introspection

Plutonium introspects models to detect:

### Column Types

| Database Type | Detected As |
|--------------|-------------|
| `string` | `:string` |
| `text` | `:text` |
| `integer` | `:integer` |
| `bigint` | `:integer` |
| `float` | `:float` |
| `decimal` | `:decimal` |
| `boolean` | `:boolean` |
| `date` | `:date` |
| `datetime` | `:datetime` |
| `time` | `:time` |
| `json`/`jsonb` | `:json` |

### Constraints

```ruby
# NULL constraint detected
t.string :title, null: false  # Required field
```

### Associations

```ruby
belongs_to :user      # Detected as association field
has_many :comments    # Available for association panels
```

### Validations

```ruby
validates :title, presence: true    # Required
validates :email, format: { ... }   # Format hint
validates :role, inclusion: { in: [...] }  # Select options
```

## Model Organization

### Feature Package Models

```ruby
# packages/blogging/app/models/blogging/post.rb
module Blogging
  class Post < ResourceRecord
    # Namespaced model
  end
end
```

### Table Naming

Namespaced models use prefixed tables:

```ruby
module Blogging
  class Post < ResourceRecord
    # Table: blogging_posts
  end
end
```

Override if needed:

```ruby
self.table_name = "posts"
```

## Best Practices

### Keep Models Thin

Put complex logic in Interactions:

```ruby
# Model: simple validations and associations
class Post < ResourceRecord
  validates :title, presence: true
end

# Interaction: complex logic
class PublishPost < ResourceInteraction
  def execute
    resource.update!(published: true)
    notify_subscribers
    update_search_index
    succeed(resource)
  end
end
```

### Use Meaningful Scopes

```ruby
# Good: intention-revealing names
scope :visible_to, ->(user) { where(user: user).or(where(published: true)) }

# Avoid: generic names
scope :filtered, -> { where(status: 'active') }
```

### Validate at the Right Level

- **Model**: Data integrity (presence, format, uniqueness)
- **Interaction**: Business rules (can only publish once)
- **Policy**: Authorization (user must own the record)

## Related

- [Model Features](./features)
- [Resources Concept](/concepts/resources)
- [Definition Reference](/reference/definition/)
