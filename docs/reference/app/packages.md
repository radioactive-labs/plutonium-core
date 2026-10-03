# Packages

Plutonium apps are organized into **packages**: Rails engines with stricter conventions. Two flavors, hard split:

| Type | Purpose | Generator | Examples |
|---|---|---|---|
| **Feature** | Business logic (models, policies, definitions, interactions, migrations) | `pu:pkg:package NAME` | `blogging`, `billing`, `inventory` |
| **Portal** | Web interface (controllers, views, routes, auth) | `pu:pkg:portal NAME` | `admin_portal`, `customer_portal`, `public_portal` |

## 🚨 Critical

- **Feature ↔ portal split is hard.** Feature packages hold models/policies/definitions/interactions. Portal packages hold controllers/views/routes/auth. Don't mix.
- **Package classes are auto-namespaced.** `packages/blogging/app/models/blogging/post.rb` resolves to `Blogging::Post`. Don't fight it.
- **Cross-package references use full namespace.** `rails g pu:res:conn Blogging::Post --dest=admin_portal`.
- **A resource is invisible until `pu:res:conn` registers it with a portal.**

## Feature packages

```bash
rails g pu:pkg:package blogging
```

### Structure

```
packages/blogging/
├── app/
│   ├── models/blogging/             # Blogging::Post
│   ├── definitions/blogging/        # Blogging::PostDefinition
│   ├── policies/blogging/           # Blogging::PostPolicy
│   └── interactions/blogging/       # Blogging::PublishPostInteraction
├── db/migrate/
└── lib/engine.rb
```

### Engine

```ruby
module Blogging
  class Engine < Rails::Engine
    include Plutonium::Package::Engine
  end
end
```

### Auto-namespacing

Every file under `app/<kind>/blogging/` resolves to `Blogging::*`:

- `app/models/blogging/post.rb` → `Blogging::Post`
- `app/policies/blogging/post_policy.rb` → `Blogging::PostPolicy`
- `app/definitions/blogging/post_definition.rb` → `Blogging::PostDefinition`
- `app/interactions/blogging/publish_post_interaction.rb` → `Blogging::PublishPostInteraction`

Each feature package gets its own base classes:

- `Blogging::ApplicationRecord`
- `Blogging::ResourceRecord`
- `Blogging::ResourcePolicy`
- `Blogging::ResourceDefinition`
- `Blogging::ResourceInteraction`

These inherit from the main app's base classes; extend them for package-wide defaults.

### Creating resources inside a feature package

```bash
rails g pu:res:scaffold Blogging::Post title:string --dest=blogging
```

Cross-package references use the full namespace:

```bash
rails g pu:res:scaffold Comment user:belongs_to blogging/post:belongs_to body:text --dest=comments
```

## Portal packages

```bash
rails g pu:pkg:portal admin
```

See [Portals](./portals) for full details on portal generators, engine config, and routing. Key structural points here:

```
packages/admin_portal/
├── app/
│   ├── controllers/admin_portal/
│   │   ├── concerns/controller.rb       # auth + shared filters
│   │   ├── dashboard_controller.rb
│   │   ├── plutonium_controller.rb
│   │   └── resource_controller.rb
│   ├── definitions/admin_portal/        # per-portal overrides
│   ├── policies/admin_portal/           # per-portal overrides
│   └── views/layouts/admin_portal.html.erb
├── config/routes.rb
└── lib/engine.rb
```

## Package loading

`config/packages.rb` (created by `pu:core:install`):

```ruby
Dir.glob(File.expand_path("../packages/**/lib/engine.rb", __dir__)) do |package|
  load package
end
```

This is loaded from `config/application.rb`. Migrations from all packages are picked up by `rails db:migrate` automatically.

## When to use which

**Feature packages**: domain logic that:

- Could be reused across multiple portals (admin and customer both edit `Blogging::Post`).
- Has no inherent UI / auth (it's just behavior).
- You want isolated from other domains (`billing` should not depend on `blogging`).

**Portal packages**: user-facing surfaces that:

- Have a specific auth flow (admin vs customer vs public).
- Render different views of the same underlying resources.
- Need different policies / definitions per audience.

## Typical architecture

```
packages/
├── blogging/                # Feature: blog functionality
│   └── models, definitions, policies, interactions
├── billing/                 # Feature: payments/invoicing
│   └── models, definitions, policies, interactions
├── admin_portal/            # Portal: admin interface
│   └── controllers, views, routes
└── customer_portal/         # Portal: customer dashboard
    └── controllers, views, routes
```

The portals expose the features. A single feature can be exposed by multiple portals, usually with different policies and definitions per portal.

## Related

- [Portals](./portals): portal-specific configuration (mounting, auth, route registration)
- [Generators](./generators): `pu:pkg:package` and `pu:pkg:portal` flags
- [Guide: Creating Packages](/guides/creating-packages): task-oriented walkthrough
