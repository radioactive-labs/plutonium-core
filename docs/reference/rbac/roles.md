# RBAC Roles

::: warning Experimental
RBAC is experimental. The role model and role UI may change in a future release.
:::

## The role model

`Plutonium::Rbac::Role` (table `plutonium_rbac_roles`, key prefix `rbac_role`, route `rbac_roles`).

| Field | Type | Notes |
|-------|------|-------|
| `name` | string | Required. The role's label. |
| `key` | string | Derived from the name when blank (`"Billing Manager"` becomes `billing_manager`). Unique among global roles and within each tenant. |
| `description` | text | Optional. |
| `permissions` | json | Array of catalog keys, stored de-duplicated and sorted. Every key must exist in the [catalog](/reference/rbac/permissions#the-catalog). |
| `system_role` | boolean | Set by sync. System roles are read-only in the UI. |
| `entity` | polymorphic, optional | `nil` for a global role, the tenant for a tenant role. |

`Plutonium::Rbac::Role.global` returns roles with no entity. A role that is still assigned to a holder cannot be destroyed (`dependent: :restrict_with_error`).

| Validation error | When |
|------------------|------|
| "contains an unknown permission: ..." | A key is not in the catalog |
| "may only use wildcard ... on a system role" | A non-system role lists `*` or `<resource>.*` |
| "includes permissions you do not have: ..." | The [escalation guard](#the-escalation-guard) rejects added keys |

## System roles

Declared in code, usually in `config/initializers/rbac.rb`:

```ruby
Plutonium::Rbac.system_role :owner, name: "Owner", permissions: ["*"]
Plutonium::Rbac.system_role :member, name: "Member", permissions: ["hr/employee.read"]
```

`system_role(key, name:, permissions:, description: nil)`. System roles are the only roles that may hold wildcards.

### Sync

```bash
rails plutonium:rbac:sync
```

The task upserts each declared role as a global row with `system_role: true`, matched by key. It is safe to run on every deploy.

- All roles sync in one transaction: if any role fails (an unknown key, a conflict), none are written.
- If a global role that is not a system role already uses a declared key, the sync raises `Plutonium::Rbac::Sync::ConflictError` instead of taking it over. Rename or delete that role and sync again.
- The database refuses two global roles with the same key.
- To change a system role, edit the declaration and sync again. The UI cannot edit or delete it.

## Tenant roles

Roles created in an entity-scoped portal belong to that portal's tenant. They must list concrete catalog keys (no wildcards) and can only be assigned to holders in the same tenant.

## The role resource

The gem ships the model, definition (`Plutonium::Rbac::RoleDefinition`, with the permission grid as the `permissions` input and display) and policy (`Plutonium::Rbac::RolePolicy`). Register it in a portal (the installer does this with `--dest`):

```ruby
# packages/org_portal/config/routes.rb
register_resource ::Plutonium::Rbac::Role
```

The installer also generates a controller that ties new roles to the current tenant. Automatic entity scoping skips polymorphic associations, so `entity` is set in `resource_params`:

```ruby
class OrgPortal::RbacRolesController < ::OrgPortal::ResourceController
  controller_for ::Plutonium::Rbac::Role

  include OrgPortal::Concerns::Controller

  private

  def resource_params
    return super unless scoped_to_entity?

    super.merge(entity: current_scoped_entity)
  end
end
```

### `RolePolicy` rules

Managing roles is RBAC-gated like any other resource, through `rbac_role.read`, `.create`, `.update`, `.destroy` and `.export`. An Owner role with `*` covers them.

| Rule | Behavior |
|------|----------|
| `relation_scope` | Global roles plus the current tenant's. An unscoped portal sees global roles only. Another tenant's roles are never listed. |
| `create?` | `rbac_role.create`, and on a built record its `entity` must be the current tenant (`nil` in an unscoped portal, so an unscoped portal creates global roles only) |
| `update?`, `destroy?` | `rbac_role.update` / `.destroy`, and the role is not a system role and belongs to the current scope. Global roles are read-only in a tenant portal; a tenant's roles are read-only in an unscoped portal. |
| `permitted_attributes_for_create` | `name`, `key`, `description`, `permissions` |
| `permitted_attributes_for_read` | the above plus `system_role`, `created_at`; the index leaves out `permissions` |

To change any of this for one portal, define `<Portal>::Plutonium::Rbac::RolePolicy < ::Plutonium::Rbac::RolePolicy` (or a `RoleDefinition` the same way); portal lookup finds it by namespace.

## Assigning roles

Permit the `rbac_roles` association on the holder's policy and the form renders the standard association select:

```ruby
class OrganizationUserPolicy < ::ResourcePolicy
  def permitted_attributes_for_create
    [:organization, :user, :rbac_roles]
  end
end
```

The select's choices come from `RolePolicy`'s `relation_scope`. A role submitted from outside that scope is dropped before it reaches the model.

| Writer | Behavior |
|--------|----------|
| `rbac_roles=`, `rbac_role_ids=` | Stage the new set. Roles validate with the holder and the assignments are written after it saves, so a rejected role is a form error on the holder and nothing is half-saved. |
| `add_rbac_role_sgid`, `remove_rbac_role_sgid` | Stage the same way |
| `rbac_role_assignments=`, `rbac_role_assignment_ids=` | Raise `ArgumentError` |

An id that is not an integer is a validation error, and `rbac_roles=` raises `ActiveRecord::AssociationTypeMismatch` for anything that is not a role. An existing assignment's role or holder cannot be changed ("cannot be changed once assigned").

In code:

```ruby
membership.update!(rbac_role_ids: [role.id])
membership.rbac_granted?("hr/employee.read")
```

A tenant role assigned to a holder in another tenant fails with "belongs to a different tenant". A global role can be assigned to any holder.

## The escalation guard

Inside a Plutonium controller request, the acting user's holder is resolved for the current tenant and portal through [`rbac_holder`](/reference/rbac/#the-holder-resolver). Nobody can hand out a permission they lack:

- assigning a role fails with "includes permissions you do not have: ..." when the role carries a key the actor lacks
- creating or editing a role fails the same way for keys the actor lacks that the role did not already have

An actor holding `*` can grant anything. An actor whose `rbac_holder` is `nil` can grant nothing. The guard also runs inside [async interaction](/reference/behavior/async-interactions) runs, with the run's initiator in the run's tenant as the actor.

It does not run in the console, seeds, rake tasks (including `plutonium:rbac:sync`) or other background jobs, and it does not check removal: anyone who can edit a holder can take its roles away.

## Invites

A pending invite can hold roles before the user signs up. Include `Plutonium::Rbac::Invite` in the invite model, after the token concern:

```ruby
module Invites
  class UserInvite < Invites::ResourceRecord
    include Plutonium::Invites::Concerns::InviteToken
    include Plutonium::Rbac::Invite
  end
end
```

The invite becomes a holder whose `rbac_entity` is its `entity`. On acceptance its assignments move to the new membership inside the same lock and transaction as `accept_for_user!`, so a failed acceptance leaves them on the invite.

Include `Plutonium::Rbac::InviteUser` in the invite interaction, after the invites concern. It adds an `rbac_role_ids` attribute and passes it to the invite:

```ruby
class Organization::InviteUserInteraction < Plutonium::Resource::Interaction
  include Plutonium::Invites::Concerns::InviteUser
  include Plutonium::Rbac::InviteUser

  input :rbac_role_ids, as: :select, multiple: true,
    choices: ->(form) {
      Plutonium::Rbac::Role.global
        .or(Plutonium::Rbac::Role.where(entity: form.object.resource))
        .pluck(:name, :id)
    }
end
```

The escalation guard checks the inviter. The invite's `role` enum is still required by the invites system; RBAC does not read it.

## Storage notes

`holder_id` and `entity_id` are string columns so any primary key type fits. On Postgres, a join from them to an integer or uuid key needs a cast (`holder_id = organization_users.id::text`).

## Related

- [Permissions](/reference/rbac/permissions): the keys roles hold
- [Tenancy › Invites](/reference/tenancy/invites): the invites system
- [Guides › Roles & permissions](/guides/rbac)
