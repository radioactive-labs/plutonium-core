# Tenancy Reference

Three closely-coupled concerns:

1. **[Entity scoping](./entity-scoping)** — every record belongs to a tenant; queries filter automatically.
2. **[Nested resources](./nested-resources)** — parent/child URLs; parent scoping takes precedence over entity scoping.
3. **[Invites](./invites)** — onboarding users into a tenant's membership.

## How entity scoping fits together

Three cooperating pieces:

| Piece | Role |
|---|---|
| **Portal** | Declares the entity class and how to resolve it from the request (`scope_to_entity Organization, strategy: :path`). |
| **Policy** | `default_relation_scope(relation)` calls `relation.associated_with(entity_scope)` on every collection query. Enforced via `verify_default_relation_scope_applied!`. |
| **Model** | `associated_with(entity)` resolves via custom scope, direct association, or `has_one :through`. |

Configure the portal once. The policy and model conventions then carry tenancy automatically.

## 🚨 Critical (applies to all three sub-pages)

- **Never bypass `default_relation_scope`.** Overriding `relation_scope` with `where(organization: ...)` or manual joins triggers `verify_default_relation_scope_applied!`. Make sure `default_relation_scope(relation)` is called somewhere in the chain — explicitly here, or via `super` to a parent policy (e.g., a package base) that calls it.
- **Always declare an association path from the model to the entity.** Direct `belongs_to`, `has_one :through`, or a custom `associated_with_<entity>` scope. If `associated_with` can't resolve, fix the **model**, not the policy.
- **Parent scoping beats entity scoping.** When a parent is present (nested resource), `default_relation_scope` scopes via the parent, not via `entity_scope`. Don't double-scope.
- **One level of nesting only.** Grandparent → parent → child nested routes are NOT supported. Use top-level routes for deeper relationships.
- **Compound uniqueness scoped to the tenant FK.** `validates :code, uniqueness: {scope: :organization_id}` — without this, uniqueness leaks across tenants.
- **Invite email must match the accepting user's email.** Security feature — don't disable `enforce_email?` lightly.

## Related

- [Behavior › Policy](/reference/behavior/policies) — `relation_scope` syntax
- [Resource › Model](/reference/resource/model) — model layer (associations, `has_cents`, SGID)
- [App › Portals](/reference/app/portals) — `scope_to_entity` engine config
- [Guides › Multi-tenancy](/guides/multi-tenancy) — task-oriented walkthrough
- [Guides › User invites](/guides/user-invites) — invitation setup recipe
