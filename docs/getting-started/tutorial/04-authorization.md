# Chapter 4: Implementing Authorization

In this chapter, you'll implement authorization policies to control who can do what.

## Understanding Policies

Plutonium uses policy classes to control authorization at three levels:

1. **Action Permissions** - Can the user perform this action? (create, read, update, delete)
2. **Attribute Permissions** - Which attributes can the user see/modify?
3. **Scope Permissions** - Which records can the user access?

## The Policy Class

Open the post policy:

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # By default, all actions are permitted
  # Let's add some restrictions
end
```

## Action Permissions

Let's implement basic CRUD permissions:

```ruby
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # Anyone can view published posts
  def read?
    record.published? || owner?
  end

  # Only the owner can edit
  def update?
    owner?
  end

  # Only the owner can delete
  def destroy?
    owner?
  end

  # Anyone authenticated can create
  def create?
    true
  end

  private

  def owner?
    record.user_id == user.id
  end
end
```

## Understanding the Policy Context

Inside a policy, you have access to:

| Accessor | Description |
|----------|-------------|
| `user` | The current authenticated user |
| `record` | The resource being authorized |
| `entity_scope` | Parent record for scoping (e.g., Organization in multi-tenant apps) |

```ruby
def some_permission?
  user          # => Current user (from authentication)
  record        # => The Post instance being checked
  entity_scope  # => Parent record for multi-tenancy (or nil)
end
```

## Attribute Permissions

Control which fields users can view and modify:

```ruby
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # Attributes allowed in forms (create/update)
  def permitted_attributes_for_create
    [:title, :body, :user_id]
  end

  def permitted_attributes_for_update
    if owner?
      [:title, :body, :published]
    else
      [] # Non-owners can't edit
    end
  end

  # Attributes visible in views
  def permitted_attributes_for_read
    if owner? || record.published?
      [:title, :body, :published, :created_at, :user]
    else
      [:title] # Limited view for unpublished posts
    end
  end
end
```

## Scope Permissions

Control which records appear in listings:

```ruby
class Blogging::PostPolicy < Blogging::ResourcePolicy
  # Called when listing posts
  def relation_scope(relation)
    if admin?
      relation # Admins see everything
    else
      relation.where(published: true).or(relation.where(user_id: user.id))
    end
  end

  private

  def admin?
    user.respond_to?(:admin?) && user.admin?
  end
end
```

## Portal-Specific Policies

Different portals can have different policies. Create a portal-specific policy:

```ruby
# packages/admin_portal/app/policies/admin_portal/blogging/post_policy.rb
class AdminPortal::Blogging::PostPolicy < ::Blogging::PostPolicy
  # Admins can do everything
  def read?
    true
  end

  def update?
    true
  end

  def destroy?
    true
  end

  def relation_scope(relation)
    relation # No scope restrictions for admins
  end
end
```

Plutonium automatically uses the portal-specific policy when available.

## Learn More

Plutonium policies extend [ActionPolicy](https://actionpolicy.evilmartians.io/). See the ActionPolicy documentation for advanced features like:

- [Aliases](https://actionpolicy.evilmartians.io/#/aliases) - Group actions under common rules
- [Pre-checks](https://actionpolicy.evilmartians.io/#/pre_checks) - Skip checks for certain users (e.g., admins)
- [Caching](https://actionpolicy.evilmartians.io/#/caching) - Cache authorization results

## What's Next

We have CRUD working with proper authorization. In the next chapter, we'll add a custom "Publish" action using Interactions.

[Continue to Chapter 5: Adding Custom Actions →](./05-custom-actions)
