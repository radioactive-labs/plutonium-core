# Behavior Reference

The behavior layer is intentionally thin:

- **[Controllers](./controllers) route** — handle requests, redirect after submit, transform params.
- **[Policies](./policies) authorize** — decide who can do what, which fields they can see, which records they can access.
- **[Interactions](./interactions) act** — encapsulate business logic for custom operations (publish, archive, import, send invitation).

Registering an action and rendering it lives in [Resource › Definition](/reference/resource/definition) and [Resource › Actions](/reference/resource/actions). This section covers **writing** the controller hook, policy method, or interaction class behind it.

For multi-tenant `relation_scope` and entity scoping, see [Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

## At a glance

| Concern | Where it lives |
|---|---|
| Field rendering (inputs, displays, columns, search/filters) | [Definition](/reference/resource/definition) |
| Custom operations (publish, archive, import) | [Interaction](./interactions) + [Action](/reference/resource/actions) on the definition |
| Authorization rules | [Policy](./policies) |
| Tenant scoping (`relation_scope`) | [Policy](./policies) + [Tenancy](/reference/tenancy/entity-scoping) |
| Custom redirect logic, param munging, custom index query shape | [Controller hook](./controllers) |
| Presentation of parent/entity fields | [Controller presentation hooks](./controllers#presentation-hooks) |
