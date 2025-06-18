---
title: Policy Module
---

# Policy Module

The Policy module provides comprehensive authorization and access control for Plutonium applications. Built on top of [ActionPolicy](https://actionpolicy.evilmartians.io/), it offers fine-grained permissions, resource scoping, and entity-based authorization with a secure-by-default approach.

::: tip
The base policy class is `Plutonium::Resource::Policy`. Resource policies are typically located in `app/policies/`.
:::

## Overview

- **Resource-Level Authorization**: Control access to CRUD operations and custom actions.
- **Attribute-Level Permissions**: Fine-grained control over which fields a user can see or edit.
- **Association Control**: Manage access to related resources.
- **Entity Scoping**: Built-in support for multi-tenant authorization.
- **Secure Defaults**: Policies default to denying access, requiring explicit permission.

## Basic Policy Structure

Resource policies inherit from `Plutonium::Resource::Policy` and define methods to control access.

::: code-group
```ruby [app/policies/post_policy.rb]
class PostPolicy < Plutonium::Resource::Policy
  # Who can see a list of posts?
  def index?
    true # Everyone can see the list
  end

  # Who can see a single post?
  def show?
    record.published? || user == record.author || user.admin?
  end

  # Who can create a post?
  def create?
    user.present? # Any signed-in user
  end

  # Who can update a post?
  def update?
    user == record.author || user.admin?
  end

  # Who can destroy a post?
  def destroy?
    user.admin? # Only admins
  end

  # Who can run the custom 'publish' action?
  def publish?
    update? && record.draft? # Can only publish if you can update
  end
end
```
```ruby [Authorization Context]
# Policies automatically receive context from the controller.
class Plutonium::Resource::Policy < ActionPolicy::Base
  # `user` is the current authenticated user. It is required.
  authorize :user, allow_nil: false

  # `entity_scope` is the current portal's scoping entity (e.g., Organization).
  # It is optional.
  authorize :entity_scope, allow_nil: true
end
```
:::

::: danger Secure by Default
If a permission method (like `create?` or `publish?`) is not defined in your policy, it will default to `false`. You must explicitly grant permissions.
:::

## Attribute Permissions

You can control which attributes (fields) are visible or editable based on the action and user.

::: code-group
```ruby [Read Permissions]
class PostPolicy < Plutonium::Resource::Policy
  # Defines which attributes are visible on `show` and `index` pages.
  def permitted_attributes_for_read
    # Start with a base set of attributes
    attrs = [:title, :content, :category, :published_at]
    # Add admin-only attributes conditionally
    attrs << :internal_notes if user.admin?
    attrs
  end
end
```
```ruby [Create/Update Permissions]
class PostPolicy < Plutonium::Resource::Policy
  # Defines which attributes can be submitted in `new` and `edit` forms.
  def permitted_attributes_for_create
    [:title, :content, :category]
  end

  def permitted_attributes_for_update
    # Inherits from create by default, but can be customized.
    attrs = permitted_attributes_for_create
    attrs << :slug if user.admin? # Only admins can edit the slug
    attrs
  end
end
```
:::

::: details Full Permission Hierarchy
Plutonium uses a hierarchical permission system. Defining a core action permission (like `read?` or `create?`) automatically grants permission for related actions unless you override them.

**Action Permissions:**
- `index?` and `show?` inherit from `read?`
- `new?` inherits from `create?`
- `edit?` inherits from `update?`
- `update?` and `destroy?` inherit from `create?` by default.

**Attribute Permissions:**
- `_for_show` and `_for_index` inherit from `_for_read`.
- `_for_new` inherits from `_for_create`.
- `_for_edit` inherits from `_for_update`.
:::

## Scoping Collections

Use `relation_scope` to filter which records appear in a collection (e.g., on the `index` page).

::: code-group
```ruby [Simple Scope]
class PostPolicy < Plutonium::Resource::Policy
  relation_scope do |relation|
    if user.admin?
      relation # Admins see all posts
    else
      # Other users only see their own posts or published posts
      relation.where(author: user).or(relation.where(published: true))
    end
  end
end
```
```ruby [Multi-Tenant Scope]
class PostPolicy < Plutonium::Resource::Policy
  relation_scope do |relation|
    # `super` applies the portal's entity scoping first.
    # e.g., `relation.associated_with(current_organization)`
    relation = super(relation)

    # Then, apply additional logic.
    if user.admin?
      relation
    else
      relation.where(published: true)
    end
  end
end
```
:::

## Association Permissions

Control which associated resources can be accessed or rendered.

```ruby
class PostPolicy < Plutonium::Resource::Policy
  # This determines which associations can be rendered in the UI,
  # especially for nested forms or displays.
  def permitted_associations
    [:comments, :author, :tags]
  end

  # You can also define permissions for specific associations.
  # Can the user view the comments for this post?
  def show_comments?
    record.comments_public? || user.admin?
  end
end
```
