# Controller Reference

Complete reference for resource controllers.

## Overview

Controllers handle HTTP requests and responses. Plutonium provides a controller module with CRUD actions built-in. You rarely need to customize controllers - definitions handle UI configuration and policies handle authorization.

## Base Class

```ruby
# app/controllers/resource_controller.rb (generated during install)
class ResourceController < ApplicationController
  include Plutonium::Resource::Controller
end

# app/controllers/posts_controller.rb (generated per resource)
class PostsController < ::ResourceController
  # Empty - all CRUD actions inherited
end
```

For portals, controllers inherit from the feature package's controller and include the portal's concern:

```ruby
# packages/admin_portal/app/controllers/admin_portal/posts_controller.rb
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller

  # Portal-specific customizations
end
```

Controllers are auto-created if not defined. When accessing a portal resource controller, Plutonium dynamically creates it by inheriting from the feature package's controller.

## Built-in Actions

| Action | HTTP Method | Path | Purpose |
|--------|-------------|------|---------|
| `index` | GET | `/posts` | List with pagination, search, filters, sorting |
| `show` | GET | `/posts/:id` | Show record |
| `new` | GET | `/posts/new` | New record form |
| `create` | POST | `/posts` | Create record |
| `edit` | GET | `/posts/:id/edit` | Edit record form |
| `update` | PATCH/PUT | `/posts/:id` | Update record |
| `destroy` | DELETE | `/posts/:id` | Delete record |

Plus interactive action routes for custom operations defined in definitions.

## Key Methods

### Resource Access

```ruby
resource_class          # The model class (e.g., Post)
resource_record!        # Current record (raises RecordNotFound if not found)
resource_record?        # Current record (nil if not found)
resource_params         # Permitted params for create/update
current_parent          # Parent record for nested routes
```

### Authorization

```ruby
authorize_current!(record, to: :action?)   # Check permission
current_policy                             # Policy for current resource
permitted_attributes                       # Allowed attributes for action
current_authorized_scope                   # Scoped records user can access
authorized_resource_scope(Post)            # Authorized scope for a different resource
policy_for(record)                         # Get policy for any record
allowed_to?(:edit?, record)                # Check if action is allowed
```

### Definition Access

```ruby
current_definition      # Definition for current resource
```

### UI Building

```ruby
build_form              # Build form component
build_detail            # Build show/detail component
build_collection        # Build table component
```

### URL Generation

```ruby
resource_url_for(@post)                    # URL for record
resource_url_for(@post, action: :edit)     # Edit URL
resource_url_for(Post)                     # Index URL
resource_url_for(Post, parent: @user)      # Nested index URL
```

## Customization Hooks

All customization is done by overriding private methods.

### Redirect Hooks

```ruby
class PostsController < ::ResourceController
  private

  # Where to go after create/update: "show" (default), "edit", "new", "index"
  def preferred_action_after_submit
    "edit"
  end

  # Custom URL after create/update (overrides preferred_action_after_submit)
  def redirect_url_after_submit
    resource_url_for(resource_class)
  end

  # Custom URL after destroy
  def redirect_url_after_destroy
    resource_url_for(resource_class)
  end
end
```

### Parameter Hooks

```ruby
class PostsController < ::ResourceController
  private

  # Modify params before create/update
  def resource_params
    params = super
    params[:tags] = params[:tags].split(",") if params[:tags].is_a?(String)
    params
  end
end
```

### Query Hooks

```ruby
class PostsController < ::ResourceController
  private

  # Customize the index query
  def filtered_resource_collection
    base = current_authorized_scope
    base = base.featured if params[:featured]
    current_query_object.apply(base, raw_resource_query_params)
  end
end
```

### Presentation Hooks

Control whether parent/entity fields appear in forms and displays:

```ruby
class PostsController < ::ResourceController
  private

  # Show parent field in displays (default: false)
  def present_parent?
    true
  end

  # Include parent field in forms (default: same as present_parent?)
  def submit_parent?
    true
  end

  # Show scoped entity in displays (default: false)
  def present_scoped_entity?
    true
  end

  # Include scoped entity in forms (default: same as present_scoped_entity?)
  def submit_scoped_entity?
    true
  end
end
```

## Lifecycle Callbacks

Use standard Rails callbacks:

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

## Custom Actions

For most custom operations, use Interactive Actions in definitions. When you need a custom controller action:

```ruby
class PostsController < ::ResourceController
  def publish
    authorize_current!(resource_record!, to: :publish?)
    resource_record!.update!(published: true)
    redirect_to resource_url_for(resource_record!), notice: "Published!"
  end
end
```

### Routes for Custom Actions

```ruby
# In portal routes or config/routes.rb
register_resource Post do
  member do
    post :publish
  end
end
```

## Authorization

### Automatic Authorization

Authorization is checked automatically for standard CRUD actions via `authorize_current!`.

### Authorization Verification

Controllers verify authorization was performed after every action:

```ruby
# These run after every action
verify_authorize_current        # Ensures authorize_current! was called
verify_current_authorized_scope # Ensures scope was loaded (except new/create)
```

### Skip Authorization Verification

```ruby
class PostsController < ::ResourceController
  skip_verify_authorize_current only: [:preview]
  skip_verify_current_authorized_scope only: [:preview]

  def preview
    # Handle authorization manually or skip it
  end
end
```

## Nested Resources

Parent records are automatically resolved:

```ruby
# Route: /users/:user_id/nested_posts/:id
class PostsController < ::ResourceController
  # current_parent returns the User
  # resource_record! returns the Post scoped to that User
end
```

Parent fields are automatically excluded from forms/displays. Override with presentation hooks.

### Parent-Related Methods

```ruby
current_parent       # The parent record (e.g., User)
parent_route_param   # The route param key (e.g., :user_id)
parent_input_param   # The association name (e.g., :user)
```

## Entity Scoping (Multi-tenancy)

When a portal is scoped to an entity:

```ruby
# packages/customer_portal/lib/engine.rb
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization
    end
  end
end
```

Controllers automatically:
- Scope all queries to the entity
- Exclude entity field from forms
- Provide `current_scoped_entity` method

## Specifying Resource Class

The resource class is inferred from the controller name. Override if needed:

```ruby
class LegacyPostsController < ::ResourceController
  controller_for Post
end
```

## Response Formats

Controllers respond to multiple formats:

- HTML (default)
- JSON (via RABL templates)
- Turbo Stream (for Hotwire)

## Error Handling

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

## Portal-Specific Controllers

Each portal can have its own controller override:

```ruby
# packages/admin_portal/app/controllers/admin_portal/posts_controller.rb
module AdminPortal
  class PostsController < ResourceController
    private

    def preferred_action_after_submit
      "index"  # Admin prefers list view
    end
  end
end
```

## Best Practices

1. **Keep controllers thin** - Use definitions for UI, policies for auth, interactions for logic
2. **Don't override CRUD actions** - Customize via hooks (`resource_params`, `redirect_url_after_submit`)
3. **Use interactive actions** - For custom operations, define in definition with interaction
4. **Let authorization work** - Don't skip verification without good reason
5. **Trust the framework** - Most customization belongs in definitions or policies

## Related

- [Definition Reference](/reference/definition/) - UI configuration
- [Policy Reference](/reference/policy/) - Authorization
- [Actions Reference](/reference/definition/actions) - Interactive actions
