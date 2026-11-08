---
name: plutonium-rbac
description: 'Use BEFORE adding roles or permissions to a Plutonium app, or deciding "who can do what" per role: pu:rbac:install, the rbac_holder method, permission keys, the Plutonium::Rbac::Policy mixin, custom-action and restricted-field permissions, declared permissions, system roles + sync, tenant roles, the role resource, assigning roles, the escalation guard, invites with roles, and testing. The single source for experimental RBAC.'
---

# Plutonium RBAC (experimental)

Permission-based roles. Plutonium derives a permission key for every resource action and restricted field from your code; system roles are declared in code and synced; tenants build their own roles from a permission grid. Policies that include `Plutonium::Rbac::Policy` answer `read?`, `create?`, `update?`, `destroy?`, `export_csv?` and every custom action from the current holder's keys.

For policy structure without RBAC, load [[plutonium-behavior]]. For entity-scoped portals, memberships and invites, load [[plutonium-tenancy]]. Full detail: [Guides › Roles & permissions](/guides/rbac) and [Reference › RBAC](/reference/rbac/).

## 🚨 Critical (read first)

- **Experimental.** The API, key format and role UI may change, the same status as [[plutonium-wizard]], [[plutonium-kanban]] and [[plutonium-dashboard]].
- **A method defined in the policy class beats the mixin.** A `create?`/`read?`/`update?`/`destroy?` that returns a constant silently keeps that action open (or closed) for everyone and RBAC never runs. `pu:rbac:install` removes only the always-`true` `create?`/`read?` pair in the `--policy` file; delete the rest yourself, including in scaffolded subclasses.
- **Custom-action predicates: `def x? = super && ...`.** Never `update? && ...`: that gates on `.update` and makes the action's own key do nothing.
- **`update?`/`destroy?` no longer fall back to `create?`**, and `export_csv?` needs `.export`. A role must grant each one.
- **`nil` holder = everything denied.** The base `rbac_holder` returns `nil`. When portals need different holders, branch inside `ResourcePolicy#rbac_holder` (`return user if user.is_a?(Admin)`) or override it in that portal's `<Portal>::ResourcePolicy` module.
- **`rbac_holder` lives on `::ResourcePolicy` or a `<Portal>::ResourcePolicy` module, nowhere else.** Defining it on any other policy class raises at load time. There is no `config.rbac.holder`.
- **Keys exist only for resources governed by an RBAC policy.** A resource whose policies don't include the mixin has no keys, and a system role naming one fails sync with "contains an unknown permission".
- **Don't declare `sort`/`filter`/`search` on a restricted field.** RBAC filters `permitted_attributes_for_*` only; the query layer still uses the field.
- **The escalation guard only runs in controller requests and async interaction runs.** The console, seeds, rake tasks and plain jobs assign roles unchecked.
- **`with_rbac_permissions` is for policy/unit tests.** Rails resets the override at the start of every request; integration tests must create a real role and assign it.

---

## 🛑 Before you install: confirm the shape (ASK: don't infer)

"Add roles" does not say who holds them or where they are managed. Resolve these (skip any the user already stated), then restate the plan in one sentence:

1. **Who holds roles?** The membership join model (`OrganizationUser:organization`) for per-tenant roles, the user/admin model for roles outside any tenant, or both.
2. **Which policies become RBAC-governed?** The app-wide `ResourcePolicy` (default), or one package's base policy (`--policy=Hr::ResourcePolicy`) to roll out gradually. Decide what `rbac_holder` returns in each portal (membership, the user, an admin); `nil` denies everything there.
3. **Which portal manages roles?** An entity-scoped portal for tenant roles (`--dest=org_portal`), `main_app`, or none yet (`--skip-portal`).
4. **Which system roles ship in code?** Names and key lists (e.g. Owner `["*"]`, Member with read keys).
5. **Which fields are restricted** (salary, SSN), and which non-resource permissions are needed (`reports.view`)?

## ✅ Before you edit: verify the ground truth (CHECK: read it, don't ask for it)

| Check | How | Why |
|---|---|---|
| RBAC already enabled? | grep `config/initializers/plutonium.rb` for `rbac.enabled = true`; read `config/initializers/rbac.rb` | Don't re-run the installer over a working setup |
| Which policies use the mixin | `grep -rn "Plutonium::Rbac::Policy" app packages` | Decides whether predicates come from keys or hand-written code |
| Constant predicates that override RBAC | grep the policies for `def create?`, `def read?`, `def update?`, `def destroy?` and read each hit | A constant body wins over the mixin |
| The holder models | Read the membership model; confirm the tenant association name and `include Plutonium::Rbac::Holder` | `rbac_holder` and `rbac_entity` depend on it |
| The current `rbac_holder` | Read `app/policies/resource_policy.rb` and each `packages/*_portal/app/policies/*/resource_policy.rb` | Decides the holder per portal; an unscoped portal needs a branch or an override |
| The real key list | `rails runner 'puts Plutonium::Rbac::Catalog.keys.sort'` | Never guess a key: typos fail validation and sync |

## 🛠 Install (generator first)

```bash
rails g pu:rbac:install --holders=OrganizationUser:organization User --dest=org_portal
rails db:migrate
rails plutonium:rbac:sync
```

| Option | Default | Notes |
|---|---|---|
| `--holders=HOLDER...` | required | `Class:association` = membership in a tenant (gets `def rbac_entity = association`); bare `Class` = the user itself (outside a tenant for the membership's user class, everywhere for any other, e.g. `Admin`) |
| `--policy=CLASS` | `ResourcePolicy` | Receives `include Plutonium::Rbac::Policy` |
| `--user-association=NAME` | `user` | Membership holder's association to the user |
| `--dest=PORTAL` | prompt | `main_app` or a portal package; pass it for unattended runs |
| `--skip-portal` | `false` | Don't register the role resource |

It sets `config.rbac.enabled = true` (which registers the gem's migration), writes `config/initializers/rbac.rb` (system roles), defines `rbac_holder` in `app/policies/resource_policy.rb` (always that file, even with `--policy`), includes `Plutonium::Rbac::Holder` in each holder, includes the policy mixin, generates `RbacRolesController` and adds `register_resource ::Plutonium::Rbac::Role` to the portal routes. It does **not** migrate or sync: run both yourself.

## The holder: `rbac_holder`

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

```ruby
# packages/admin_portal/app/policies/admin_portal/resource_policy.rb (optional portal override)
module AdminPortal
  module ResourcePolicy
    def rbac_holder = user.is_a?(Admin) ? user : super
  end
end
```

Returns the record whose roles apply to `user` in `entity_scope`, or `nil` (no permissions). Resolved once per user, tenant and portal through `Plutonium::Rbac.holder_for`, which every RBAC policy, the gem's `RolePolicy`, the escalation guard and async runs share. The portal comes from the request's engine (or the async run's stored namespace), not from the policy, so a resource without a portal policy still gets the portal's override. `super` in a portal override reaches the `ResourcePolicy` method. No `::ResourcePolicy` raises `Plutonium::Rbac::NotConfiguredError`.

## Permission keys

`<model_name.i18n_key>.<action>`: `hr/employee.read`, `hr/employee.promote`, `hr/employee.salary.read`, `rbac_role.create`.

| Source | Keys |
|---|---|
| Every resource with an RBAC policy | `read`, `create`, `update`, `destroy`, `export` |
| Each non-built-in `action` on any of its definitions (base or portal) | `<action>` |
| Each `rbac_restricted_attributes` field | `<field>.read`, `<field>.write` |
| `Plutonium::Rbac.permission "reports.view"` | the key as written |

Wildcards (system roles only): `hr/employee.*` (one resource), `*` (everything).

## Default predicates

| Predicate | With the mixin |
|---|---|
| `read?` / `create?` / `update?` / `destroy?` | `granted?(:read)` / `(:create)` / `(:update)` / `(:destroy)` |
| `export_csv?` | `granted?(:export)` |
| `index?`, `show?` / `new?` / `edit?`, `kanban_move?`, `reposition?` / `search?`, `typeahead?` | unchanged: delegate to `read?` / `create?` / `update?` / `index?` |
| any declared custom action `x?` | `granted?(:x)`, no method needed |

`granted?(:sym)` expands to the policy's own resource; `granted?("reports.view")` takes a full key. A predicate for an action no definition declares still raises `NoMethodError`.

## Custom actions with record state

```ruby
class Blogging::PostPolicy < Blogging::ResourcePolicy
  def publish? = super && record.draft?
end
```

`super` is the permission check. Keep state gates in the policy, not in a `condition:` proc.

## Restricted fields

```ruby
class Hr::EmployeePolicy < Hr::ResourcePolicy
  rbac_restricted_attributes :salary

  def permitted_attributes_for_read
    [:organization, :name, :salary]
  end
end
```

Keep listing the field as usual. It is dropped from `_read`/`_index`/`_show`/`_export` without `hr/employee.salary.read` and from `_create`/`_update`/`_new`/`_edit` without `.salary.write`, including subclass overrides.

## Declared permissions

```ruby
# config/initializers/rbac.rb
Plutonium::Rbac.permission "reports.view", label: "View reports"

# a policy
def view_reports? = granted?("reports.view")
```

Grouped in the role grid by its first segment (override with `group:`).

## System roles

```ruby
Plutonium::Rbac.system_role :owner, name: "Owner", permissions: ["*"]
Plutonium::Rbac.system_role :member, name: "Member", permissions: ["hr/employee.read"]
```

`rails plutonium:rbac:sync` upserts them as global, read-only rows in one transaction; run it on every deploy. A hand-made global role with the same key raises `Plutonium::Rbac::Sync::ConflictError`. Only system roles may use wildcards. Edit the declaration and re-sync; the UI can't.

## Tenant roles and the role resource

Register in the portal (the installer does it with `--dest`):

```ruby
register_resource ::Plutonium::Rbac::Role
```

The gem ships the definition, policy and permission grid. The list shows global roles plus the current tenant's. The generated `RbacRolesController` ties new roles to `current_scoped_entity`; `create?` requires the record's `entity` to be the current tenant (so an unscoped portal creates global roles only). System roles and global roles are read-only in a tenant portal. Custom roles need concrete keys, no wildcards. Managing roles needs `rbac_role.read/create/update/destroy`. Override per portal with `MyPortal::Plutonium::Rbac::RolePolicy` / `RoleDefinition`.

## Assigning roles

Permit the `:rbac_roles` association on the holder's policy; the standard association select renders, no definition line:

```ruby
class OrganizationUserPolicy < ::ResourcePolicy
  def permitted_attributes_for_create
    [:organization, :user, :rbac_roles]
  end
end
```

- Choices come from the role policy's `relation_scope` (global + current tenant).
- `rbac_roles=` / `rbac_role_ids=` **stage**: validated with the holder, written after it saves, so a rejected role is a form error. In code: `holder.update!(rbac_role_ids: [...])`; check one key with `holder.rbac_granted?("hr/employee.read")`.
- Never use `rbac_role_assignments=` / `rbac_role_assignment_ids=` (they raise `ArgumentError`). An existing assignment's role or holder can't change.
- A tenant role can only go to a holder whose `rbac_entity` is that tenant.

**Escalation guard:** inside a request or async run, the actor's own holder is resolved for the current tenant. Assigning a role, or adding keys to a role, fails with "includes permissions you do not have: ..." for any key the actor lacks. `*` can grant anything; a `nil` actor holder grants nothing. Removal is not checked.

## Invites with roles

```ruby
# invite model, after InviteToken
include Plutonium::Rbac::Invite

# invite interaction, after Plutonium::Invites::Concerns::InviteUser
include Plutonium::Rbac::InviteUser
input :rbac_role_ids, as: :select, multiple: true,
  choices: ->(form) {
    Plutonium::Rbac::Role.global
      .or(Plutonium::Rbac::Role.where(entity: form.object.resource))
      .pluck(:name, :id)
  }
```

The pending invite holds the roles (tenant = invite `entity`); on acceptance they move to the new membership in the same transaction. The guard checks the inviter. The invite's `role` enum is still required; RBAC ignores it.

## Testing

```ruby
include Plutonium::Testing::Rbac

with_rbac_permissions("hr/employee.update") { refute policy.promote? }
with_rbac_permissions("hr/employee.promote") { assert policy.promote? }
```

Policy/unit tests only. Integration tests:

```ruby
role = Plutonium::Rbac::Role.create!(name: "Reviewer", entity: org, permissions: ["hr/employee.read"])
membership.update!(rbac_role_ids: [role.id])
```

## Gotchas and limitations

- Sorts, filters and search on restricted fields are not filtered: don't declare them.
- No guard in the console, seeds, rake tasks or plain jobs. Async interaction runs are guarded (actor = run initiator in the run's tenant).
- The catalog lists only models governed by an RBAC policy; add the mixin before naming a resource's keys.
- `holder_id`/`entity_id` are strings. On Postgres, joins to integer/uuid keys need a cast (`holder_id = organization_users.id::text`).
- Grants only: no deny rules, no role hierarchy, no last-owner protection, no audit log.
- The `pu:saas:setup` membership `role` enum is untouched and unread.

## Related skills

- [[plutonium-behavior]]: policy structure, `permitted_attributes_for_*`, interactions
- [[plutonium-tenancy]]: entity-scoped portals, memberships, invites
- [[plutonium-resource]]: declaring the `action`s that become keys
- [[plutonium-testing]]: integration test helpers
