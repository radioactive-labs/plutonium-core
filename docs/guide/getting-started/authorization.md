# Authorization and Access Control

Plutonium provides a robust authorization system built on top of [Action Policy](https://actionpolicy.evilmartians.io/), offering fine-grained access control, resource scoping, and entity-based authorization.

## Overview

Authorization in Plutonium operates at multiple levels:
- Resource-level policies
- Action-based permissions
- Entity-based scoping
- Attribute-level access control

## Basic Policy Definition

Every resource in Plutonium requires a policy. Here's a basic example:

```ruby
class BlogPolicy < ResourcePolicy
  # Core CRUD Permissions

  def create?
    # Allow only authenticated users to create blogs
    user.present?
  end

  def read?
    # Allow anyone to read blogs
    true
  end

  def update?
    # Allow only the blog owner to update
    user.present? && record.user_id == user.id
  end

  def destroy?
    # Allow only the blog owner or admins to destroy
    user.present? && (record.user_id == user.id || user.admin?)
  end

  # Attribute Control

  def permitted_attributes_for_create
    [:title, :content, :category]
  end

  def permitted_attributes_for_read
    [:title, :content, :category, :created_at, :updated_at, :user_id]
  end

  def permitted_attributes_for_update
    [:title, :content, :category]
  end

  # Association Access

  def permitted_associations
    [:comments]
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end
end
```

::: tip
Note that `permitted_attributes_for_show` and `permitted_attributes_for_index` automatically inherits from `permitted_attributes_for_read` if not defined.
:::

## Entity-Based Authorization

Plutonium supports multi-tenancy through entity-based authorization, allowing you to scope resources based on organizational boundaries.

### Setting Up Entity Scoping

```ruby
# In your engine.rb
module AdminPortal
  class Engine < ::Rails::Engine
    include Plutonium::Portal::Engine

    # Scope all resources to an organization using URL-based scoping
    scope_to_entity Organization, strategy: :path

    # Or use current a controller method
    scope_to_entity Organization, strategy: :current_organization
  end
end
```

::: info
When using `:path` strategy, Plutonium automatically handles routing for you
:::

### Implementing Entity Association

There are two ways to associate resources with entities:

::: code-group
```ruby [ActiveRecord Association]
class Blog < ApplicationRecord
  include Plutonium::Resource::Record

  belongs_to :organization

  # Plutonium will automatically use the organization association
end
```

```ruby [Custom Relationship]
class Blog < ApplicationRecord
  include Plutonium::Resource::Record

  belongs_to :user
  # Organization is accessed through user

  # Define how to scope by organization
  scope :associated_with_organization, ->(organization) do
    joins(:user).where(users: { organization_id: organization.id })
  end
end
```
:::

## Authorization Contexts

By default, Plutonium policies have two context objects:

```ruby
class ResourcePolicy < ActionPolicy::Base
  # Current user (required)
  authorize :user, allow_nil: false

  # Current scope/tenant (optional)
  authorize :scope, allow_nil: true

  # All resources are automatically scoped
  relation_scope do |relation|
    if scope.present?
      relation.associated_with(scope)
    else
      relation
    end
  end
end
```

### Adding Custom Contexts

You can add additional authorization contexts:

::: code-group
```ruby [Policy]
class BlogPolicy < ResourcePolicy
  authorize :ability, allow_nil: true

  def promote?
    user.admin? && ability&.can?(:promote, record)
  end
end
```

```ruby [Controller]
class BlogsController < ResourceController
  authorize :ability, through: :current_ability

  private

  def current_ability
    @current_ability ||= Ability.new(current_user)
  end
end
```
:::

## Attribute-Level Access Control

Control access to specific attributes based on user roles or context:

```ruby
class BlogPolicy < ResourcePolicy
  def permitted_attributes_for_create
    # Start with basic attributes
    attrs = [:title, :content]

    # Add role-specific attributes
    if user.editor?
      attrs += [:featured, :category]
    end

    # Add organization-specific attributes
    if user.admin_in?(scope)
      attrs += [:internal_notes]
    end

    attrs
  end

  # Show action inherits from read by default
  def permitted_attributes_for_read
    attrs = [:title, :content, :created_at]

    # Owners and admins can see sensitive data
    if owner? || user.admin?
      attrs += [:internal_notes]
    end

    attrs
  end
end
```

## Security Best Practices

### 1. Never Skip Authorization

Plutonium controllers automatically verify authorization:

```ruby
class BlogsController < ResourceController
  def show
    # This will raise an error if you forget to authorize
    # authorize! resource_record
    render :show
  end
end
```

## Related Resources

- [Action Policy Documentation](https://actionpolicy.evilmartians.io/)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
