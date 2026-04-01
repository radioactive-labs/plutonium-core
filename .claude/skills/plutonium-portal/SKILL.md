---
name: plutonium-portal
description: Use when creating portals, connecting resources to portals, configuring authentication, entity scoping, or portal routes
---

# Plutonium Portals

Portals are Rails engines that provide web interfaces for specific user types.

## Creating a Portal

```bash
rails g pu:pkg:portal dashboard
```

### Generator Options

| Option | Description |
|--------|-------------|
| `--auth=NAME` | Rodauth account to authenticate with (e.g., `--auth=user`) |
| `--public` | Grant public access (no authentication) |
| `--byo` | Bring your own authentication |
| `--scope=CLASS` | Entity class to scope to for multi-tenancy (e.g., `--scope=Organization`) |

```bash
# Non-interactive examples
rails g pu:pkg:portal admin --auth=admin
rails g pu:pkg:portal api --public
rails g pu:pkg:portal custom --byo

# With entity scoping (multi-tenancy)
rails g pu:pkg:portal admin --auth=admin --scope=Organization
```

Without flags, the generator prompts interactively.

## Portal Engine

```ruby
# packages/dashboard_portal/lib/engine.rb
module DashboardPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      # Optional: multi-tenancy
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

## Connecting Resources to Portals

Resources must be connected to a portal to be accessible via its web interface.

### Command Syntax

```bash
rails g pu:res:conn RESOURCE [RESOURCE...] --dest=PORTAL_NAME [--singular]
```

**Always specify resources directly** - this avoids interactive prompts.

### Usage Patterns

```bash
# Main app resources
rails g pu:res:conn Post Comment Tag --dest=dashboard_portal

# Namespaced resources (from a feature package)
rails g pu:res:conn Blogging::Post Blogging::Comment --dest=admin_portal

# Singular resources (profile, dashboard, settings)
rails g pu:res:conn Profile --dest=customer_portal --singular
```

### What Gets Generated

For a resource `Post` connected to `admin_portal`:

```
packages/admin_portal/app/
├── controllers/admin_portal/posts_controller.rb   # Portal controller
├── policies/admin_portal/post_policy.rb           # Portal policy
└── definitions/admin_portal/post_definition.rb    # Portal definition
```

Plus route registration in `packages/admin_portal/config/routes.rb`.

### Generated Controller

```ruby
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller
end
```

### Generated Policy

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

### Route Registration

```ruby
# In packages/admin_portal/config/routes.rb
register_resource ::Post
register_resource ::Profile, singular: true  # With --singular
```

### Important Notes

1. **Always specify resources directly** - avoids prompts, no `--src` needed
2. **Always use the generator** - never manually connect resources
3. **Run after migrations** - the generator reads model columns for policy attributes

## Authentication

### Rodauth Integration

```ruby
# packages/dashboard_portal/app/controllers/dashboard_portal/concerns/controller.rb
module DashboardPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:user)  # Use :user account
    end
  end
end
```

### Public Access

```ruby
module DashboardPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Public
    end
  end
end
```

### Custom Authentication

```ruby
module DashboardPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Public

      def current_user
        @current_user ||= User.find_by(api_key: request.headers["X-API-Key"])
      end
    end
  end
end
```

## Entity Scoping (Multi-tenancy)

Automatically scope all data to a parent entity.

### Path Strategy

Entity ID in URL path:

```ruby
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

Routes become: `/organizations/:organization_id/posts`

### Custom Strategy

Implement your own lookup method:

```ruby
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :current_organization
    end
  end
end

# In controller concern
module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller

      private

      # Method name must match strategy
      def current_organization
        @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
      end
    end
  end
end
```

### Accessing the Scoped Entity

```ruby
current_scoped_entity  # The current Organization/Account/etc.
scoped_to_entity?      # true if scoping is active
```

### Model Requirements

Models must have an association path to the scoped entity:

```ruby
# Direct association (preferred)
class Post < ResourceRecord
  belongs_to :organization
end

# Through association
class Comment < ResourceRecord
  belongs_to :post
  has_one :organization, through: :post
end

# Complex (define custom scope)
class AuditLog < ResourceRecord
  scope :associated_with_organization, ->(org) {
    joins(:user).where(users: { organization_id: org.id })
  }
end
```

## Routes

### Portal Routes

```ruby
# packages/dashboard_portal/config/routes.rb
DashboardPortal::Engine.routes.draw do
  root to: "dashboard#index"

  # Register resources
  register_resource ::Post
  register_resource Blogging::Comment

  # Custom routes
  get "settings", to: "settings#index"
end
```

### Custom Routes on Resources

Add member or collection routes with a block:

```ruby
register_resource ::Post do
  member do
    get :preview
    get :analytics
    post :publish
  end
  collection do
    get :archived
    post :bulk_publish
  end
end
```

### Mounting in Main App

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # With authentication constraint
  constraints Rodauth::Rails.authenticate(:user) do
    mount DashboardPortal::Engine, at: "/dashboard"
  end

  # Or without
  mount PublicPortal::Engine, at: "/public"
end
```

## Controller Hierarchy

Portal controllers inherit from the feature package's controller if one exists (and include the portal's `Concerns::Controller`). If no feature package controller exists, they inherit from the portal's `ResourceController`.

```ruby
# With feature package controller:
class DashboardPortal::PostsController < ::PostsController
  include DashboardPortal::Concerns::Controller
end

# Without feature package controller:
class DashboardPortal::PostsController < DashboardPortal::ResourceController
end
```

### Portal ResourceController

```ruby
# packages/dashboard_portal/app/controllers/dashboard_portal/resource_controller.rb
module DashboardPortal
  class ResourceController < ::ResourceController
    include DashboardPortal::Concerns::Controller
  end
end
```

### Non-Resource Controllers

For portal pages not tied to a resource (dashboard, settings, etc.), inherit from `PlutoniumController`:

```ruby
module DashboardPortal
  class DashboardController < PlutoniumController
    def index
      # Dashboard home page
    end
  end
end
```

## Portal-Specific Overrides

### Override Definition

```ruby
class DashboardPortal::PostDefinition < ::PostDefinition
  scope :my_posts, -> { where(user: current_user) }
end
```

### Override Policy

```ruby
class DashboardPortal::PostPolicy < ::PostPolicy
  include DashboardPortal::ResourcePolicy

  def destroy?
    false  # No deletion in user portal
  end

  def permitted_attributes_for_create
    %i[title content]  # Fewer fields than admin
  end
end
```

### Override Controller

```ruby
module DashboardPortal
  class PostsController < ResourceController
    private

    def preferred_action_after_submit
      "index"
    end
  end
end
```

## Multiple Portals Example

```ruby
# Admin portal - full access
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end

# User dashboard - limited access
module DashboardPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end

# Public portal - read-only, no auth
module PublicPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
  end
end
```

## Typical Workflow

```bash
# 1. Create portal
rails g pu:pkg:portal admin --auth=admin --scope=Organization

# 2. Create resources
rails g pu:res:scaffold Post user:belongs_to title:string 'content:text?' --dest=main_app
rails db:migrate

# 3. Connect resources to portal
rails g pu:res:conn Post --dest=admin_portal

# 4. Customize portal-specific definitions/policies as needed
```

## Related Skills

- `plutonium-package` - Package overview (features vs portals)
- `plutonium-rodauth` - Authentication setup and configuration
- `plutonium-policy` - Portal-specific policies
- `plutonium-definition` - Portal-specific definitions
- `plutonium-controller` - Portal-specific controllers
