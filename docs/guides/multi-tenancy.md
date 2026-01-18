# Multi-tenancy

This guide covers isolating data by organization, account, or other entity.

## Overview

Multi-tenancy means each tenant (organization, company, account) sees only their own data. Plutonium supports this through:

- **Entity Scoping** - Automatic query filtering via portal configuration
- **Path or Custom Strategies** - Flexible entity resolution
- **Policy Integration** - Authorization automatically respects tenancy

## Setting Up Multi-tenancy

### 1. Create the Entity Model

```ruby
# app/models/organization.rb
class Organization < ApplicationRecord
  include Plutonium::Resource::Record

  has_many :users
  has_many :posts
end
```

### 2. Add Entity Reference to Resources

Resources must have an association path to the entity:

```ruby
# Direct association (preferred)
class Post < ResourceRecord
  belongs_to :organization
  belongs_to :user
end

# Through association
class Comment < ResourceRecord
  belongs_to :post
  has_one :organization, through: :post
end
```

### 3. Configure the Portal Engine

```ruby
# packages/customer_portal/lib/engine.rb
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      # Path strategy - entity ID in URL
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

Routes become: `/organizations/:organization_id/posts`

## Scoping Strategies

### Path Strategy (Default)

Entity ID is included in the URL path:

```ruby
config.after_initialize do
  scope_to_entity Organization, strategy: :path
end
```

The user must have access to the organization (via `associated_with` scope).

### Custom Strategy

Define a method that returns the current entity:

```ruby
# packages/customer_portal/lib/engine.rb
config.after_initialize do
  scope_to_entity Organization, strategy: :current_organization
end
```

```ruby
# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
module CustomerPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:user)

      private

      # Method name must match strategy
      def current_organization
        @current_organization ||= current_user.organization
      end
    end
  end
end
```

## How Entity Scoping Works

### Automatic Query Filtering

All resource queries are automatically scoped via `associated_with`:

```ruby
# In a scoped portal
Post.all  # Returns only current entity's posts
```

### Helper Methods

Inside controllers:

```ruby
current_scoped_entity  # The current Organization/Account/etc.
scoped_to_entity?      # true if scoping is active
scoped_entity_class    # Organization (the entity class)
```

### Model Requirements

Models must have an association path to the scoped entity. Plutonium automatically resolves:

1. **Direct belongs_to** - `Post belongs_to :organization`
2. **Through association** - `Comment has_one :organization, through: :post`
3. **Custom scope** - For complex cases, define a named scope:

```ruby
class AuditLog < ResourceRecord
  # When automatic resolution fails, define this scope
  scope :associated_with_organization, ->(org) {
    joins(:user).where(users: { organization_id: org.id })
  }
end
```

## User Membership Patterns

### Single Organization per User

```ruby
class User < ApplicationRecord
  belongs_to :organization
end

# Custom strategy
def current_organization
  current_user.organization
end
```

### Multiple Organizations per User

```ruby
class User < ApplicationRecord
  has_many :memberships
  has_many :organizations, through: :memberships
end

# Custom strategy with session storage
def current_organization
  @current_organization ||=
    current_user.organizations.find_by(id: session[:organization_id]) ||
    current_user.organizations.first
end
```

### Organization Switcher

```ruby
class OrganizationSwitchController < ApplicationController
  def update
    org = current_user.organizations.find(params[:id])
    session[:organization_id] = org.id
    redirect_back(fallback_location: root_path)
  end
end
```

## Policy Integration

Entity scoping is automatic. The base `Plutonium::Resource::Policy` includes:

```ruby
relation_scope do |relation|
  next relation unless entity_scope

  relation.associated_with(entity_scope)
end
```

The `entity_scope` context is automatically set to `current_scoped_entity`.

### Additional Filtering

Add role-based filtering on top of entity scoping:

```ruby
class PostPolicy < ResourcePolicy
  relation_scope do |relation|
    relation = super(relation)  # Apply entity scoping first

    if user.role == "viewer"
      relation.where(published: true)
    else
      relation
    end
  end
end
```

## Subdomain-Based Tenancy

Route to different organizations by subdomain:

### Routes

```ruby
# config/routes.rb
constraints subdomain: /[a-z]+/ do
  mount CustomerPortal::Engine, at: "/"
end
```

### Custom Strategy

```ruby
# Engine configuration
scope_to_entity Organization, strategy: :current_organization

# Controller concern
def current_organization
  @current_organization ||=
    Organization.find_by!(subdomain: request.subdomain)
end
```

## Cross-Tenant Operations

Sometimes admins need to see all data:

### Super Admin Portal (No Scoping)

```ruby
# packages/super_admin_portal/lib/engine.rb
module SuperAdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
    # No scope_to_entity = sees everything
  end
end
```

### Conditional Scoping

```ruby
# Custom strategy that returns nil for super admins
def current_organization
  return nil if current_user.super_admin?
  current_user.organization
end
```

When `current_scoped_entity` returns `nil`, scoping is bypassed.

## Data Isolation Patterns

### Shared Database, Scoped Queries (Recommended)

All tenants share tables, queries filter by entity association:

```ruby
scope_to_entity Organization, strategy: :path
```

Pros:
- Simple setup
- Easy migrations
- Efficient for many small tenants

Cons:
- Risk of data leakage if scoping fails
- Complex queries for cross-tenant reports

### Schema-Based Isolation

Each tenant has separate database schema. This requires additional setup beyond Plutonium's built-in scoping.

## Related

- [Authorization](./authorization)
- [Creating Packages](./creating-packages)
- [Authentication](./authentication)
