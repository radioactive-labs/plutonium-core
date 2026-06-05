# Adding Resources

Add a new model to your Plutonium app: scaffold it, migrate it, connect it to a portal.

## Goal

Get a working list/show/new/edit/delete UI for a new model with sensible defaults, then customize as needed.

## Steps

### 1. Scaffold the resource

```bash
rails g pu:res:scaffold Post user:belongs_to title:string 'content:text?' published:boolean --dest=main_app
```

Quote any field containing `?` or `{}` to prevent shell expansion.

Full field-type syntax: [Reference › Resource › Model](/reference/resource/model). For all `pu:res:scaffold` options: [Reference › Generators](/reference/app/generators#pu-res-scaffold).

### 2. Review the migration

Plutonium generates a basic migration. Before running it, edit `db/migrate/<timestamp>_create_posts.rb` to add:

- Cascade deletes (`foreign_key: {on_delete: :cascade}`)
- Composite indexes for tenant-scoped uniqueness
- Sensible defaults

### 3. Run the migration

```bash
rails db:prepare
```

### 4. Connect to a portal

```bash
rails g pu:res:conn Post --dest=admin_portal
```

This creates the portal-specific controller, policy, and definition, plus registers the resource in the portal's routes. Until you do this, the resource has no URL.

For singular resources (`/profile`, `/settings`), add `--singular`:

```bash
rails g pu:res:conn Profile --dest=customer_portal --singular
```

### 5. Trim the generated policy

The generator is liberal — it seeds `permitted_attributes_for_*` from your model columns. Open `packages/admin_portal/app/policies/admin_portal/post_policy.rb` and:

- Drop `_id` fields when the form should use the association name (e.g. `:user`, not `:user_id`).
- Replace `:price_cents` with `:price` if the model uses `has_cents`.
- Reduce to what users should actually be able to set/see.

See [Reference › Behavior › Policies](/reference/behavior/policies) for details.

### 6. Visit the portal

```
http://localhost:3000/admin/posts
```

You should see:

- Index page with the columns auto-detected from your model.
- "New" button.
- Show / edit / delete on each row.

## Customizing what you get

| Want to change | Edit | See |
|---|---|---|
| Which fields appear / how they render | The definition | [Reference › Resource › Definition](/reference/resource/definition) |
| Search, filters, scopes, sorting | The definition | [Reference › Resource › Query](/reference/resource/query) |
| Custom buttons / bulk actions | The definition + an interaction | [Reference › Resource › Actions](/reference/resource/actions) |
| Authorization rules | The policy | [Reference › Behavior › Policies](/reference/behavior/policies) |
| Redirects, params, presentation | The controller | [Reference › Behavior › Controllers](/reference/behavior/controllers) |
| Custom page layouts | The definition's nested page classes | [Reference › UI › Pages](/reference/ui/pages) |

## Adding fields later

Two paths:

**Migration only.** Add a new column with a standard Rails migration. Plutonium auto-detects it — appears in all CRUD pages.

**Field with custom rendering.** Add the column, then declare it in the definition:

```ruby
# app/definitions/post_definition.rb
class PostDefinition < ResourceDefinition
  input :slug, hint: "URL-friendly identifier"
end
```

## Converting an existing model

If the model already exists, skip the model generation:

```ruby
# 1. Include the module
class Post < ApplicationRecord
  include Plutonium::Resource::Record
end
```

```bash
# 2. Scaffold the rest (skips model + migration)
rails g pu:res:scaffold Post --no-migration --dest=main_app

# 3. Connect to portal
rails g pu:res:conn Post --dest=admin_portal
```

## Resources in feature packages

```bash
rails g pu:res:scaffold Blogging::Post title:string --dest=blogging
rails g pu:res:conn Blogging::Post --dest=admin_portal
```

See [Creating packages](./creating-packages) for the package structure.

## Cross-package references

```bash
rails g pu:res:scaffold Comment user:belongs_to blogging/post:belongs_to body:text --dest=comments
```

The `blogging/post` syntax expands to `Blogging::Post`.

## Related

- [Reference › App › Generators](/reference/app/generators) — full generator catalog
- [Reference › Resource](/reference/resource/) — model + definition + query + actions
- [Reference › App › Portals](/reference/app/portals) — `pu:res:conn` details
- [Creating packages](./creating-packages) — resources in feature packages
- [Nested resources](./nested-resources) — parent/child relationships
