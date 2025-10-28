# Advanced Concept: Authorization

Plutonium provides a robust authorization system built on top of [Action Policy](https://actionpolicy.evilmartians.io/). It's designed to be secure by default while offering fine-grained control over every aspect of your application's access control.

## Core Principles

Authorization in Plutonium is handled by **Policy** classes. Every resource should have a corresponding policy that inherits from `Plutonium::Resource::Policy`.

A policy's primary job is to answer the question: "Can the current `user` perform this `action` on this `record`?"

```ruby
class PostPolicy < Plutonium::Resource::Policy
  # Can the user see a list of posts?
  def index?
    true # Everyone can see the list
  end

  # Can the user update this specific post?
  def update?
    # `record` is the post instance.
    # `user` is the current authenticated user.
    record.author == user || user.admin?
  end

  # ... other permissions
end
```

## Secure by Default: The Permission Chain

Plutonium policies are secure by default. If a permission is not explicitly granted, it's denied. This is achieved through a clear inheritance chain.

::: code-group

```ruby [Core Permissions]
# These are the base permissions.
# They both default to `false`. You MUST override them.
def create?
  false
end

def read?
  false
end
```

```ruby [Derived Permissions]
# These permissions inherit from the core ones.
# You can override them for more granular control.
def update?
  create?
end

def destroy?
  create?
end

def index?
  read?
end

def show?
  read?
end
```

:::

::: danger Always Define Core Permissions
Because `create?` and `read?` default to `false`, you must define them in your policy to grant any access. If `create?` is `false`, then `update?` and `destroy?` will also be `false` unless you explicitly override them.
:::

## Attribute & Association Permissions

Beyond actions, policies also control access to a resource's data at a granular level.

### Attribute Permissions

Attribute permissions control which fields a user can see or submit in a form. They follow a similar inheritance chain.

::: code-group

```ruby [Read Attributes]
# Controls which fields are returned for `index` and `show` actions.
def permitted_attributes_for_read
  # By default, auto-detects all columns in development,
  # but MUST be overridden for production.
end
```

```ruby [Create/Update Attributes]
# Controls which fields are allowed in `create` and `update` actions.
def permitted_attributes_for_create
  # By default, auto-detects columns (minus some system ones)
  # in development, but MUST be overridden for production.
end

def permitted_attributes_for_update
  # Inherits from `permitted_attributes_for_create` by default.
  permitted_attributes_for_create
end
```

:::

::: warning Override in Production
The default auto-detection for attributes only works in development to speed up initial scaffolding. You **must** override `permitted_attributes_for_create` and `permitted_attributes_for_read` in your policies for them to work in production.
:::

### Association Permissions

By default, no associations are permitted. You must explicitly list which related resources can be included.

```ruby
class PostPolicy < Plutonium::Resource::Policy
  def permitted_associations
    [:comments, :author]
  end
end
```

## Scoping: Filtering Collections

A policy's `relation_scope` is used to filter down a collection of records to only what the current user should see. This is applied automatically on `index` pages.

::: code-group

```ruby [Simple Scope]
class PostPolicy < Plutonium::Resource::Policy
  relation_scope do |relation|
    if user.admin?
      relation # Admins see all posts
    else
      # Others only see their own posts or published posts
      relation.where(author: user).or(relation.where(published: true))
    end
  end
end
```

```ruby [Multi-Tenant Scope]
class PostPolicy < Plutonium::Resource::Policy
  relation_scope do |relation|
    # `super` applies the portal's entity scoping first
    # e.g., `relation.associated_with(current_organization)`
    relation = super(relation)

    # Then, apply additional logic
    if user.admin?
      relation
    else
      relation.where(published: true)
    end
  end
end
```

:::

## Authorization Context

Policies have access to a `context` object. By default, Plutonium provides two:

- **`user`**: The current authenticated user. This is **required**.
- **`entity_scope`**: The current portal's multi-tenancy record (e.g., the current `Organization`). This is optional.

You can add your own custom context objects for more complex scenarios.

::: details Adding Custom Context
Imagine you have a separate `Ability` system that you also want to check.

**1. Define the context in the Policy:**

```ruby
class PostPolicy < ResourcePolicy
  authorize :ability, allow_nil: true

  def promote?
    # You can now use `ability` in your permission checks
    user.admin? && ability&.can?(:promote, record)
  end
end
```

**2. Provide the context from the Controller:**

```ruby
class PostsController < ResourceController
  # This tells the policy how to find the `ability` object.
  authorize :ability, through: :current_ability

  private

  def current_ability
    # Your custom logic to find the ability object
    Ability.new(user)
  end
end
```

:::
