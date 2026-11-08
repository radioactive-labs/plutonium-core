# RBAC (permission-based roles): design

Status: design approved in conversation, not yet implemented. Experimental.

## The problem

Plutonium authorization today is hand-written per policy. The SaaS membership
generator gives each membership a fixed `role` enum (`owner/admin/member`), and
every policy branches on it by hand (`user.admin?`). That does not scale to apps
where a tenant wants its own roles ("Billing Manager", "Reviewer") built from a
menu of permissions, and it gives no single place to see what a role can do.

## Goals

- Permissions are declared in code (derived from resources, actions and
  restricted fields), so they are stable and greppable.
- Roles are database rows carrying a list of permission keys. Code seeds locked
  system roles; tenants create their own roles from the code-defined permissions.
- A role is held by any model (a membership in tenant portals, a user/admin in
  portals without a tenant). A holder can have many roles; effective permissions
  are the union. Grants only, no deny.
- Policies get permission checks by default with no per-policy code. Overriding
  a predicate and calling `super` combines a grant with record state.
- v1 ships: role management UI, `pu:rbac:install`, field-level permissions,
  invite integration.

## Non-goals (v1)

Deny rules, role hierarchy/inheritance, last-owner lockout protection, audit log.
The existing membership `role` enum is left untouched; RBAC does not read it.

## Layout and enablement

- Namespace `Plutonium::Rbac`, code in `lib/plutonium/rbac/`.
- Off by default: `config.rbac.enabled = true`. The migration lives in
  `db/migrate/rbac/` and registers through `Plutonium::Migrations.register(:rbac, ...)`,
  the same mechanism wizards and async interactions use.
- Loaded from `experimental.rb`, not `plutonium.rb`.
- Docs carry the `::: warning Experimental` banner.

## Units

### `Plutonium::Rbac::Catalog`

Builds the permission catalog lazily (after eager load), memoized, cleared on
dev reload. Returns `Permission` value objects: `key`, `resource`, `action`,
`label`, `group`.

Sources:
1. Each resource class: `read`, `create`, `update`, `destroy`, `export`.
2. Every action declared on any definition for that resource (the base definition
   and portal-specific definitions), e.g. `publish`.
3. Restricted fields from `rbac_restricted_attributes` on the resource's policies:
   `<resource>.<field>.read` and `<resource>.<field>.write`.
4. Hand-declared extras: `Plutonium::Rbac.permission "reports.view", label: "..."`.

Key format: `"<resource>.<action>"`, where resource is `model_name.i18n_key`
(`blogging/post.publish`). A policy class can override the resource segment with
`rbac_resource_key "post"`.

### `Plutonium::Rbac::Role` (table `plutonium_rbac_roles`)

- `name`, `key` (unique within its entity), `description`
- `permissions`: JSON array of permission keys
- `system`: boolean. System roles are synced from code and read-only in the UI.
- `entity`: optional polymorphic. `nil` means global/system; set means a role a
  tenant created.
- Validation: every key must exist in the catalog, or be a wildcard (`*`,
  `<resource>.*`). Wildcards are allowed on system roles only.

### `Plutonium::Rbac::RoleAssignment` (table `plutonium_rbac_role_assignments`)

- polymorphic `holder`, `role`; unique index on `(holder_type, holder_id, role_id)`,
  inline in `create_table`.
- Validation: a tenant role (entity set) may only be assigned to a holder in
  that tenant.
- Escalation guard (validation): the role's permissions must be a subset of the
  assigning actor's effective permissions. The actor comes from
  `Plutonium::Rbac::Current.actor`; with no actor (console, seeds, sync) the
  check is skipped.

### `Plutonium::Rbac::Holder` (concern)

- `has_many :rbac_role_assignments, as: :holder`, `has_many :rbac_roles, through:`
- `role_ids` accessor for forms.
- `rbac_permission_keys`: one query, memoized via `Plutonium::Rbac::Current`.
- `rbac_granted?(key)`: exact match, `<resource>.*`, or `*`.

### Holder resolution

```ruby
config.rbac.holder = ->(user:, entity_scope:) {
  entity_scope ? entity_scope.memberships.find_by(user:) : user
}
```

There is no implicit default: the gem cannot know the membership association
name. The installer writes this resolver into `config/initializers/rbac.rb`
using the `--holder` it was given, and an unset resolver raises a clear error
on first use. A resolver returning `nil` means no permissions, so everything
is denied.

### `Plutonium::Rbac::Current` (CurrentAttributes)

Per-request/per-job cache of `holder -> permission keys`, plus `actor` for the
escalation guard. Reset automatically by Rails between requests and jobs. A
50-row table does one permissions query, not fifty.

### System roles from code

```ruby
Plutonium::Rbac.system_role :owner, name: "Owner", permissions: ["*"]
Plutonium::Rbac.system_role :member, name: "Member", permissions: ["blogging/post.read"]
```

`rake plutonium:rbac:sync` upserts these as `system: true` rows (idempotent);
the installer runs it.

## Policy mixin: `Plutonium::Rbac::Policy`

Included into the app's `ResourcePolicy` by the installer.

| Rule | Becomes |
|---|---|
| `read?` | `granted?(:read)` |
| `create?` | `granted?(:create)` |
| `update?` | `granted?(:update)` (no longer falls back to `create?`) |
| `destroy?` | `granted?(:destroy)` |
| `export_csv?` | `granted?(:export)` (opt-in, since a role has to grant it) |
| `index? show? new? edit? search? typeahead? kanban_move? reposition?` | unchanged, still delegate as today |

- `granted?(action_or_key)`: a symbol expands to `"<resource>.<action>"`, a
  string is used as a full key (`granted?("reports.view")`). Public inside policies.
- `rbac_holder`: resolves through `config.rbac.holder` with the policy's
  `user` and `entity_scope`.
- **Custom actions:** `respond_to_missing?` is true for `"<name>?"` when `<name>`
  is an action on any definition for the resource; `method_missing` resolves it
  to `granted?(name)`. Unknown predicates still raise through
  `send_with_report`, which keeps the async executor's renamed-predicate
  detection intact. An explicit method wins:
  `def publish? = super && record.draft?`.
- **Field permissions:** `rbac_restricted_attributes :salary, :ssn` (class
  macro). The mixin prepends a filter module onto every policy subclass via
  `inherited`, so it wraps that subclass's own overrides too. Filtering:
  - read side (`permitted_attributes_for_read/index/show/export`): drop a
    restricted field unless `<resource>.<field>.read` is granted.
  - write side (`permitted_attributes_for_create/update/new/edit`): drop
    unless `<resource>.<field>.write` is granted.
  Whether a field appears is the policy's call, so the macro lives on the
  policy, not the definition.

## Role management UI

Follows the AsyncRun pattern: the gem ships the definition, policy and
controller; apps `register_resource ::Plutonium::Rbac::Role` in a portal.

- The Role policy includes the RBAC mixin itself
  (`plutonium/rbac/role.read`, `.create`, ...), so Owner's `*` covers it and
  nothing special-cases admins. System roles: `update?`/`destroy?` are false.
- `relation_scope` calls `skip_default_relation_scope!` deliberately (default
  scoping would hide global roles) and returns
  `where(entity: nil).or(where(entity: entity_scope))` in a tenant portal, or
  `where(entity: nil)` without one. New roles get the current entity.
- `permissions` input `as: :rbac_permissions`: a grid with one row per
  resource and a checkbox per action, restricted fields indented under their
  resource, and select-all for each row and column. Hand-declared permissions
  appear grouped by their prefix. Interactivity is a Stimulus controller,
  registered.
- Holders: `role_ids` multi-select on the holder's form, choices limited by
  the Role policy scope. The escalation guard applies.

## Installer: `pu:rbac:install`

Options: `--holder=OrganizationUser` (repeatable), `--portal=org_portal` or
`--skip-portal`, `--dest=`.

1. Set `config.rbac.enabled = true`.
2. `include Plutonium::Rbac::Holder` in each holder model.
3. `include Plutonium::Rbac::Policy` in `ResourcePolicy`.
4. Write `config/initializers/rbac.rb`: holder resolver plus stub system
   roles (`owner: ["*"]`, `member:` read-only).
5. Register the Role resource in the portal (unless `--skip-portal`).
6. Run the migration and `plutonium:rbac:sync`.

## Invite integration

`include Plutonium::Rbac::Invite` on the invite model makes the pending invite
a holder. Roles are assigned to it through `role_assignments` (no new column).
After `create_membership_for(user)` returns, inside the same transaction, the
invite's assignments move onto the new membership. `InviteUser` gains a `roles`
input. The escalation guard applies with the inviter as the actor.

## Testing

Unit (`test/plutonium/rbac/`):
- Catalog: resource, definition-action, restricted-field and extra permissions;
  portal definitions contribute actions.
- Holder: exact and wildcard matching; per-request cache (one query).
- Policy mixin: default predicates; delegation chain unchanged; custom action
  via `respond_to?`; unknown predicate still raises; `super` combination;
  field filtering, including a subclass that overrides
  `permitted_attributes_for_index` directly.
- RoleAssignment: tenant mismatch rejected; escalation guard.
- Invite: assignments transfer on accept, atomically.

Integration (dummy app): `pu:rbac:install --holder=OrganizationUser
--portal=org_portal`, generated then customized. Request tests: a custom tenant
role with `blogging/post.publish` can publish but not destroy; a restricted
field is hidden from a role without its read permission.

Consumer helper: `Plutonium::Testing` gains `with_rbac_permissions(*keys)` for
policy tests.

Docs: `docs/guides/rbac.md` (experimental banner) plus updates to the
`plutonium-behavior` and `plutonium-tenancy` skills.
