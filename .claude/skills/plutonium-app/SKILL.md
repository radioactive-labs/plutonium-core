---
name: plutonium-app
description: Use BEFORE installing Plutonium, creating a portal or feature package, mounting an engine, or registering resources/routes. Covers initial setup, the package system, portal engines, route registration (including singular and custom routes), and resource-to-portal wiring.
---

# Plutonium App — Installation, Packages, Portals, Routes

How a Plutonium app is assembled: the install bootstrap, the package system (feature vs portal), portal engines, and the routing surface that exposes resources to the web.

For the resources themselves (model + definition + scaffold options), see [[plutonium-resource]]. For controllers/policies/interactions, see [[plutonium-behavior]]. For multi-tenancy, see [[plutonium-tenancy]].

## 🚨 Critical (read first)

- **Use the generators for everything.** `pu:core:install`, `pu:rodauth:install`, `pu:pkg:portal`, `pu:pkg:package`, `pu:res:scaffold`, `pu:res:conn`. Never hand-write base controllers, engine files, layouts, or portal route registration.
- **Existing app → `base.rb`. New app → `plutonium.rb`.** The `plutonium.rb` template re-runs full bootstrap (dotenv, annotate, solid_*, asset config) and creates generic "initial commit" commits that clobber history. For any pre-existing app use `base.rb`.
- **Pass `--dest`, `--auth`, `--force`, `--skip-bundle`** etc. for unattended runs so generators don't block on prompts.
- **Feature vs portal is a hard split.** Feature packages hold models/policies/definitions/interactions. Portal packages hold controllers/views/routes/auth. Don't mix.
- **Package classes are auto-namespaced** — `packages/blogging/app/models/blogging/post.rb` → `Blogging::Post`. Don't fight it.
- **Always connect resources with `pu:res:conn`** — until connected, a resource has no portal routes and is invisible.
- **For custom routes on a registered resource, pass `as:`** — otherwise `resource_url_for` can't build URLs.

---

## 🛑 Before you install or scaffold structure: confirm the shape (ASK — don't infer)

"Set up Plutonium" / "make an admin area" / "create a billing package" each hide a high-blast-radius decision. Get one wrong and you **clobber a year of git history**, build the wrong kind of package, or ship a portal nobody can log into. Resolve each — confirming by inspection (next section), not assumption:

1. **Fresh app or existing one?** Existing ⇒ `bundle add plutonium` + `pu:core:install` (the `base.rb` path). **NEVER the `plutonium.rb` fresh-app template on an existing app** — it re-bootstraps (dotenv/annotate/solid_*/assets) and drops "initial commit" commits that clobber history. This is the single most dangerous mistake in this skill — confirm it's greenfield *before* reaching for `plutonium.rb`.
2. **Feature package or portal package?** Business logic (models/policies/definitions/interactions) ⇒ `pu:pkg:package` (feature, no UI). A web surface (controllers/views/routes/auth) ⇒ `pu:pkg:portal`. Hard split — "billing" is a *feature*; "admin area" is a *portal*. A feature package is invisible until its resources are `pu:res:conn`'d into a portal.
3. **Auth per portal.** `--auth=<account>` / `--public` / `--byo` / `--scope=<Entity>` (multi-tenant). Unguessable from "admin area" — decide, don't default silently.
4. **Don't stop half-wired.** A resource reaches the browser only after: scaffold → migrate → `pu:res:conn --dest=portal` → portal engine `mount`ed in `config/routes.rb` → registered (conn does the last). Name the whole chain before you start.

**Never ship a guessed schema, portal name, or auth flag as applied commands** — read them off the app first; fall back to `AskUserQuestion` only for genuine product choices (separate staff accounts vs shared, which payment backend). The decisions compound: *existing app ⇒ base.rb path*; *feature package ⇒ needs a portal to be visible*; *new portal ⇒ pick auth + mount it*.

## ✅ Before you run a generator: verify the ground truth (CHECK — read it, don't ask for it)

You have file access — **inspect**; don't ask the user to describe their app.

| Check | How | Why it matters |
|---|---|---|
| Greenfield vs existing | `git log --oneline \| head`; is there a populated `Gemfile`/`app/`? | An existing app must use the `base.rb` path — **never** `plutonium.rb` |
| Plutonium already installed | grep `Gemfile` for `plutonium`; `ls config/packages.rb app/controllers/resource_controller.rb` | Avoid re-installing / double bootstrap |
| Package/portal already exists | `ls packages/<name>` | Don't duplicate — connect to / extend the existing one |
| Existing auth | grep `Gemfile`/`app/models` for `rodauth`/`devise`/`has_secure_password` | Drives `--auth` vs `--byo` |
| Portal engine mounted | grep `config/routes.rb` for `mount <Portal>::Engine` | An unmounted portal 404s |
| Resource registered | grep the portal's `config/routes.rb` for `register_resource ::<X>` | Unregistered ⇒ no URLs (`resource_url_for` fails) |
| Migrations applied | `rails db:migrate:status` before `pu:res:conn` | `conn` seeds the policy from columns |

Inspect with your own tools **before** running any generator.

## 🛠 Use the generator — pick the right install path

Never hand-write base controllers, engine files, layouts, or route registration. Pass `--dest`/`--auth`/`--force`/`--skip-bundle` for unattended runs.

| Task | Generator | Verify first |
|---|---|---|
| Install — **existing** app | `bundle add plutonium` + `pu:core:install` | It's an existing app (use `base.rb`, **not** `plutonium.rb`) |
| Install — **fresh** app | `rails new … -m …/plutonium.rb` | Brand-new app **only** |
| Feature package | `pu:pkg:package <name>` | Not already present |
| Portal package | `pu:pkg:portal <name> --auth=…/--public/--byo/--scope=…` | Auth strategy decided; then `mount` the engine by hand |
| Connect a resource | `pu:res:conn <Res> --dest=portal` | Migrated; target portal exists |

---

# Part 1 — Installation

## Fresh Rails app (recommended)

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

Configures Rails + Propshaft + esbuild + TailwindCSS + Plutonium in one shot.

## Existing Rails app

⚠️ Use `base.rb`, **not** `plutonium.rb`.

```bash
# Option 1 — template
bin/rails app:template \
  LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb

# Option 2 — manual
# Add `gem "plutonium"` to Gemfile, then:
bundle install
rails generate pu:core:install
```

## Full setup workflow

```bash
# 1. Core install (base controllers/policies/definitions/layouts)
rails generate pu:core:install

# 2. Auth (if needed)
rails generate pu:rodauth:install
rails generate pu:rodauth:account user

# 3. Portal
rails generate pu:pkg:portal admin --auth=user

# 4. First resource
rails generate pu:res:scaffold Post user:belongs_to title:string 'content:text?' --dest=main_app
rails db:prepare

# 5. Connect resource to portal
rails generate pu:res:conn Post --dest=admin_portal

# 6. Mount portal in config/routes.rb
#    mount AdminPortal::Engine, at: "/admin"

# 7. Start
rails server
```

## What `pu:core:install` creates

```
app/
├── controllers/
│   ├── plutonium_controller.rb       # non-resource base
│   └── resource_controller.rb        # CRUD base — see plutonium-behavior
├── definitions/resource_definition.rb
├── interactions/resource_interaction.rb
├── models/resource_record.rb         # abstract model — includes Plutonium::Resource::Record
├── policies/resource_policy.rb
└── views/layouts/resource.html.erb

config/
├── initializers/plutonium.rb
└── packages.rb                       # auto-loads packages/**/lib/engine.rb

packages/.keep
```

The base classes (`ResourceController`, `ResourcePolicy`, `ResourceDefinition`, `ResourceRecord`, `ResourceInteraction`) are where you put app-wide defaults; resource-specific subclasses come from `pu:res:scaffold`.

## Converting an existing model to a resource

```ruby
# 1. Include the module on your model
class Post < ApplicationRecord
  include Plutonium::Resource::Record
end
```

```bash
# 2. Generate supporting files (skips model + migration)
rails g pu:res:scaffold Post --no-migration --dest=main_app

# 3. Connect to portal
rails g pu:res:conn Post --dest=admin_portal
```

## Configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  # Page chrome. Default :modern (topbar + icon rail).
  # :classic preserves the legacy header + sidebar (only when upgrading).
  # config.shell = :classic

  # Custom assets
  # config.assets.stylesheet = "custom_stylesheet"
  # config.assets.script     = "custom_script"
  # config.assets.logo       = "custom_logo.png"
end
```

---

# Part 2 — The Package System

Two kinds, hard split:

| Type | Purpose | Generator | Examples |
|---|---|---|---|
| **Feature** | Business logic (models, policies, definitions, interactions, migrations) | `pu:pkg:package NAME` | `blogging`, `billing`, `inventory` |
| **Portal** | Web interface (controllers, views, routes, auth) | `pu:pkg:portal NAME` | `admin_portal`, `customer_portal`, `public_portal` |

## Feature packages

```bash
rails g pu:pkg:package blogging
```

Structure:

```
packages/blogging/
├── app/
│   ├── models/blogging/                 # Blogging::Post
│   ├── definitions/blogging/            # Blogging::PostDefinition
│   ├── policies/blogging/               # Blogging::PostPolicy
│   └── interactions/blogging/           # Blogging::PublishPostInteraction
├── db/migrate/
└── lib/engine.rb
```

Engine:

```ruby
module Blogging
  class Engine < Rails::Engine
    include Plutonium::Package::Engine
  end
end
```

Auto-namespacing: every file under `app/<kind>/blogging/` resolves to `Blogging::*`.

### Creating resources in a feature package

```bash
rails g pu:res:scaffold Blogging::Post title:string --dest=blogging
```

`--dest=<package_name>` puts model/migration in the package. Cross-package references use the full namespace:

```bash
rails g pu:res:scaffold Comment user:belongs_to blogging/post:belongs_to body:text --dest=comments
```

## Portal packages

```bash
rails g pu:pkg:portal admin
```

Structure:

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

See Part 3 for engine configuration and Part 5 for resource connection.

## Package loading

`config/packages.rb` (created by `pu:core:install`):

```ruby
Dir.glob(File.expand_path("../packages/**/lib/engine.rb", __dir__)) do |package|
  load package
end
```

This is loaded from `config/application.rb`. Migrations from all packages are picked up by `rails db:migrate` automatically.

## When to use which

**Feature packages** — domain logic that:
- Could be reused across multiple portals (admin and customer both edit `Blogging::Post`)
- Has no inherent UI / auth (it's just behavior)
- You want to keep isolated from other domains (`billing` should not depend on `blogging`)

**Portal packages** — user-facing surfaces that:
- Have a specific auth flow (admin vs customer vs public)
- Render different views of the same underlying resources
- Need different policies / definitions per audience

---

# Part 3 — Portal Engines

A portal is a Rails engine mixing in `Plutonium::Portal::Engine`. It defines its own routes, controller concern, and (optionally) entity scoping.

## Generator

```bash
rails g pu:pkg:portal <name>
```

### Options

| Option | Description |
|---|---|
| `--auth=NAME` | Rodauth account to use (e.g. `--auth=user`) |
| `--public` | Public access — no auth |
| `--byo` | Bring your own auth |
| `--scope=CLASS` | Entity class for multi-tenancy (e.g. `--scope=Organization`) |

```bash
rails g pu:pkg:portal admin     --auth=admin
rails g pu:pkg:portal api       --public
rails g pu:pkg:portal custom    --byo
rails g pu:pkg:portal admin     --auth=admin --scope=Organization
```

Without flags, the generator prompts interactively.

## Engine file

```ruby
# packages/admin_portal/lib/engine.rb
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      # Optional: multi-tenancy. See plutonium-tenancy for strategies.
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

## Controller concern (auth)

Every portal has a `Concerns::Controller` mixed into its `ResourceController`. The generator wires this up; you customize it for auth / before_action hooks.

### Rodauth

```ruby
module AdminPortal::Concerns::Controller
  extend ActiveSupport::Concern
  include Plutonium::Portal::Controller
  include Plutonium::Auth::Rodauth(:user)
end
```

### Public access

```ruby
module AdminPortal::Concerns::Controller
  extend ActiveSupport::Concern
  include Plutonium::Portal::Controller
  include Plutonium::Auth::Public
end
```

### BYO auth

```ruby
module AdminPortal::Concerns::Controller
  extend ActiveSupport::Concern
  include Plutonium::Portal::Controller
  include Plutonium::Auth::Public        # disables Rodauth requirement

  def current_user
    @current_user ||= User.find_by(api_key: request.headers["X-API-Key"])
  end
end
```

## Mounting

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Authenticated mount
  constraints Rodauth::Rails.authenticate(:user) do
    mount AdminPortal::Engine, at: "/admin"
  end

  # Unconstrained (portal handles its own auth)
  mount PublicPortal::Engine, at: "/public"
end
```

## Controller hierarchy

Portal controllers inherit from the feature-package controller if one exists, OR from the portal's `ResourceController` otherwise.

```ruby
# Feature controller exists → inherit from it AND include portal concern
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller
end

# No feature controller → inherit from portal's ResourceController
class AdminPortal::PostsController < AdminPortal::ResourceController
end
```

For non-resource portal pages (dashboard, settings):

```ruby
module AdminPortal
  class DashboardController < PlutoniumController
    def index; end
  end
end
```

## Per-portal overrides

```ruby
# Definition
class AdminPortal::PostDefinition < ::PostDefinition
  input :internal_notes, as: :text     # admins see this; customers don't
  scope :pending_review
end

# Policy
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy
  def destroy? = true
  def permitted_attributes_for_create = %i[title content featured internal_notes]
end

# Controller
module AdminPortal
  class PostsController < ResourceController
    private
    def preferred_action_after_submit = "index"
  end
end
```

---

# Part 4 — Routes & `register_resource`

Portal routes live in `packages/<name>_portal/config/routes.rb`:

```ruby
AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"

  register_resource ::Post
  register_resource Blogging::Comment

  # Non-resource pages
  get "settings", to: "settings#index"
end
```

## `register_resource` — what it does

For each call, Plutonium auto-generates:

- Top-level CRUD routes (`/posts`, `/posts/:id`, etc.)
- Nested routes for every registered `has_many` / `has_one` parent (prefixed `nested_`)
- Route names that `resource_url_for` can resolve

You list every resource the portal exposes. If a resource isn't registered, it has no URLs in that portal — `resource_url_for` will fail.

## Singular (singleton) resources

For resources with no collection — a single per-user `Profile`, app-wide `Settings`, etc.:

```ruby
register_resource ::Profile, singular: true
```

Generates singular routes (no `:id`, no index):

- `GET /profile`           → show
- `GET /profile/new`       → new
- `GET /profile/edit`      → edit
- `POST /profile`          → create
- `PATCH /profile`         → update
- `DELETE /profile`        → destroy

Use the `--singular` flag on `pu:res:conn`:

```bash
rails g pu:res:conn Profile --dest=customer_portal --singular
```

## Custom member / collection routes

```ruby
register_resource ::Post do
  member do
    get  :preview,    as: :preview
    get  :analytics,  as: :analytics
    post :publish,    as: :publish
  end
  collection do
    get  :archived,       as: :archived
    post :bulk_publish,   as: :bulk_publish
  end
end
```

**Always pass `as:`.** Without it, `resource_url_for(@post, action: :preview)` fails because there's no named route to look up — especially critical for nested resources.

For most operations with business logic, prefer **interactive actions** (definition + interaction — see [[plutonium-resource]] › Actions) over custom controller routes. The action routes are wired automatically with no `register_resource` block needed.

## Cross-package and nested URLs

See [[plutonium-behavior]] for full `resource_url_for` signature and [[plutonium-tenancy]] for nested routing semantics.

---

# Part 5 — Connecting Resources to Portals (`pu:res:conn`)

A resource is invisible until connected to at least one portal. The generator wires up the portal-specific controller, policy, definition, and route registration.

## Command syntax

```bash
rails g pu:res:conn RESOURCE [RESOURCE...] --dest=PORTAL_NAME [--singular]
```

Pass resources directly — avoids interactive prompts. No `--src` needed.

## Usage

```bash
# Main app resources
rails g pu:res:conn Post Comment Tag --dest=admin_portal

# Namespaced (from a feature package)
rails g pu:res:conn Blogging::Post Blogging::Comment --dest=admin_portal

# Singular (profile, settings, dashboard)
rails g pu:res:conn Profile --dest=customer_portal --singular
```

**Run after migrations** — the generator reads model columns to seed the policy's `permitted_attributes_for_*`.

## What gets generated

For `Post` connected to `admin_portal`:

```
packages/admin_portal/app/
├── controllers/admin_portal/posts_controller.rb
├── policies/admin_portal/post_policy.rb
└── definitions/admin_portal/post_definition.rb
```

Plus route registration appended to `packages/admin_portal/config/routes.rb`:

```ruby
register_resource ::Post
register_resource ::Profile, singular: true   # if --singular
```

Re-running `pu:res:conn` for the same resource is **idempotent** — already-registered entries report `identical` and are not duplicated. Insertion falls back gracefully when the conventional `# register resources above` marker is missing (uses the `routes.draw do` opening), and warns clearly if it can't find any anchor.

### Generated controller

```ruby
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller
end
```

### Generated policy (seeded from model columns)

```ruby
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  def permitted_attributes_for_create
    [:title, :content, :user_id]
  end

  def permitted_attributes_for_read
    [:title, :content, :user_id, :created_at, :updated_at]
  end

  def permitted_associations
    %i[]
  end
end
```

Review and trim — the generator is liberal. Especially: drop `_id` fields when the form uses the association name, and add `:price` (not `:price_cents`) for `has_cents` fields.

---

## Generator reference

| Generator | Purpose |
|---|---|
| `pu:core:install` | Initial Plutonium setup (base classes, config, layouts) |
| `pu:rodauth:install` | Set up Rodauth auth |
| `pu:rodauth:account NAME` | Create user account type |
| `pu:rodauth:admin NAME` | Admin account with 2FA, lockout, audit |
| `pu:saas:setup` | User + entity + membership in one shot |
| `pu:saas:user NAME` | SaaS user account |
| `pu:saas:entity NAME` | Entity model |
| `pu:saas:membership` | Membership join table |
| `pu:pkg:package NAME` | Feature package |
| `pu:pkg:portal NAME` | Portal package |
| `pu:res:scaffold NAME` | Resource (model, migration, controller, policy, definition) |
| `pu:res:conn NAME` | Connect resource to portal |
| `pu:invites:install` | Invite system (see [[plutonium-tenancy]]) |
| `pu:invites:invitable NAME` | Mark a model as invitable |
| `pu:eject:layout` | Eject layouts for customization |
| `pu:eject:shell` | Eject topbar/sidebar partials |
| `pu:core:update` | Update plutonium gem + npm |
| `pu:skills:sync` | Sync Claude Code skills to project |

---

## Related skills

- [[plutonium-resource]] — what a resource IS (model + definition + scaffold options)
- [[plutonium-behavior]] — controllers, policies, interactions
- [[plutonium-tenancy]] — entity scoping, nested resources, invites
- [[plutonium-auth]] — Rodauth account configuration
- [[plutonium-ui]] — layouts, page classes, custom Phlex components, assets
- [[plutonium-testing]] — testing portals, packages, controllers
