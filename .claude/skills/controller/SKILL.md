---
name: controller
description: Plutonium resource controllers - CRUD actions, customization, and integration
---

# Plutonium Controllers

Controllers in Plutonium provide full CRUD functionality out of the box. You rarely need to customize them - definitions handle most UI configuration and policies handle authorization.

## Base Classes

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

## What You Get for Free

Every resource controller automatically provides:

| Action | Route | Purpose |
|--------|-------|---------|
| `index` | GET /posts | List with pagination, search, filters, sorting |
| `show` | GET /posts/:id | Display single record |
| `new` | GET /posts/new | New record form |
| `create` | POST /posts | Create record |
| `edit` | GET /posts/:id/edit | Edit record form |
| `update` | PATCH /posts/:id | Update record |
| `destroy` | DELETE /posts/:id | Delete record |

Plus interactive action routes for custom operations defined in definitions.

## When to Customize

**Use Definitions for:**
- Field configuration (inputs, displays, columns)
- Search, filters, scopes, sorting
- Actions (interactive operations)
- Form customization

**Customize Controller for:**
- Custom redirect logic
- Special parameter processing
- Non-standard authorization flows
- External integrations
- Response format changes

## Override Hooks

All customization is done by overriding private methods:

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
    posts_path
  end

  # Custom URL after destroy
  def redirect_url_after_destroy
    posts_path
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

## Custom Actions

```ruby
class PostsController < ::ResourceController
  def publish
    authorize_current!(resource_record!, to: :publish?)
    resource_record!.update!(published: true)
    redirect_to resource_url_for(resource_record!), notice: "Published!"
  end
end
```

Note: For most custom operations, use Interactive Actions in definitions instead.

## Key Methods

### Resource Access

```ruby
resource_class          # The model class (e.g., Post)
resource_record!        # Current record (raises if not found)
resource_record?        # Current record (nil if not found)
resource_params         # Permitted params for create/update
current_parent          # Parent record for nested routes
```

### Authorization

```ruby
authorize_current!(record, to: :action?)  # Check permission
current_policy                            # Policy for current resource
permitted_attributes                      # Allowed attributes for action
current_authorized_scope                  # Scoped records user can access
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
```

## Nested Resources

Parent records are automatically resolved:

```ruby
# Route: /users/:user_id/posts/:id
class PostsController < ::ResourceController
  # current_parent returns the User
  # resource_record! returns the Post scoped to that User
end
```

Parent fields are automatically excluded from forms/displays. Override with presentation hooks (see above).

## Entity Scoping (Multi-tenancy)

When a portal is scoped to an entity:

```ruby
# packages/admin_portal/lib/engine.rb
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

Controllers automatically:
- Scope all queries to the entity
- Exclude entity field from forms
- Provide `current_scoped_entity` method

## Authorization Verification

Controllers verify authorization was performed:

```ruby
# These run after every action
verify_authorize_current        # Ensures authorize_current! was called
verify_current_authorized_scope # Ensures scope was loaded (except new/create)
```

To skip verification for custom actions:

```ruby
class PostsController < ::ResourceController
  skip_verify_authorize_current only: [:custom_action]

  def custom_action
    # Handle authorization manually
  end
end
```

## Response Formats

Controllers respond to multiple formats:

```ruby
def show
  # Responds to:
  # - HTML (default)
  # - JSON (via RABL templates)
  # - Turbo Stream (for Hotwire)
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

## Related Skills

- `resource` - How controllers fit in the resource architecture
- `policy` - Authorization (used by controllers)
- `definition-actions` - Interactive actions (preferred over custom controller actions)
- `views` - Custom page, form, display, and table classes
- `nested-resources` - Parent/child routes and scoping
- `model` - Resource models
