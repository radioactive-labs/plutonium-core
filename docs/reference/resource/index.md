# Resource Reference

A **resource** is the unit Plutonium gives you full CRUD for — list, show, create, edit, delete — automatically. It's four cooperating layers, plus an optional fifth for business logic.

| Layer | File | What it controls |
|---|---|---|
| [Model](./model) | `app/models/post.rb` | Data, validations, associations |
| [Definition](./definition) | `app/definitions/post_definition.rb` | UI — which fields, how they render, what actions exist |
| Policy | `app/policies/post_policy.rb` | Authorization — see [Behavior › Policy](/reference/behavior/policies) |
| Controller | `app/controllers/posts_controller.rb` | Request handling — see [Behavior › Controller](/reference/behavior/controllers) |
| Interaction *(optional)* | `app/interactions/publish_post_interaction.rb` | Business logic for custom actions — see [Behavior › Interaction](/reference/behavior/interactions) |

## How a resource is born

```bash
rails g pu:res:scaffold Post user:belongs_to title:string 'content:text?' --dest=main_app
rails db:prepare
rails g pu:res:conn Post --dest=admin_portal
```

That single scaffold gives you a working model + migration + controller + policy + definition. `pu:res:conn` adds it to a portal. See [App › Generators](/reference/app/generators) for the full generator catalog.

## Auto-detection is the default

Plutonium reads your model and renders every attribute automatically — type, label, form widget, display formatter, table column. You only declare overrides:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # No field/input/display/column needed unless you're overriding the default.
  field :content, as: :markdown      # override: render as markdown editor + viewer
  input :title, hint: "Be descriptive"
end
```

::: warning Don't declare for completeness
A `field :title` with no options that matches what Plutonium would auto-detect is **dead code** — it does nothing and clutters the file. Declare ONLY when you need a different type, an option, a `condition:`, a block, or a custom component.
:::

## Sub-pages

- [Model](./model) — `Plutonium::Resource::Record`, `has_cents`, SGID, custom routing, labeling
- [Definition](./definition) — fields, inputs, displays, columns, page chrome, metadata panel, index views
- [Query](./query) — search, filters, scopes, sorting
- [Actions](./actions) — custom actions, bulk actions, interaction integration

## Related

- [Guides › Adding Resources](/guides/adding-resources) — task recipe
- [App › Generators](/reference/app/generators) — `pu:res:scaffold` / `pu:res:conn` reference
- [Tenancy](/reference/tenancy/) — multi-tenant scoping
