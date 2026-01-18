# Resources

In Plutonium, a **resource** is a complete unit that represents a domain concept. Unlike plain Rails models, a Plutonium resource combines data, presentation, and authorization.

## What Makes a Resource?

A resource consists of four parts:

| Component | Purpose | Example |
|-----------|---------|---------|
| **Model** | Data structure and validation | `Post` |
| **Definition** | How it renders | `PostDefinition` |
| **Policy** | Who can do what | `PostPolicy` |
| **Controller** | HTTP handling | `PostsController` |

## Resource Models

Resource models inherit from `ResourceRecord`:

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_many :comments

  validates :title, presence: true
end
```

This base class adds:
- Automatic field introspection
- Association detection
- Integration with definitions and policies

## Creating Resources

### Using the Generator

The fastest way to create a resource:

```bash
rails generate pu:res:scaffold Post title:string body:text published:boolean
```

This generates:
- Model with attributes and validations
- Definition with default configuration
- Policy with standard permissions
- Migration

### Manual Creation

You can also create resources manually:

```ruby
# app/models/post.rb
class Post < ResourceRecord
  validates :title, presence: true
end

# app/definitions/post_definition.rb
class PostDefinition < Plutonium::Resource::Definition
end

# app/policies/post_policy.rb
class PostPolicy < Plutonium::Resource::Policy
end
```

## Resource vs Model

| Aspect | Plain Model | Resource |
|--------|-------------|----------|
| Inheritance | `ApplicationRecord` | `ResourceRecord` |
| Fields | Manual configuration | Auto-detected |
| Authorization | Separate concern | Integrated via Policy |
| UI | Manual forms/views | Auto-generated |
| CRUD | Write manually | Generated |

## Resource Discovery

Plutonium automatically discovers resources based on naming conventions:

```
Post           → PostDefinition, PostPolicy, PostsController
Blogging::Post → Blogging::PostDefinition, Blogging::PostPolicy
```

## Field Introspection

Resources automatically detect their fields from the database schema:

```ruby
# Given this schema:
create_table :posts do |t|
  t.string :title, null: false
  t.text :body
  t.boolean :published, default: false
  t.belongs_to :user
  t.timestamps
end

# Plutonium auto-detects:
# - title: string input, required
# - body: textarea
# - published: checkbox
# - user: association select
# - created_at, updated_at: datetime displays
```

## Resource Registration

Resources must be registered with a portal to be accessible:

```bash
rails generate pu:res:conn Post --portal admin
```

Or manually in routes:

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  resources :posts
end
```

## Nested Resources

Resources are automatically nested via `belongs_to` associations:

```ruby
class Comment < ResourceRecord
  belongs_to :post
end
```

When both resources are registered in a portal, Plutonium creates nested URLs like `/posts/:post_id/comments`.

## Resource Features

### Entity Scoping (Multi-tenancy)

Entity scoping is configured on the portal engine, not the model:

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

### Monetary Fields

```ruby
class Product < ResourceRecord
  # Store as cents, expose as decimal
  has_cents :price_cents
end
```

## Resource Lifecycle

```
1. User requests /posts/new
2. Controller builds new Post instance
3. Policy checks create? permission
4. Definition provides form fields
5. Form rendered to user

6. User submits form
7. Controller receives params
8. Policy filters permitted attributes
9. Model validates and saves
10. Controller redirects or re-renders
```

## Best Practices

### Keep Models Thin
Put business logic in Interactions, not models.

```ruby
# Good: Model handles data
class Post < ResourceRecord
  validates :title, presence: true
end

# Interaction handles logic
class PublishPost < Plutonium::Interaction::Base
  def execute
    resource.update!(published: true, published_at: Time.current)
    notify_subscribers
    succeed(resource)
  end
end
```

### Use Meaningful Scopes

```ruby
class Post < ResourceRecord
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_author, ->(user) { where(user: user) }
end
```

### Validate at the Right Level

- **Model**: Data integrity (presence, format, uniqueness)
- **Interaction**: Business rules (can only publish once)
- **Policy**: Authorization (user must own post)

## Related Topics

- [Architecture](./architecture) - How layers work together
- [Model Reference](/reference/model/) - Complete model documentation
- [Definition Reference](/reference/definition/) - Field configuration
