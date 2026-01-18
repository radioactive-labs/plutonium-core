# Policy Reference

Complete reference for authorization policies. Built on [ActionPolicy](https://actionpolicy.evilmartians.io/).

## Overview

Policies control authorization at three levels:
1. **Action Permissions** - Can user perform this action?
2. **Attribute Permissions** - Which fields can user access?
3. **Scope Permissions** - Which records can user see?

## Base Class

```ruby
class PostPolicy < Plutonium::Resource::Policy
  # Policy code
end
```

In packages, inherit from the package's ResourcePolicy:

```ruby
module AdminPortal
  class PostPolicy < ::PostPolicy
    # Portal-specific overrides
  end
end
```

## Authorization Context

Inside a policy, you have access to:

| Variable | Description |
|----------|-------------|
| `user` | Current authenticated user (required) |
| `record` | Resource being authorized |
| `entity_scope` | Current scoped entity (for multi-tenancy) |

```ruby
def update?
  user          # => Current user
  record        # => The Post instance
  entity_scope  # => Organization for multi-tenant portals
end
```

## Action Permissions

### Core Actions (Must Override)

These default to `false` - you must override them:

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def create?
    user.present?
  end

  def read?
    true
  end
end
```

### Derived Actions

These inherit from core actions by default:

| Method | Inherits From | Override When |
|--------|---------------|---------------|
| `update?` | `create?` | Different update rules |
| `destroy?` | `create?` | Different delete rules |
| `index?` | `read?` | Custom listing rules |
| `show?` | `read?` | Record-specific read rules |
| `new?` | `create?` | Rarely needed |
| `edit?` | `update?` | Rarely needed |
| `search?` | `index?` | Search-specific rules |

### Example with Ownership

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def create?
    user.present?
  end

  def read?
    true
  end

  def update?
    owner? || admin?
  end

  def destroy?
    owner? || admin?
  end

  private

  def owner?
    record.user_id == user.id
  end

  def admin?
    user.admin?
  end
end
```

### Custom Action Permissions

For custom actions defined in definitions:

```ruby
def publish?
  owner? && !record.published?
end

def archive?
  owner? || admin?
end

def bulk_delete?
  admin?
end
```

Actions are secure by default - undefined methods return `false`.

## Attribute Permissions

### Core Methods (Must Override for Production)

```ruby
# What users can see (index, show)
def permitted_attributes_for_read
  %i[title body author created_at]
end

# What users can set (create, update)
def permitted_attributes_for_create
  %i[title body category_id]
end
```

### Derived Methods

| Method | Inherits From |
|--------|---------------|
| `permitted_attributes_for_update` | `permitted_attributes_for_create` |
| `permitted_attributes_for_index` | `permitted_attributes_for_read` |
| `permitted_attributes_for_show` | `permitted_attributes_for_read` |
| `permitted_attributes_for_new` | `permitted_attributes_for_create` |
| `permitted_attributes_for_edit` | `permitted_attributes_for_update` |

### Conditional Attribute Access

```ruby
def permitted_attributes_for_create
  attrs = %i[title body]
  attrs << :featured if user.admin?
  attrs << :author_id if user.admin?
  attrs
end

def permitted_attributes_for_update
  case record.status
  when 'draft'
    %i[title body category_id]
  when 'published'
    %i[body]  # Can only edit body once published
  else
    []
  end
end
```

### Auto-Detection (Development Only)

In development, undefined attribute methods auto-detect from the model. This raises errors in production - always define explicitly:

```
🚨 Resource field auto-detection: PostPolicy#permitted_attributes_for_create
Auto-detected resource fields result in security holes and will fail outside of development.
```

## Association Permissions

Control which associations appear in panels and forms:

```ruby
def permitted_associations
  %i[comments tags author]
end
```

Returns an empty array by default.

## Collection Scoping

### relation_scope

Filter which records users can see using ActionPolicy's `relation_scope`:

```ruby
class PostPolicy < Plutonium::Resource::Policy
  relation_scope do |relation|
    if user.admin?
      relation
    else
      relation.where(published: true).or(
        relation.where(user_id: user.id)
      )
    end
  end
end
```

### With Entity Scoping

Call `super` to preserve automatic entity scoping for multi-tenancy:

```ruby
relation_scope do |relation|
  relation = super(relation)  # Applies associated_with(entity_scope)

  if user.admin?
    relation
  else
    relation.where(published: true)
  end
end
```

The default `relation_scope` automatically applies `relation.associated_with(entity_scope)` when an entity scope is present.

## Portal-Specific Policies

Override policies for specific portals:

```ruby
# packages/admin_portal/app/policies/admin_portal/post_policy.rb
module AdminPortal
  class PostPolicy < ::PostPolicy
    def destroy?
      true  # Admins can delete any post
    end

    def permitted_attributes_for_create
      %i[title body featured internal_notes]  # More fields
    end

    relation_scope do |relation|
      relation  # No restrictions for admins
    end
  end
end
```

## Custom Authorization Context

Add custom context using ActionPolicy's `authorize` directive:

```ruby
# In policy
class PostPolicy < Plutonium::Resource::Policy
  authorize :department, allow_nil: true

  def create?
    department&.allows_posting?
  end
end

# In controller
class PostsController < ResourceController
  authorize :department, through: :current_department

  private

  def current_department
    current_user.department
  end
end
```

## Authorization Errors

When authorization fails:

```ruby
# Raises ActionPolicy::Unauthorized
```

### Handling Errors

```ruby
# app/controllers/application_controller.rb
rescue_from ActionPolicy::Unauthorized do |exception|
  redirect_to root_path, alert: "Not authorized"
end
```

## Common Patterns

### Role-Based

```ruby
def update?
  case user.role
  when 'admin' then true
  when 'editor' then true
  when 'author' then owner?
  else false
  end
end
```

### Status-Based

```ruby
def update?
  return false if record.archived?
  owner? || admin?
end
```

### Time-Based

```ruby
def update?
  return false if record.created_at < 24.hours.ago
  owner?
end
```

### Hierarchical

```ruby
def read?
  return true if admin?
  return true if manager_of_department?
  return true if owner?
  record.public?
end
```

## Debugging

### Logging

```ruby
def update?
  result = owner? || admin?
  Rails.logger.debug { "PostPolicy#update? user=#{user.id} post=#{record.id}: #{result}" }
  result
end
```

### Console Testing

```ruby
user = User.find(1)
post = Post.find(1)

# Use ActionPolicy's testing helpers
policy = PostPolicy.new(post, user: user)
policy.update?
policy.permitted_attributes_for_update
```

## Best Practices

1. **Always override `create?` and `read?`** - They default to `false`
2. **Define attributes explicitly** - Auto-detection only works in development
3. **Call `super` in `relation_scope`** - Preserves entity scoping
4. **Use derived methods** - Let `update?` inherit from `create?` when appropriate
5. **Keep policies focused** - Authorization logic only, no business logic
6. **Test edge cases** - Archived records, nil associations, role combinations

## Related

- [Multi-tenancy Guide](/guides/multi-tenancy)
- [ActionPolicy Documentation](https://actionpolicy.evilmartians.io/)
