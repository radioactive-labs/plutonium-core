---
title: "Introducing Plutonium RBAC: permission-based roles for your Rails policies"
titleTemplate: "Plutonium Blog"
date: 2026-11-08
description: Plutonium now ships an experimental role system. Permissions are derived from your resources and actions, tenants build their own roles from them, and your existing policies check them by default.
author: Stefan Froelich
tags: [announcement, authorization, rbac, multi-tenancy]
draft: true
---

# Introducing Plutonium RBAC: permission-based roles for your Rails policies

<BlogMeta />

The SaaS generators give each membership a `role` enum with three values, owner, admin and member, and each policy checks that enum by hand. If your customers need roles of their own, for example one that can read employee records and salaries but not change them, you have had to build that yourself.

Plutonium now includes an experimental role system for this. Permissions are derived from your resources and their actions. Roles are database records that tenants create from those permissions. Policies check them by default.

![The new-role form, with a permission grid that has a card per resource, a checkbox per action, and buttons that select an action across every resource](/images/guides/rbac-role-form.png)

## What's in the box

- A permission catalog built from your resources: the standard actions, the custom actions on their definitions, and any fields you mark as restricted.
- A `Plutonium::Rbac::Policy` mixin that makes `read?`, `create?`, `update?`, `destroy?` and custom action rules check the current user's permissions.
- Roles stored in the database and held by any model, usually the membership. System roles are declared in code and synced on deploy.
- A Roles page you can register in any portal, where tenants manage their own roles with the grid shown above.
- A check that prevents users from granting permissions they don't hold.
- Roles on invites, and a helper for policy tests.
- A `pu:rbac:install` generator.

## Install it

```bash
rails g pu:rbac:install --holders=OrganizationUser:organization --dest=org_portal
rails db:migrate
rails plutonium:rbac:sync
```

`--holders` names the model that holds roles, followed by the association that links it to a tenant. The generator includes `Plutonium::Rbac::Holder` in that model, adds the policy mixin to `ResourcePolicy`, enables the subsystem, registers the Roles page in `org_portal`, and writes the system roles to `config/initializers/rbac.rb`:

```ruby
# config/initializers/rbac.rb
Plutonium::Rbac.system_role :owner, name: "Owner", permissions: ["*"]
Plutonium::Rbac.system_role :member, name: "Member", permissions: []
```

It also defines `rbac_holder` on `ResourcePolicy`:

```ruby
# app/policies/resource_policy.rb
class ResourcePolicy < Plutonium::Resource::Policy
  include Plutonium::Rbac::Policy

  def rbac_holder
    OrganizationUser.find_by(user:, organization: entity_scope) if entity_scope
  end
end
```

`rbac_holder` returns the record whose roles apply to the current user in the current tenant. If it returns `nil`, the user has no permissions, so a user without a membership in the organization is denied everything. Every policy inherits this method. If a portal needs a different holder, such as an admin portal where the admin holds roles directly, branch inside it or override it in that portal's `AdminPortal::ResourcePolicy` module. It can't be defined on any other policy.

`rails plutonium:rbac:sync` writes the system roles to the database, and the UI doesn't allow editing them.

The `ResourcePolicy` that `pu:core:install` generates defines `create?` and `read?` to return `true`. Methods defined in a class take precedence over methods from an included module, so these two would override the permission checks. The installer removes them. If you have changed either method, the installer keeps your version and prints a warning.

## Where permissions come from

Plutonium builds the permission catalog from every resource whose policy includes the mixin. Each resource gets `read`, `create`, `update`, `destroy` and `export`, plus one permission for each custom action on its definitions. For an `Hr::Employee` with a `promote` action, the keys are:

```
hr/employee.read     hr/employee.create   hr/employee.update
hr/employee.destroy  hr/employee.export   hr/employee.promote
```

The prefix is the model's i18n key, which includes the namespace and is the same in every portal. When you add an action to a definition, a checkbox for it appears in the role form, and when you remove the action the checkbox goes away. Saving a role with a key that isn't in the catalog fails validation.

For permissions that don't correspond to a resource action, such as access to a reports page, declare them in the initializer with `Plutonium::Rbac.permission "reports.view"` and check them in a policy with `granted?("reports.view")`.

## How policies use them

With the mixin included, `read?` checks `hr/employee.read`, `update?` checks `hr/employee.update`, and the other core rules follow the same pattern. Custom actions don't need a policy method. When the table or show page asks for `promote?`, the mixin checks `hr/employee.promote`. The derived rules are unchanged: `index?` and `show?` use `read?`, and `edit?` uses `update?`. The difference from the default policy is that `update?` and `destroy?` have their own permissions instead of falling back to `create?`.

Buttons, menus and requests all use the same policy. A member without the `destroy` permission doesn't see the Delete button, and a delete request from that member returns a 403.

To combine a permission with a condition on the record, override the rule and call `super`, which performs the permission check:

```ruby
class Hr::EmployeePolicy < Hr::ResourcePolicy
  def promote? = super && !record.terminated?
end
```

With this override, promoting an employee requires the `promote` permission and an employee who isn't terminated.

## Restricting fields

To give a field its own permission, list it in the policy:

```ruby
class Hr::EmployeePolicy < Hr::ResourcePolicy
  rbac_restricted_attributes :salary

  def permitted_attributes_for_read = %i[name salary]
  def permitted_attributes_for_create = %i[name salary]
end
```

This adds `hr/employee.salary.read` and `hr/employee.salary.write` to the catalog. Users without the read permission don't see salary in the table, on the show page or in the CSV export. Users without the write permission don't see it in forms. The filtering applies to every `permitted_attributes_for_*` method, including ones a subclass overrides.

## Roles and tenants

A role has a name, a key and a list of permission keys. In a tenant portal, the Roles page lists the system roles and the tenant's own roles, and new roles belong to the current tenant. Tenants can't see or assign each other's roles, and a membership can only hold roles from its own tenant. When a member has several roles, they get the permissions of all of them.

You assign roles through the holder's `rbac_roles` association. Permit `:rbac_roles` in the membership policy and the membership form shows a role picker. Its choices come from the Role policy scope, so it lists only the roles available to the tenant.

## Preventing privilege escalation

If a tenant admin can manage roles, a plain form would let them create a role with every permission and assign it to themselves. To prevent this, Plutonium checks role changes and role assignments against the permissions of the user making them. Adding a permission to a role, or assigning a role, fails validation when it would grant a key that user doesn't have.

The check runs in forms, interactions and async interactions. Async interactions rebuild the user and tenant when the job runs, so the check uses the user who started the job. System roles can't be edited in the UI, and only system roles can use wildcards such as `*`.

## Invites and tests

Roles selected when sending an invite are stored on the pending invite. When the invite is accepted, they move to the new membership in the same transaction. If the acceptance fails, they stay on the invite.

In policy tests, `with_rbac_permissions` runs a block with the current user holding exactly the keys you pass:

```ruby
with_rbac_permissions("hr/employee.read") do
  assert policy.read?
  refute policy.promote?
end
```

The helper only works in unit tests, because Rails resets this state between requests. In integration tests, create roles and assign them to the user.

## Experimental, for now

RBAC is marked experimental, like dashboards, kanban, wizards and async interactions, and the API may change before 1.0. Two limitations remain. Permissions don't filter `sort`, `filter` or `search` declarations, so sorting by a restricted field still reveals the order of its values; avoid declaring those on restricted fields. Plain background jobs and the console run without the escalation check because there is no current user. If the API gets in your way, let me know.

## Where to go next

- [RBAC guide](/guides/rbac): setup, assigning roles, invites and testing.
- [RBAC reference](/reference/rbac/): permission keys, roles, configuration and policy rules.
