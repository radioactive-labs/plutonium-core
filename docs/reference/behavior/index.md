# Behavior Reference

The behavior layer is intentionally thin:

- **[Controllers](./controllers) route** — handle requests, redirect after submit, transform params.
- **[Policies](./policies) authorize** — decide who can do what, which fields they can see, which records they can access.
- **[Interactions](./interactions) present** — declare the inputs for a custom operation (publish, archive, import, send invitation), render as a button and a form, and hand back an outcome.
- **[Async Interactions (Runs)](./runs)** — `dispatches_to` a persisted, resumable run instead of executing inline, for bulk operations, long-running work, or anything that needs an audit trail.

Registering an action and rendering it lives in [Resource › Definition](/reference/resource/definition) and [Resource › Actions](/reference/resource/actions). This section covers **writing** the controller hook, policy method, or interaction class behind it.

::: tip And the operation itself lives on the model
An interaction is a presentation object — it can only be constructed with a `view_context`. Logic may *start* in `execute`, but the second caller (a job, an API controller, a rake task, the console) is the trigger to move it onto the record, Rails-style. See [Interactions › What an interaction is for](./interactions#what-an-interaction-is-for).
:::

For multi-tenant `relation_scope` and entity scoping, see [Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

## At a glance

| Concern | Where it lives |
|---|---|
| Field rendering (inputs, displays, columns, search/filters) | [Definition](/reference/resource/definition) |
| Custom operations (publish, archive, import) | [Interaction](./interactions) + [Action](/reference/resource/actions) on the definition |
| Bulk/long-running operations, audit trail | [Async Interactions (Runs)](./runs) |
| Authorization rules | [Policy](./policies) |
| Tenant scoping (`relation_scope`) | [Policy](./policies) + [Tenancy](/reference/tenancy/entity-scoping) |
| Custom redirect logic, param munging, custom index query shape | [Controller hook](./controllers) |
| Presentation of parent/entity fields | [Controller presentation hooks](./controllers#presentation-hooks) |
