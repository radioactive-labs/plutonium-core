# Roles and Permissions (RBAC)

::: warning Experimental
RBAC is experimental. The API, the permission key format and the role UI may change in a future release.
:::

Replace hand-written `user.admin?` branches with permissions declared by your code and roles stored in the database. Plutonium derives a permission for every resource action and restricted field, your app seeds locked system roles, and each tenant builds its own roles ("Billing Manager", "Reviewer") from that list.

## Goal

A member of an organization holds one or more roles. Each role is a list of permission keys such as `hr/employee.read` or `hr/employee.promote`. Policies that include `Plutonium::Rbac::Policy` answer `read?`, `create?`, `update?`, `destroy?`, `export_csv?` and every custom action from those keys, with no per-policy code. Restricted fields (a salary, an SSN) disappear from forms, tables and show pages unless the role grants them. Tenants manage their roles from a permission grid in their portal.

## Prerequisites

- A model that holds roles. In a multi-tenant app that is the membership join model from `pu:saas:setup` (`OrganizationUser`). In a portal without a tenant it can be the user or admin model itself.
- A portal to manage roles in. For tenant roles, an entity-scoped portal (see [Multi-tenancy](/guides/multi-tenancy)).

## Install

```bash
rails g pu:rbac:install --holders=OrganizationUser:organization User --dest=org_portal
rails db:migrate
rails plutonium:rbac:sync
```

`--holders` takes one or more models. `Class:association` marks a membership that belongs to a tenant through that association; a bare class holds roles as the user itself: outside a tenant when it is the class memberships point at (`User`), everywhere otherwise (`Admin`). The installer:

- sets `config.rbac.enabled = true` in `config/initializers/plutonium.rb` (this also registers the gem's migration, which creates `plutonium_rbac_roles` and `plutonium_rbac_role_assignments`)
- writes `config/initializers/rbac.rb` with two system roles
- defines `rbac_holder` on `ResourcePolicy` (`app/policies/resource_policy.rb`) from `--holders`, always in that file, even when `--policy` names another class
- adds `include Plutonium::Rbac::Holder` to each holder model, plus `def rbac_entity = organization` for a membership holder
- adds `include Plutonium::Rbac::Policy` to the policy named by `--policy` (default `ResourcePolicy`)
- generates a `RbacRolesController` in the portal and adds `register_resource ::Plutonium::Rbac::Role` to its routes (skip with `--skip-portal`)

The installer does not migrate or sync for you: the migration path is registered at boot, and the generator's process booted before the flag existed.

| Option | Default | Description |
|---|---|---|
| `--holders=HOLDER...` | (required) | Holder models, `Class` or `Class:entity_association` |
| `--policy=CLASS` | `ResourcePolicy` | Policy class that receives `Plutonium::Rbac::Policy` |
| `--user-association=NAME` | `user` | Association from a membership holder to the user |
| `--dest=PORTAL` | prompt | Portal that gets the role resource (`main_app` or a portal package) |
| `--skip-portal` | `false` | Do not connect the role resource to a portal |

::: danger Remove hand-written `create?` and `read?`
A method defined in the policy class wins over the mixin, so a `create?` or `read?` that returns `true` keeps those actions open to everyone and RBAC never runs for them. `pu:core:install` generates exactly that pair in `ResourcePolicy`, so the installer removes `def create?`/`def read?` from the `--policy` file when the body is plain `true` (the multi-line form or `def create? = true`) and logs each removal. A `create?` or `read?` with any other body is left alone and reported as a warning, because only you know whether it should stay. Scaffolded policies often uncomment the same two methods: delete every `create?`/`read?`/`update?`/`destroy?` that returns a constant from the subclasses yourself. To roll RBAC out one package at a time, point `--policy` at that package's base policy instead (`--policy=Hr::ResourcePolicy`).
:::

## The holder

`rbac_holder` tells Plutonium which record holds roles for the current user in the current tenant. It is a method on your `ResourcePolicy`, which every policy in the app inherits. For the install command above the installer writes:

```ruby
class ResourcePolicy < Plutonium::Resource::Policy
  include Plutonium::Rbac::Policy

  # Who holds roles for `user` in `entity_scope`. nil means no permissions.
  def rbac_holder
    return user unless entity_scope

    OrganizationUser.find_by(user:, organization: entity_scope)
  end
end
```

The method sees the same `user` and `entity_scope` as any policy, and its answer is memoized per user and tenant for the rest of the request. A `nil` user never reaches it. A `nil` return means no permissions, so every RBAC-gated predicate is `false`. The base `Plutonium::Resource::Policy#rbac_holder` returns `nil`, so an app that never defines it has RBAC deny everything.

Portal policies are optional, so a resource without one still resolves its holder through `ResourcePolicy`. When portals need different holders, branch inside the method:

```ruby
def rbac_holder
  return user if user.is_a?(Admin)
  OrganizationUser.find_by(user:, organization: entity_scope) if entity_scope
end
```

A portal can also override it in its `<Portal>::ResourcePolicy` module (the one `pu:pkg:portal` generates). The override applies to every authorization in that portal, including resources without a portal policy, and `super` reaches the `ResourcePolicy` method:

```ruby
module AdminPortal
  module ResourcePolicy
    def rbac_holder = user.is_a?(Admin) ? user : super
  end
end
```

Those are the only two places. Defining `rbac_holder` on any other policy class raises when the class loads, because RBAC never calls it there. Plutonium looks the portal up from the controller's engine, and an async run from its stored authorization namespace.

Using RBAC without a `ResourcePolicy` raises `Plutonium::Rbac::NotConfiguredError`.

## Permission keys

A key is `<resource>.<action>`, where the resource segment is the model's `model_name.i18n_key`. The catalog is built from your code, so the keys are stable and greppable. For the dummy app's `Hr::Employee`, with a `promote` action and a restricted `salary` field, and for the role resource itself:

```
hr/employee.create
hr/employee.destroy
hr/employee.export
hr/employee.promote
hr/employee.read
hr/employee.salary.read
hr/employee.salary.write
hr/employee.update
rbac_role.create
rbac_role.destroy
rbac_role.export
rbac_role.read
rbac_role.update
```

Each resource governed by at least one policy that includes `Plutonium::Rbac::Policy` gets `read`, `create`, `update`, `destroy` and `export`. A resource whose policies do not use the mixin gets no keys, because nothing would read them. Every action declared on any of its definitions (the base one and portal-specific ones) that is not a Plutonium built-in becomes a key. Each restricted attribute adds `<field>.read` and `<field>.write`. The role model's key prefix is `rbac_role`.

The full list of catalog sources and wildcard rules is in [RBAC › Permissions](/reference/rbac/permissions#the-catalog). Print the catalog for your app:

```bash
rails runner 'puts Plutonium::Rbac::Catalog.keys.sort'
```

Two wildcards exist for system roles: `hr/employee.*` grants every key of one resource, and `*` grants everything.

## Default predicates

With `Plutonium::Rbac::Policy` included, the core predicates read permissions:

| Predicate | Without RBAC | With RBAC |
|---|---|---|
| `read?` | `false` | `granted?(:read)` |
| `create?` | `false` | `granted?(:create)` |
| `update?` | delegates to `create?` | `granted?(:update)` |
| `destroy?` | delegates to `create?` | `granted?(:destroy)` |
| `export_csv?` | `false` | `granted?(:export)` |
| `index?`, `show?` | delegate to `read?` | unchanged |
| `new?` | delegates to `create?` | unchanged |
| `edit?`, `kanban_move?`, `reposition?` | delegate to `update?` | unchanged |
| `search?`, `typeahead?` | delegate to `index?` | unchanged |

`update?` and `destroy?` no longer fall back to `create?`: a role that can create records cannot edit or delete them unless it also holds `.update` and `.destroy`. CSV export stays opt-in, because a role has to grant `.export`.

`granted?` is public inside the policy. A symbol expands to the policy's own resource (`granted?(:update)` is `hr/employee.update` in `Hr::EmployeePolicy`); a string is a full key (`granted?("reports.view")`).

## Custom actions

Any action declared on a definition gets a predicate for free:

```ruby
class Hr::EmployeeDefinition < Hr::ResourceDefinition
  action :promote, interaction: Hr::PromoteEmployee
end
```

`Hr::EmployeePolicy#promote?` now returns whether the holder has `hr/employee.promote`. You do not write the method. A predicate for an action that no definition declares still raises `NoMethodError`, as it does without RBAC.

To combine the grant with record state, define the method and call `super`:

```ruby
class Blogging::PostPolicy < Blogging::ResourcePolicy
  def publish? = super && record.draft?
end
```

`super` reaches the permission check, so the action needs both `blogging/post.publish` and a draft record. Avoid the pre-RBAC idiom `def publish? = update? && record.draft?`: it gates the action on `.update` instead of `.publish`, and the `publish` key in the role grid stops doing anything.

## Restricted fields

Whether a field appears is the policy's call, so field permissions live on the policy:

```ruby
class Hr::EmployeePolicy < Hr::ResourcePolicy
  rbac_restricted_attributes :salary

  def permitted_attributes_for_create
    [:organization, :name, :salary]
  end

  def permitted_attributes_for_read
    [:organization, :name, :salary]
  end
end
```

`salary` is dropped from the read side (`permitted_attributes_for_read`, `_index`, `_show`, `_export`) unless the holder has `hr/employee.salary.read`, and from the write side (`_create`, `_update`, `_new`, `_edit`) unless it has `hr/employee.salary.write`. The filter wraps every subclass's own overrides too, so a portal policy that redefines `permitted_attributes_for_index` is still filtered. Keep listing the field in `permitted_attributes_for_*` as usual; the macro only removes it.

## Declared permissions

For a permission that is not one resource action (a reports page, a feature switch), declare it in `config/initializers/rbac.rb`:

```ruby
Plutonium::Rbac.permission "reports.view", label: "View reports"
```

It appears in the role grid, grouped by its first segment ("Reports"). Check it with the full key:

```ruby
def view_reports? = granted?("reports.view")
```

## System roles

System roles are declared in code and synced to the database as global, read-only rows:

```ruby
Plutonium::Rbac.system_role :owner, name: "Owner", permissions: ["*"]
Plutonium::Rbac.system_role :member, name: "Member", permissions: ["hr/employee.read"]
```

```bash
rails plutonium:rbac:sync
```

The task upserts each role by key in one transaction and is safe to run on every deploy. If a global role that is not a system role already uses a declared key, the sync raises `Plutonium::Rbac::Sync::ConflictError` instead of taking it over; rename or delete that role and sync again. The database also refuses two global roles with the same key. System roles are the only roles that may use wildcards. They cannot be edited or deleted from the UI; change the declaration and sync again. Every key must exist in the catalog, so a typo fails the sync with "contains an unknown permission".

## Tenant roles

The role model, its policy rules and per-portal overrides are listed in [RBAC › Roles](/reference/rbac/roles#the-role-resource). Register the role resource in a portal (the installer does this with `--dest`):

```ruby
# packages/org_portal/config/routes.rb
register_resource ::Plutonium::Rbac::Role
```

The gem ships the definition, policy and permission grid. In an entity-scoped portal:

- the role list shows global roles plus the current tenant's roles, never another tenant's
- a role created there belongs to the current tenant (the generated `RbacRolesController` sets `entity` in `resource_params`)
- a role record can only be created for the current tenant (`create?` checks the record's `entity`), so an unscoped portal creates global roles only
- a tenant role can be edited and deleted only from its own tenant; global roles are read-only there
- custom roles must list concrete keys from the catalog, no wildcards

Managing roles is gated by RBAC like any other resource: `rbac_role.read`, `rbac_role.create`, `rbac_role.update` and `rbac_role.destroy`. The Owner role's `*` covers them.

## Assigning roles

`Plutonium::Rbac::Holder` gives each holder an `rbac_roles` association. Permit it on the holder's policy and the form renders the standard association select:

```ruby
class OrganizationUserPolicy < ::ResourcePolicy
  def permitted_attributes_for_create
    [:organization, :user, :rbac_roles]
  end
end
```

Its choices come from the role policy's `relation_scope`: the global roles plus the current tenant's. A role submitted from outside that scope is dropped before it reaches the model.

Assigning roles stages the change. `rbac_roles=` and `rbac_role_ids=` both validate the roles with the holder and write the assignments after it saves, so a rejected role shows up as a form error on the holder and nothing is half-saved. Rails' own has_many writers would save on assignment instead. `add_rbac_role_sgid` and `remove_rbac_role_sgid` stage the same way. An id that is not an integer is a validation error, and `rbac_roles=` raises `ActiveRecord::AssociationTypeMismatch` for anything that is not a role.

Assignment rows are not edited in place. `rbac_role_assignments=` and `rbac_role_assignment_ids=` raise `ArgumentError` (they would move other holders' rows), and changing an existing assignment's role or holder fails validation. Assign through `rbac_roles=` or `rbac_role_ids=` instead.

Assignments are validated twice:

- a tenant role can only be assigned to a holder in the same tenant ("belongs to a different tenant")
- the escalation guard, below

In code, `holder.update!(rbac_role_ids: [...])` does the same thing. `holder.rbac_granted?("hr/employee.read")` checks one key.

## The escalation guard

Inside a Plutonium controller, the acting user's own holder is resolved for the current tenant, and nobody can hand out a permission they do not have:

- assigning a role fails with "includes permissions you do not have: ..." when the role carries a key the actor lacks
- creating or editing a role fails the same way for keys the actor lacks that the role did not already have

An actor holding `*` can grant anything. An actor whose `rbac_holder` is `nil` can grant nothing through the UI. The guard runs inside controller requests and inside [async interaction](/reference/behavior/async-interactions) runs, where the actor is the run's initiator in the run's tenant. Seeds, the console, other background jobs and `plutonium:rbac:sync` are not checked.

## Invites

Invited users can receive roles before they sign up. Include `Plutonium::Rbac::Invite` in the invite model generated by `pu:invites:install`:

```ruby
module Invites
  class UserInvite < Invites::ResourceRecord
    include Plutonium::Invites::Concerns::InviteToken
    include Plutonium::Rbac::Invite
    # ...
  end
end
```

The pending invite becomes a holder whose tenant is the invite's `entity`. On acceptance, its role assignments move to the new membership inside the same lock and transaction as `accept_for_user!`, so a failed acceptance leaves them on the invite.

Then include `Plutonium::Rbac::InviteUser` in the invite interaction, after the invites concern, and add an input for the roles:

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
  # ...
end
```

`Plutonium::Rbac::InviteUser` adds the `rbac_role_ids` attribute and passes it to the invite. The escalation guard applies with the inviter as the actor. The invite's `role` enum is still required by the invites system; RBAC does not read it.

## Testing

`Plutonium::Testing::Rbac` runs a block as if the current holder had exactly the given keys:

```ruby
require "plutonium/testing"

class Hr::EmployeePolicyTest < ActiveSupport::TestCase
  include Plutonium::Testing::Rbac

  test "promote needs its own permission" do
    policy = Hr::EmployeePolicy.new(Hr::Employee.new, user: User.new, entity_scope: Organization.new)

    with_rbac_permissions("hr/employee.update") { refute policy.promote? }
    with_rbac_permissions("hr/employee.promote") { assert policy.promote? }
  end
end
```

The override lives in per-request state, which Rails resets at the start of every request, so it is for policy and unit tests. In integration tests, create a real role and assign it:

```ruby
role = Plutonium::Rbac::Role.create!(name: "Reviewer", entity: org, permissions: ["hr/employee.read"])
membership.update!(rbac_role_ids: [role.id])
```

## Limitations

RBAC v1 deliberately leaves these out:

- **No deny rules.** Permissions are grants only; a holder's permissions are the union of its roles.
- **No role hierarchy.** A role cannot inherit from another role.
- **No last-owner protection.** Nothing stops the last owner of a tenant from losing the Owner role.
- **No audit log** of role or assignment changes.
- **No guard on removal.** The escalation guard checks what is granted, not what is taken away, so anyone who can edit a holder can remove its roles.
- **No guard outside requests and async interactions.** Other jobs, the console, seeds and rake tasks assign roles unchecked.
- **Sorts, filters and search ignore restricted fields.** A definition's `sort`, `filter` or `search` on a restricted field still runs for a holder without the field's `.read` grant, which lets them order or narrow records by a value they cannot see. Do not declare sorts, filters or search on restricted fields.
- **Holder and entity ids are strings.** `holder_id` and `entity_id` are string columns so any primary key type fits. On Postgres, a join from those columns to an integer or uuid key needs an explicit cast (`holder_id = organization_users.id::text`).

The membership `role` enum from `pu:saas:setup` is left untouched, and RBAC does not read it.

## Related

- [Authorization](/guides/authorization): policies without RBAC
- [Multi-tenancy](/guides/multi-tenancy): entity-scoped portals
- [User invites](/guides/user-invites): the invites system RBAC extends
- [RBAC reference](/reference/rbac/): configuration, holders, [permissions](/reference/rbac/permissions) and [roles](/reference/rbac/roles)
- [Policies reference](/reference/behavior/policies)
