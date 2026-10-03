# Portals

A portal is a Rails engine mixing in `Plutonium::Portal::Engine`. It defines its own routes, controller concern, and (optionally) entity scoping.

## 🚨 Critical

- **Use `pu:pkg:portal` for everything.** Never hand-write the engine file, controller concern, or layout.
- **Pass `--auth=<name>`, `--public`, or `--byo`** for unattended runs; without one of these flags, the generator prompts.
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
| `--public` | Public access, no authentication |
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

Every portal has a `Concerns::Controller`, included by both its `ResourceController` (resource pages) and its `PlutoniumController` (dashboard and other non-resource pages). The generator wires this up; you customize for auth flow and shared before_action hooks.

Portal-wide helpers the layout calls belong here, declared with `helper_method`, so they work on the dashboard as well as resource pages. The common case is `profile_url`: `Plutonium::Auth::Rodauth` defines it as `nil`, and the avatar menu only shows a Profile link when it returns a URL. `pu:profile:conn --dest=<portal>` writes the override into this concern (see [Auth › Profile](/reference/auth/profile)).

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

`pu:pkg:portal` writes the mount at the bottom of the portal's own `packages/<name>_portal/config/routes.rb`, at `/<name>`, wrapped in an auth constraint when `--auth` is given:

```ruby
# packages/admin_portal/config/routes.rb (after the engine's routes.draw block)
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:user) do
    mount AdminPortal::Engine, at: "/admin"
  end
end
```

With `--public` or `--byo` the mount is unconstrained and the portal handles its own auth.

To change the path, edit `at:` in place. Don't mount the engine again in `config/routes.rb`: the second `mount` reuses the route name (`admin_portal`) and Rails raises `ArgumentError: Invalid route name, already in use`.

Route order matters: the app's `config/routes.rb` is drawn first, then each package's routes file, then gem engines (Active Storage, Turbo).

### Mounting a portal at `/`

Two things change when a portal is mounted at `"/"`.

**Drop the `Rodauth::Rails.authenticate` constraint and authenticate in the controller concern instead.** The constraint does not fail the match for an anonymous visitor; it calls `rodauth.require_account`, which redirects to login. A constrained mount at `/` matches every path the app's own routes did not claim, so it redirects anonymous requests meant for routes drawn after it (other portals, Active Storage) and turns unknown URLs into login redirects.

```ruby
# packages/desk_portal/config/routes.rb
Rails.application.routes.draw do
  mount DeskPortal::Engine, at: "/"
end

# packages/desk_portal/app/controllers/desk_portal/concerns/controller.rb
module DeskPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:user)

      included do
        before_action { rodauth.require_account }
      end
    end
  end
end
```

**Move the engine's root off `/` but keep the name.** The app's `root` is drawn first, so the generated `root to: "dashboard#index"` is unreachable and the portal's `root_path` points at the app's home page. Plutonium's header, icon rail, breadcrumbs and wizard exits all link to `root_path`, so the portal still needs a route named `root`:

```ruby
DeskPortal::Engine.routes.draw do
  get "dashboard", to: "dashboard#index", as: :root
  register_resource ::Comment
  # register resources above.
end
```

The same applies to `register_dashboard ..., at: "/"`. Confirm with `Rails.application.routes.recognize_path("/")` (still the app's home) and `recognize_path("/dashboard")`.

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

You list every resource the portal exposes. If a resource isn't registered, it has no URLs in that portal, so `resource_url_for` will fail.

### Choosing nested associations

Name the associations that get nested routes, and the rest are not drawn:

```ruby
register_resource ::Post, associations: %i[comments post_detail]
```

`associations: []` draws none, and a name that is not a routable association fails the boot. Set `config.nested_association_routes = :declared` to make naming them the rule; see [Tenancy › Nested resources](../tenancy/nested-resources#declaring-which-associations-get-routes).

### Singular (singleton) resources

For resources with no collection: a single per-user `Profile`, app-wide `Settings`, etc.:

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
Without `as:`, `resource_url_for(@post, action: :preview)` fails because there's no named route, which is especially critical for nested resources.
:::

For most operations with business logic, prefer **interactive actions** (definition + interaction; see [Resource › Actions](/reference/resource/actions)) over custom controller routes. Action routes wire automatically with no `register_resource` block needed.

## Connecting resources: `pu:res:conn`

A resource is invisible until connected to at least one portal. The generator wires up the portal-specific controller, policy, definition, and route registration.

```bash
rails g pu:res:conn RESOURCE [RESOURCE...] --dest=PORTAL_NAME [--singular]
```

Pass resources directly to avoid interactive prompts. No `--src` needed.

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
# Definition: how fields render per portal
class AdminPortal::PostDefinition < ::PostDefinition
  scope :pending_review
  input :internal_notes, hint: "Not shown to the author"
end

# Policy: which fields exist, and who may act
#          `internal_notes` appears for admins because THIS permits it,
#          not because the definition above mentions it.
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  def destroy? = true
  def permitted_attributes_for_create = %i[title content featured internal_notes]
end

# Controller: different redirect after submit
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

Strategies: `:path` (entity id in URL, the default) or a custom method name on the portal controller concern.

For the full multi-tenancy story, see [Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

## Dashboard / non-resource pages

The generated `dashboard#index` is a plain page listing the registered resources. To replace it with a [dashboard](/guides/dashboards) of metric and chart cards, run `rails g pu:dashboard Home --dest=<portal> --at=/`, which swaps the `root to:` line for a `register_dashboard ... at: "/"` registration.

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"
  get "settings", to: "settings#index"
end

# Controller: inherit from PlutoniumController, NOT ResourceController
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
# Admin: full access, entity-scoped
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end

# Customer dashboard: entity-scoped to the customer's organization
module DashboardPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end

# Public: no auth, no entity scoping
module PublicPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
  end
end
```

## Related

- [Packages](./packages): feature vs portal split, structure, namespacing
- [Generators](./generators): full `pu:pkg:portal` / `pu:res:conn` option reference
- [Behavior › Controllers](/reference/behavior/controllers): controller key methods, hooks, customizations
- [Tenancy › Entity scoping](/reference/tenancy/entity-scoping): multi-tenancy mechanics
- [Auth](/reference/auth/): Rodauth account types referenced by `--auth=`
- [UI › Layouts](/reference/ui/layouts): customizing portal chrome
