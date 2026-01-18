# Authorization

This guide covers implementing authorization policies to control access.

## Overview

Plutonium authorization is built on [ActionPolicy](https://actionpolicy.evilmartians.io/) and works at three levels:

1. **Action Permissions** - Can the user perform this action?
2. **Attribute Permissions** - Which fields can the user see/modify?
3. **Scope Permissions** - Which records can the user access?

## Policy Structure

Policies inherit from a base `ResourcePolicy` class:

```ruby
# app/policies/resource_policy.rb (generated during install)
class ResourcePolicy < Plutonium::Resource::Policy
  def create?
    true
  end

  def read?
    true
  end
end

# app/policies/post_policy.rb (per resource)
class PostPolicy < ResourcePolicy
  def create?
    user.present?
  end

  def read?
    true
  end

  def update?
    owner?
  end

  def destroy?
    owner? || user.admin?
  end

  def permitted_attributes_for_create
    %i[title content]
  end

  def permitted_attributes_for_read
    %i[title content author_id created_at updated_at]
  end

  def permitted_associations
    %i[comments tags]
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

## Policy Context

Inside a policy, you have access to:

| Variable | Description |
|----------|-------------|
| `user` | Current authenticated user (required) |
| `record` | The resource being authorized |
| `entity_scope` | Current scoped entity (for multi-tenancy) |

```ruby
def update?
  user          # => Current user
  record        # => The specific Post instance
  entity_scope  # => Current parent/tenant entity
end
```

## Action Permissions

### Core Actions (Must Override)

The base `Plutonium::Resource::Policy` defaults `create?` and `read?` to `false`. You must override these:

```ruby
def create?  # Default: false
  user.present?
end

def read?    # Default: false
  true
end
```

### Derived Actions

Other actions inherit from core actions by default:

| Method | Inherits From | Override When |
|--------|---------------|---------------|
| `update?` | `create?` | Different update rules |
| `destroy?` | `create?` | Different delete rules |
| `index?` | `read?` | Custom listing rules |
| `show?` | `read?` | Record-specific read rules |
| `new?` | `create?` | Rarely needed |
| `edit?` | `update?` | Rarely needed |
| `search?` | `index?` | Search-specific rules |

```ruby
class PostPolicy < ResourcePolicy
  # Only need to override when rules differ
  def destroy?
    owner? || user.admin?  # Different from create?
  end
end
```

### Custom Actions

Define methods matching your action names:

```ruby
def publish?
  update? && record.draft?
end

def archive?
  update? && !record.archived?
end
```

Actions are secure by default - undefined methods return `false`.

## Attribute Permissions

### Core Methods (Must Override for Production)

```ruby
# What users can see (index, show)
def permitted_attributes_for_read
  %i[title content author_id published_at created_at]
end

# What users can set (create, update)
def permitted_attributes_for_create
  %i[title content]
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

### Per-Action Attributes

Show different fields for different views:

```ruby
def permitted_attributes_for_index
  %i[title author_id created_at]  # Minimal for list
end

def permitted_attributes_for_read
  %i[title content author_id tags created_at updated_at]  # Full for detail
end
```

### Conditional Attributes

```ruby
def permitted_attributes_for_create
  attrs = %i[title content]
  attrs << :featured if user.admin?
  attrs << :author_id if user.admin?  # Only admins can set author
  attrs
end
```

### Auto-Detection Warning

In development, undefined attribute methods auto-detect from the model. **This raises errors in production** - always define explicitly.

## Association Permissions

Control which associations can be rendered:

```ruby
def permitted_associations
  %i[comments tags author]
end
```

Used for nested forms, related data displays, and association fields in tables.

## Scope Permissions

Control which records appear in lists using ActionPolicy's `relation_scope`:

```ruby
class PostPolicy < ResourcePolicy
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
  relation = super(relation)  # Apply entity scope first

  if user.admin?
    relation
  else
    relation.where(published: true)
  end
end
```

## Portal-Specific Policies

Override policies for specific portals:

```ruby
# packages/admin_portal/app/policies/admin_portal/post_policy.rb
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  # Admins can do everything
  def destroy?
    true
  end

  def permitted_attributes_for_create
    %i[title content featured internal_notes]  # More fields
  end

  relation_scope do |relation|
    relation  # No restrictions
  end
end
```

For restricted portals:

```ruby
# packages/public_portal/app/policies/public_portal/post_policy.rb
class PublicPortal::PostPolicy < ::PostPolicy
  include PublicPortal::ResourcePolicy

  def create?
    false  # No public creation
  end

  relation_scope do |relation|
    relation.where(published: true)  # Only published
  end
end
```

Plutonium automatically uses portal-specific policies when available.

## Policy Helpers

Extract common logic into concerns:

```ruby
# app/policies/concerns/ownership.rb
module Ownership
  extend ActiveSupport::Concern

  def owner?
    return false unless record.respond_to?(:user_id)
    record.user_id == user.id
  end
end

# Use in policies
class PostPolicy < ResourcePolicy
  include Ownership

  def update?
    owner? || user.admin?
  end
end
```

## Testing Policies

### Manual Testing

```bash
rails runner "
  user = User.first
  post = Post.first
  policy = PostPolicy.new(user: user, record: post)

  puts 'Can read: ' + policy.read?.to_s
  puts 'Can update: ' + policy.update?.to_s
"
```

### RSpec with ActionPolicy

```ruby
# spec/policies/post_policy_spec.rb
RSpec.describe PostPolicy, type: :policy do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe '#update?' do
    context 'when user owns the post' do
      let(:record) { create(:post, user: user) }

      it { is_expected.to be_allowed_to(:update?) }
    end

    context 'when user does not own the post' do
      let(:record) { create(:post, user: other_user) }

      it { is_expected.not_to be_allowed_to(:update?) }
    end
  end
end
```

## Common Patterns

### Role-Based Access

```ruby
class PostPolicy < ResourcePolicy
  def destroy?
    case user.role
    when 'admin'
      true
    when 'editor'
      record.draft?
    when 'author'
      owner? && record.draft?
    else
      false
    end
  end
end
```

### Time-Based Permissions

```ruby
def update?
  owner? && record.created_at > 24.hours.ago
end
```

### Status-Based Permissions

```ruby
def update?
  return false if record.archived?
  return true if user.admin?
  owner? && record.draft?
end
```

### Check Model Capabilities

```ruby
def archive?
  return false unless record.respond_to?(:archived!)
  return false if record.archived?
  update?
end
```

### Prevent Actions on Archived Records

```ruby
def update?
  return false if record.try(:archived?)
  super
end

def destroy?
  return false if record.try(:archived?)
  super
end
```

## Handling Unauthorized Access

When authorization fails, ActionPolicy raises `ActionPolicy::Unauthorized`.

### Custom Error Handling

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from ActionPolicy::Unauthorized do |exception|
    respond_to do |format|
      format.html { redirect_to root_path, alert: "You are not authorized." }
      format.json { render json: { error: "Unauthorized" }, status: :forbidden }
    end
  end
end
```

### Skip Verification (Custom Actions)

Built-in CRUD actions automatically verify authorization. For custom actions:

```ruby
class PostsController < ResourceController
  skip_verify_authorize_current only: [:custom_action]

  def custom_action
    # Handle authorization manually or skip entirely
  end
end
```

## Debugging Authorization

### Check Why Access Denied

Add logging to your policy:

```ruby
def update?
  result = owner?
  Rails.logger.debug { "PostPolicy#update? for user #{user.id} on post #{record.id}: #{result}" }
  result
end
```

### Policy Inspection

```ruby
policy = PostPolicy.new(user: current_user, record: @post)
puts policy.permitted_attributes_for_update.inspect
```

## Related

- [Authentication](./authentication)
- [Multi-tenancy](./multi-tenancy)
- [Custom Actions](./custom-actions)
