# Portals

A portal is a Rails engine mixing in `Plutonium::Portal::Engine`. It defines its own routes, controller concern, and (optionally) entity scoping.

## 🚨 Critical

- **Use `pu:pkg:portal` for everything.** Never hand-write the engine file, controller concern, or layout.
- **Pass `--auth=<name>`, `--public`, or `--byo`** for unattended runs — without one of these flags, the generator prompts.
- **Always connect resources with `pu:res:conn`.** Until connected, a resource has no portal routes and is invisible.
- **For custom routes on a registered resource, pass `as:`.** Without it, `resource_url_for` can't build URLs.

## Creating a portal

```bash
rails g pu:pkg:portal <name>
```

### Options

| Option | Description |
|---|---|
| `--auth=NAME` | Rodauth account to authenticate with (e.g. `--auth=user`) |
| `--public` | Public access — no authentication |
| `--byo` | Bring your own authentication |
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
      # Optional: multi-tenancy. See Tenancy › Entity scoping for strategies.
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

## Controller concern (auth)

Every portal has a `Concerns::Controller` mixed into its `ResourceController`. The generator wires this up; you customize for auth flow and shared before_action hooks.

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
  include Plutonium::Auth::Public     # disables the Rodauth requirement

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

  # Unconstrained — the portal handles its own auth
  mount PublicPortal::Engine, at: "/public"
end
```

## Routes & `register_resource`

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

### What `register_resource` does

For each call, Plutonium auto-generates:

- Top-level CRUD routes (`/posts`, `/posts/:id`, etc.)
- Nested routes for every registered `has_many` / `has_one` parent (prefixed `nested_`)
- Route names that `resource_url_for` can resolve

You list every resource the portal exposes. If a resource isn't registered, it has no URLs in that portal — `resource_url_for` will fail.

### Singular (singleton) resources

For resources with no collection — a single per-user `Profile`, app-wide `Settings`, etc.:

```ruby
register_resource ::Profile, singular: true
```

Generates singular routes (no `:id`, no index):

- `GET /profile` → show
- `GET /profile/new` → new
- `GET /profile/edit` → edit
- `POST /profile` → create
- `PATCH /profile` → update
- `DELETE /profile` → destroy

Use the `--singular` flag on `pu:res:conn`:

```bash
rails g pu:res:conn Profile --dest=customer_portal --singular
```

### Custom member / collection routes

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

::: warning Always pass `as:`
Without `as:`, `resource_url_for(@post, action: :preview)` fails because there's no named route — especially critical for nested resources.
:::

For most operations with business logic, prefer **interactive actions** (definition + interaction — see [Resource › Actions](/reference/resource/actions)) over custom controller routes. Action routes wire automatically with no `register_resource` block needed.

## Connecting resources — `pu:res:conn`

A resource is invisible until connected to at least one portal. The generator wires up the portal-specific controller, policy, definition, and route registration.

```bash
rails g pu:res:conn RESOURCE [RESOURCE...] --dest=PORTAL_NAME [--singular]
```

Pass resources directly — avoids interactive prompts. No `--src` needed.

```bash
# Main app resources
rails g pu:res:conn Post Comment Tag --dest=admin_portal

# Namespaced (from a feature package)
rails g pu:res:conn Blogging::Post Blogging::Comment --dest=admin_portal

# Singular
rails g pu:res:conn Profile --dest=customer_portal --singular
```

::: tip Run after migrations
The generator reads model columns to seed the policy's `permitted_attributes_for_*`. Run `rails db:prepare` first.
:::

### What gets generated

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

#### Generated controller

```ruby
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller
end
```

#### Generated policy (seeded from model columns)

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

::: warning Review the generated policy
The generator is liberal. Drop `_id` fields when the form uses the association name. Add `:price` (not `:price_cents`) for `has_cents` fields. See [Behavior › Policy](/reference/behavior/policies).
:::

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
# Definition — different fields per portal
class AdminPortal::PostDefinition < ::PostDefinition
  input :internal_notes, as: :text     # admins see this; customers don't
  scope :pending_review
end

# Policy — different rules per portal
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  def destroy? = true
  def permitted_attributes_for_create = %i[title content featured internal_notes]
end

# Controller — different redirect after submit
module AdminPortal
  class PostsController < ResourceController
    private
    def preferred_action_after_submit = "index"
  end
end
```

## Entity scoping

Portals can scope ALL their resources to a parent entity automatically:

```ruby
config.after_initialize do
  scope_to_entity Organization, strategy: :path
end
```

Strategies: `:path` (entity id in URL — default) or a custom method name on the portal controller concern.

For the full multi-tenancy story, see [Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

## Dashboard / non-resource pages

```ruby
# config/routes.rb
AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"
  get "settings", to: "settings#index"
end

# Controller — inherit from PlutoniumController, NOT ResourceController
module AdminPortal
  class DashboardController < PlutoniumController
    def index
      @stats = { posts: Post.count, users: User.count }
    end
  end
end
```

See [UI › Pages](/reference/ui/pages) for custom Phlex page classes.

## Multiple portals

```ruby
# Admin — full access, entity-scoped
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end

# Customer dashboard — entity-scoped to the customer's organization
module DashboardPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end

# Public — no auth, no entity scoping
module PublicPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
  end
end
```

## Related

- [Packages](./packages) — feature vs portal split, structure, namespacing
- [Generators](./generators) — full `pu:pkg:portal` / `pu:res:conn` option reference
- [Behavior › Controllers](/reference/behavior/controllers) — controller key methods, hooks, customizations
- [Tenancy › Entity scoping](/reference/tenancy/entity-scoping) — multi-tenancy mechanics
- [Auth](/reference/auth/) — Rodauth account types referenced by `--auth=`
- [UI › Layouts](/reference/ui/layouts) — customizing portal chrome
