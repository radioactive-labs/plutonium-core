# Controller

Plutonium controllers ship full CRUD out of the box; nearly all customization belongs elsewhere. The controller stays thin — when in doubt, push the change to the definition (UI) or the policy (auth).

## 🚨 Critical

- **Don't override CRUD actions.** Use hooks (`resource_params`, `redirect_url_after_submit`, presentation hooks). Overriding `create` / `update` usually breaks authorization, params filtering, or both.
- **Named custom routes only.** Always pass `as:` — without it, `resource_url_for` can't build URLs (critical for nested resources).
- **Authorization is verified after every action** — if you write a custom action, you MUST call `authorize_current!` yourself or use `skip_verify_authorize_current` / `skip_verify_authorize_current!`.
- **Cross-resource queries: use `authorized_resource_scope(OtherModel)`, not raw `where`.** Otherwise you bypass that resource's tenancy and visibility rules.

## Base classes

```ruby
# app/controllers/resource_controller.rb — installed once
class ResourceController < ApplicationController
  include Plutonium::Resource::Controller
end

# app/controllers/posts_controller.rb — per resource, generated
class PostsController < ::ResourceController
  # Empty — all CRUD inherited
end
```

Portal-specific overrides:

```ruby
# packages/admin_portal/app/controllers/admin_portal/resource_controller.rb
module AdminPortal
  class ResourceController < ::ResourceController
    include AdminPortal::Concerns::Controller
  end
end

# packages/admin_portal/app/controllers/admin_portal/posts_controller.rb
class AdminPortal::PostsController < ResourceController
  # Portal-specific customizations
end
```

## What you get for free

| Action | Method | Path | Purpose |
|---|---|---|---|
| `index` | GET | `/posts` | List with pagination, search, filters, sorting |
| `show` | GET | `/posts/:id` | Display a single record |
| `new` | GET | `/posts/new` | Form |
| `create` | POST | `/posts` | Create |
| `edit` | GET | `/posts/:id/edit` | Form |
| `update` | PATCH/PUT | `/posts/:id` | Update |
| `destroy` | DELETE | `/posts/:id` | Delete |

Plus interactive-action routes for every action declared in the definition (`/posts/:id/record_actions/publish`, etc.).

## Where customization belongs

| Concern | Lives in |
|---|---|
| Field rendering (inputs, displays, columns) | [Definition](/reference/resource/definition) |
| Search, filters, scopes, sorting | [Query](/reference/resource/query) |
| Custom operations (publish, archive, import) | [Interaction](./interactions) + action on definition |
| Authorization rules | [Policy](./policies) |
| Form / show / page chrome | Definition (custom page classes — see [UI › Pages](/reference/ui/pages)) |
| **Custom redirect logic** | **[Controller hook](#redirect-hooks)** |
| **Param munging** | **[Controller hook](#parameter-hook)** |
| **Custom index query shape** | **[Controller hook](#index-query-hook)** |
| **Presentation of parent/entity fields** | **[Controller hook](#presentation-hooks)** |

## Override hooks

All hooks are private methods. Override only the ones you need.

### Redirect hooks

```ruby
class PostsController < ::ResourceController
  private

  # Where to go after create/update: "show" (default), "edit", "new", "index"
  def preferred_action_after_submit = "edit"

  # Custom URL after create/update (overrides preferred_action_after_submit)
  def redirect_url_after_submit = posts_path

  # Custom URL after destroy
  def redirect_url_after_destroy = posts_path
end
```

### Parameter hook

```ruby
def resource_params
  params = super
  params[:tags] = params[:tags].split(",") if params[:tags].is_a?(String)
  params
end
```

### Index query hook

```ruby
def filtered_resource_collection
  base = current_authorized_scope
  base = base.featured if params[:featured]
  current_query_object.apply(base, raw_resource_query_params)
end
```

### Presentation hooks

Control whether parent / scoped-entity fields appear in forms and displays. Defaults are `false` (hidden, since they're inferred from the URL/portal).

```ruby
def present_parent?         = true   # show parent field on displays
def submit_parent?          = true   # include in forms (defaults to tracking present_parent?)
def present_scoped_entity?  = true
def submit_scoped_entity?   = true
```

Conditional pattern — show parent only when accessed standalone:

```ruby
def present_parent?
  current_parent.nil?
end
```

## Lifecycle callbacks

Standard Rails callbacks work:

```ruby
class PostsController < ::ResourceController
  before_action :check_quota, only: [:create]

  private

  def check_quota
    if current_user.posts.count >= 100
      redirect_to resource_url_for(resource_class), alert: "Post limit reached"
    end
  end
end
```

## Custom actions

Prefer **interactive actions** (definition + interaction — see [Resource › Actions](/reference/resource/actions)) for anything with business logic. The only reasons to hand-write a controller action: unusual response shapes, external service callbacks, etc.

```ruby
class PostsController < ::ResourceController
  def publish
    authorize_current!(resource_record!, to: :publish?)
    resource_record!.update!(published: true)
    redirect_to resource_url_for(resource_record!), notice: "Published!"
  end
end
```

Route must be named:

```ruby
register_resource Post do
  member { post :publish, as: :publish }   # ← `as:` required
end
```

::: warning Always name custom routes
Without `as:`, `resource_url_for` can't build the URL — particularly critical for nested resources.
:::

## Key methods

### Resource access

```ruby
resource_class            # The model class
resource_record!          # Current record (raises RecordNotFound if not found)
resource_record?          # Current record (nil if not found)
resource_params           # Permitted params for create/update
current_parent            # Parent record for nested routes
current_scoped_entity     # Tenant entity for the current portal (nil if not scoped)
```

### Authorization

**Current resource:**

```ruby
authorize_current!(record, to: :action?)   # check permission, raises if denied
current_policy                              # Policy instance for current resource
permitted_attributes                        # Allowed attributes for the current action
current_authorized_scope                    # Scoped collection the user can access
```

**Other resources** — cross-resource auth. Use these, NOT raw `where` / `find`:

```ruby
authorize! other_record, to: :show?         # ActionPolicy — raises if denied
allowed_to?(:show?, other_record)           # Boolean check
policy_for(OtherModel)                      # Policy instance for class or record
policy_for(other_record).show?

authorized_resource_scope(OtherModel)                            # Scope on the model class
authorized_resource_scope(OtherModel, relation: OtherModel.published)  # On a relation
authorized_resource_scope(OtherModel, type: :create)             # Different action
```

`authorized_resource_scope` applies the *other* resource's `relation_scope` AND the current policy context (entity scope, etc.). **Always prefer it over `OtherModel.all` / raw `where`** in cross-resource controller code — otherwise you bypass that resource's tenancy and visibility rules.

### Definition access

```ruby
current_definition
```

### UI builders (rarely needed in controllers)

```ruby
build_form
build_detail
build_collection
```

### URL generation

```ruby
resource_url_for(@post)                          # show URL
resource_url_for(@post, action: :edit)
resource_url_for(Post)                           # index URL
resource_url_for(Post, action: :new)

# Nested
resource_url_for(@comment, parent: @post)
resource_url_for(Comment, action: :new, parent: @post)

# Cross-package
resource_url_for(@post, package: AdminPortal)

# Interactive actions
resource_url_for(@post, interaction: :publish)
resource_url_for(Post, interaction: :import)
resource_url_for(Post, interaction: :archive, ids: [1, 2, 3])
resource_url_for(@post, parent: @user, interaction: :publish)
```

## Nested resources

Routes prefixed `nested_` automatically resolve the parent. See [Tenancy › Nested resources](/reference/tenancy/nested-resources) for the full surface; the controller-side methods:

```ruby
current_parent              # parent record
current_nested_association  # :posts
parent_route_param          # :user_id
parent_input_param          # :user
```

Parent fields are excluded from forms/displays by default. Toggle with the [presentation hooks](#presentation-hooks).

Custom parent resolution:

```ruby
def current_parent
  @current_parent ||= Company.friendly.find(params[:company_id])
end
```

## Entity scoping (multi-tenancy)

When a portal calls `scope_to_entity Organization, strategy: :path`, controllers in that portal automatically:

- Scope queries to the entity
- Exclude the entity field from forms (detected by association class)
- Inject the entity on create/update
- Expose `current_scoped_entity`

Plutonium auto-detects which `belongs_to` association points to the scoped class, even when `param_key` differs from the association name:

```ruby
# Portal config
scope_to_entity Competition::Team, param_key: :team

# Model — association name differs from param_key, but Plutonium finds by class
class Match < ApplicationRecord
  belongs_to :competition_team
end
```

### Multiple associations to the same class

If a model has two associations pointing at the scoped entity class, Plutonium raises:

```
Match has multiple associations to Competition::Team: home_team, away_team.
Plutonium cannot auto-detect which one to use for entity scoping.
Override `scoped_entity_association` in your controller to specify the association.
```

Override:

```ruby
class MatchesController < ::ResourceController
  private
  def scoped_entity_association = :home_team
end
```

Full mechanics in [Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

## Authorization verification

After-action callbacks ensure authorization happened:

```ruby
verify_authorize_current         # all actions — `authorize_current!` must have been called
verify_current_authorized_scope  # all except :new and :create — scope must have been loaded
```

Skip only when handling auth manually. Two forms:

```ruby
# Class-level — across multiple actions
class PostsController < ::ResourceController
  skip_verify_authorize_current only: [:preview]
  skip_verify_current_authorized_scope only: [:preview]

  def preview
    # auth handled manually
  end
end

# Per-action — bang methods, inside the action body
def preview
  skip_verify_authorize_current!
  skip_verify_current_authorized_scope!
  # auth handled manually
end
```

Prefer the per-action bang form when only one action skips — keeps the exception co-located with the code that needs it.

## Response formats

Controllers respond to:

- HTML (default)
- JSON (via RABL templates)
- Turbo Stream (for Hotwire)

## Error handling

```ruby
class PostsController < ::ResourceController
  rescue_from ActiveRecord::RecordNotFound do
    redirect_to resource_url_for(resource_class), alert: "Post not found"
  end

  rescue_from ActionPolicy::Unauthorized do
    redirect_to resource_url_for(resource_class), alert: "Not authorized"
  end
end
```

## Specifying resource class

The resource class is inferred from the controller name. Override if needed:

```ruby
class LegacyPostsController < ::ResourceController
  controller_for Post
end
```

## Portal-specific controllers

Each portal can override:

```ruby
class AdminPortal::PostsController < ResourceController
  private
  def preferred_action_after_submit = "index"
end
```

See [App › Portals](/reference/app/portals) for the full portal controller story.

## Related

- [Policies](./policies) — authorization called from controllers
- [Interactions](./interactions) — business logic for custom actions
- [Resource › Definition](/reference/resource/definition) — UI config (where most "controller-like" tweaks belong)
- [Resource › Actions](/reference/resource/actions) — registering interactive actions
- [Tenancy › Nested resources](/reference/tenancy/nested-resources) — parent/child routing
