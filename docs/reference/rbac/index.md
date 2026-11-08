# RBAC Reference

::: warning Experimental
RBAC is experimental. The API, the permission key format and the role UI may change in a future release.
:::

Reference documentation for Plutonium's permission-based roles. Permissions are derived from your code; roles are stored in the database and assigned to holders. For a walkthrough, see [Guides › Roles & permissions](/guides/rbac).

## In this section

| Page | What it covers |
|------|---------------|
| [Permissions](/reference/rbac/permissions) | The key format, catalog sources, `Plutonium::Rbac::Policy` default predicates, custom actions, restricted fields, declared permissions, wildcards |
| [Roles](/reference/rbac/roles) | The role model, system roles and sync, tenant roles, the role resource and its policy, assigning roles, the escalation guard, invites |

## Install

```bash
rails g pu:rbac:install --holders=OrganizationUser:organization User --dest=org_portal
rails db:migrate
rails plutonium:rbac:sync
```

The installer enables the subsystem, writes `config/initializers/rbac.rb` (system roles), defines `rbac_holder` on `ResourcePolicy`, wires the holder models and the policy mixin, and registers the role resource in the portal. It does not migrate or sync. Options are listed under [Generators › `pu:rbac:install`](/reference/app/generators#pu-rbac-install).

## Configuration

Set in `config/initializers/plutonium.rb`:

| Option | Default | Description |
|--------|---------|-------------|
| `rbac.enabled` | `false` | Enable RBAC and register its migration (`plutonium_rbac_roles`, `plutonium_rbac_role_assignments`). Also turns on the escalation guard in controllers and async interaction runs. |

## The holder resolver

`rbac_holder` returns the record whose roles apply to `user` in `entity_scope`, or `nil` for no permissions. Define it on `ResourcePolicy`:

```ruby
# app/policies/resource_policy.rb
class ResourcePolicy < Plutonium::Resource::Policy
  include Plutonium::Rbac::Policy

  def rbac_holder
    return user if user.is_a?(Admin)
    OrganizationUser.find_by(user:, organization: entity_scope) if entity_scope
  end
end
```

A portal may override it in its `<Portal>::ResourcePolicy` module; `super` reaches the `ResourcePolicy` method:

```ruby
# packages/admin_portal/app/policies/admin_portal/resource_policy.rb
module AdminPortal
  module ResourcePolicy
    def rbac_holder = user.is_a?(Admin) ? user : super
  end
end
```

| Rule | Behavior |
|------|----------|
| Where it runs | `Plutonium::Rbac.holder_for(user:, entity_scope:, portal:)` builds `::ResourcePolicy` (with the portal's module included when it defines `rbac_holder`) and calls the method. Every RBAC policy, the gem's `RolePolicy`, the escalation guard and async runs go through it, so a resource without a portal policy gets the portal's holder. |
| The portal | The controller's engine when it is a portal engine; for an async run, the portal owning its stored authorization namespace. `nil` in the main app. |
| Default | `Plutonium::Resource::Policy#rbac_holder` returns `nil`. |
| Memoized | Per user, tenant and portal for the rest of the request or job. A `nil` user never reaches it. |
| `nil` | No permissions: every RBAC-gated predicate is `false`. |
| Other policies | Defining `rbac_holder` on any policy class other than `ResourcePolicy` raises when the class loads. |
| No `ResourcePolicy` | Raises `Plutonium::Rbac::NotConfiguredError`. |

## Holders

A holder is any model that holds roles: a membership, a user, an admin, a pending invite. Include `Plutonium::Rbac::Holder`:

```ruby
class OrganizationUser < ::ResourceRecord
  include Plutonium::Rbac::Holder

  belongs_to :organization
  belongs_to :user

  def rbac_entity = organization
end
```

| Method | Description |
|--------|-------------|
| `rbac_roles`, `rbac_role_assignments` | Associations to the held roles and their assignment rows |
| `rbac_roles=`, `rbac_role_ids=` | Stage a new role set; validated with the holder and written after it saves. See [Assigning roles](/reference/rbac/roles#assigning-roles). |
| `rbac_entity` | The tenant this holder belongs to. Defaults to `nil`. Tenant roles can only be assigned to a holder whose `rbac_entity` is the role's tenant. The installer writes `def rbac_entity = <association>` for each `Class:association` holder. |
| `rbac_permission_keys` | The union of its roles' keys, cached per request |
| `rbac_granted?(key)` | Whether one key is granted, wildcards included |

## Related

- [Guides › Roles & permissions](/guides/rbac): task-oriented walkthrough
- [Behavior › Policies](/reference/behavior/policies): policies without RBAC
- [Tenancy](/reference/tenancy/): entity-scoped portals and memberships
- [Testing](/reference/testing/#plutonium-testing-rbac): `with_rbac_permissions`
