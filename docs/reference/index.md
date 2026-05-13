# Reference

Concept-by-concept API documentation. For task-oriented walkthroughs, see [Guides](/guides/).

## The seven areas

### [App](/reference/app/)
Installation, packages (feature + portal), portal engines, mounting, route registration (including singular and custom routes), connecting resources via `pu:res:conn`, full generator catalog.

### [Resource](/reference/resource/)
The four-layer resource — model, definition, query, actions. `pu:res:scaffold` field-type syntax, `has_cents`, SGID, URL routing, definition DSL (fields, inputs, displays, columns), page chrome, metadata panel, index views (table & grid), search, filters, scopes, sorting, custom + bulk actions.

### [Behavior](/reference/behavior/)
Controllers, policies, interactions. Controller hooks (redirect, params, presentation), policy action methods and `permitted_attributes_for_*`, `permitted_associations`, `relation_scope`, interaction structure, outcomes, chaining, URL generation.

### [UI](/reference/ui/)
Pages, forms, displays, tables, components, layouts, assets. Custom page classes, form field builders, association inputs (typeahead + inline `+`), built-in component kit, custom Phlex components, the shell, design tokens, `.pu-*` component classes, Phlexi themes.

### [Auth](/reference/auth/)
Rodauth installation, account types (basic / admin / SaaS), profile resource with the SecuritySection component.

### [Tenancy](/reference/tenancy/)
Multi-tenant entity scoping (`associated_with`, `default_relation_scope`, three model shapes), nested resources (parent/child routes, scoping), user invitations.

### [Testing](/reference/testing/)
The `Plutonium::Testing::*` concerns — CRUD, policy matrix, definition smoke tests, model concerns, nested resources, portal access, interaction outcomes.

## Quick reference

| I need to… | See |
|---|---|
| Install Plutonium | [App › Index](/reference/app/) |
| Run a generator | [App › Generators](/reference/app/generators) |
| Create a portal | [App › Portals](/reference/app/portals) |
| Scaffold a resource | [App › Generators › `pu:res:scaffold`](/reference/app/generators#pu-res-scaffold) |
| Configure form fields | [Resource › Definition](/reference/resource/definition) |
| Add search / filters | [Resource › Query](/reference/resource/query) |
| Add custom buttons / bulk actions | [Resource › Actions](/reference/resource/actions) |
| Override CRUD redirects / params | [Behavior › Controllers](/reference/behavior/controllers) |
| Control who can see what | [Behavior › Policies](/reference/behavior/policies) |
| Write business logic | [Behavior › Interactions](/reference/behavior/interactions) |
| Customize a page | [UI › Pages](/reference/ui/pages) |
| Customize a form | [UI › Forms](/reference/ui/forms) |
| Style the UI | [UI › Assets](/reference/ui/assets) |
| Set up Rodauth | [Auth › Accounts](/reference/auth/accounts) |
| Add a profile page | [Auth › Profile](/reference/auth/profile) |
| Scope to a tenant | [Tenancy › Entity scoping](/reference/tenancy/entity-scoping) |
| Wire user invitations | [Tenancy › Invites](/reference/tenancy/invites) |
| Test a resource | [Testing](/reference/testing/) |

## Reading this reference

- **🚨 Critical blocks** at the top of each page surface the "you'll regret this" rules. Skim them even if you're skimming the rest.
- **Option / DSL tables** are designed for scanning — find your option name without reading prose.
- **Cross-references** use VitePress relative paths. If a link points somewhere that doesn't exist yet, it's a known gap.
- **Concrete decision rules** ("use X when…, Y when…") sit alongside the option references. Reach for them when in doubt.
