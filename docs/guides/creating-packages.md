# Creating Packages

This guide covers creating and organizing Feature Packages and Portal Packages.

## Package Types

| Type | Purpose | Generator |
|------|---------|-----------|
| **Feature Package** | Business logic (models, definitions, policies) | `rails g pu:pkg:package NAME` |
| **Portal Package** | Web interface (routes, auth, UI) | `rails g pu:pkg:portal NAME` |

## Creating a Feature Package

### Using the Generator

```bash
rails g pu:pkg:package blogging
```

### Generated Structure

```
packages/blogging/
├── app/
│   ├── controllers/blogging/
│   │   └── resource_controller.rb
│   ├── definitions/blogging/
│   │   └── resource_definition.rb
│   ├── interactions/blogging/
│   │   └── resource_interaction.rb
│   ├── models/blogging/
│   │   └── resource_record.rb
│   ├── policies/blogging/
│   │   └── resource_policy.rb
│   └── views/blogging/
└── lib/
    └── engine.rb
```

### Engine Configuration

```ruby
# packages/blogging/lib/engine.rb
module Blogging
  class Engine < Rails::Engine
    include Plutonium::Package::Engine
  end
end
```

### Namespacing

All classes are auto-namespaced:
- `app/models/blogging/post.rb` → `Blogging::Post`
- `app/policies/blogging/post_policy.rb` → `Blogging::PostPolicy`

## Creating a Portal Package

### Using the Generator

```bash
rails g pu:pkg:portal admin
```

### Generator Options

| Option | Description |
|--------|-------------|
| `--auth=NAME` | Rodauth account to authenticate with |
| `--public` | Grant public access (no authentication) |
| `--byo` | Bring your own authentication |

```bash
# Non-interactive examples
rails g pu:pkg:portal admin --auth=admin
rails g pu:pkg:portal api --public
rails g pu:pkg:portal custom --byo
```

Without flags, the generator prompts interactively.

### Generated Structure

```
packages/admin_portal/
├── app/
│   ├── controllers/admin_portal/
│   │   ├── concerns/controller.rb
│   │   ├── dashboard_controller.rb
│   │   ├── plutonium_controller.rb
│   │   └── resource_controller.rb
│   ├── definitions/admin_portal/
│   │   └── resource_definition.rb
│   ├── policies/admin_portal/
│   │   └── resource_policy.rb
│   └── views/admin_portal/
│       └── dashboard/index.html.erb
├── config/
│   └── routes.rb
└── lib/
    └── engine.rb
```

### Portal Engine

```ruby
# packages/admin_portal/lib/engine.rb
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      # Multi-tenancy (optional)
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

### Portal Authentication

Authentication is configured in the controller concern based on generator options:

```ruby
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:admin)
    end
  end
end
```

For public access:

```ruby
include Plutonium::Auth::Public
```

For custom authentication:

```ruby
included do
  helper_method :current_user
end

def current_user
  # Your authentication logic
  @current_user ||= User.find_by(api_key: request.headers["X-API-Key"])
end
```

## Portal Routes

The portal generator creates routes and auto-mounts to the main app:

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"

  # Register resources here
  register_resource ::Post
  register_resource Blogging::Comment
end

# Also adds to main app routes:
# config/routes.rb (auto-generated)
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:admin) do
    mount AdminPortal::Engine, at: "/admin"
  end
end
```

### Custom Routes on Resources

Add member or collection routes with a block:

```ruby
register_resource ::Post do
  member do
    get :preview
    post :publish
  end
  collection do
    get :archived
  end
end
```

## Package Loading

Packages are loaded via `config/packages.rb` (generated during install):

```ruby
# config/packages.rb
Dir.glob(File.expand_path("../packages/**/lib/engine.rb", __dir__)) do |package|
  load package
end
```

This is automatically required in `config/application.rb`.

## Adding Resources to Packages

```bash
# Add to main app
rails g pu:res:scaffold Post title:string --dest=main_app

# Add to a feature package
rails g pu:res:scaffold Post title:string --dest=blogging
```

Resources are namespaced:

```ruby
# packages/blogging/app/models/blogging/post.rb
module Blogging
  class Post < Blogging::ResourceRecord
    # Model code
  end
end
```

## Connecting Resources to Portals

Resources must be connected to portals to be accessible:

```bash
# Connect main app resource
rails g pu:res:conn Post --dest=admin_portal

# Connect namespaced resource
rails g pu:res:conn Blogging::Post --dest=admin_portal
```

## Entity Scoping (Multi-tenancy)

Automatically scope all data to a parent entity:

### Path Strategy

Entity ID in URL path:

```ruby
# packages/admin_portal/lib/engine.rb
config.after_initialize do
  scope_to_entity Organization, strategy: :path
end
```

Routes become: `/organizations/:organization_id/posts`

### Custom Strategy

Implement your own lookup method:

```ruby
config.after_initialize do
  scope_to_entity Organization, strategy: :current_organization
end

# In controller concern
def current_organization
  @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
end
```

## Package Best Practices

### 1. Single Responsibility
Each feature package should handle one domain:
- `blogging` - Posts, comments, categories
- `inventory` - Products, stock, warehouses
- `billing` - Invoices, payments, subscriptions

### 2. Clear Naming
- Feature packages: domain nouns (`blogging`, `billing`)
- Portal packages: role + portal (`admin_portal`, `api_portal`)

### 3. Minimal Cross-Dependencies
Limit dependencies between feature packages. If two packages are tightly coupled, consider merging them.

### 4. Portal Customization
Put UI customizations in portal packages, not feature packages:

```ruby
# Good: Portal-specific definition
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb

# Bad: Feature package with portal-specific code
# packages/blogging/app/definitions/blogging/admin_post_definition.rb
```

## Multiple Portals Pattern

Common pattern for different user types:

```
packages/
├── blogging/           # Feature: blog functionality
├── billing/            # Feature: payment/invoicing
├── admin_portal/       # Portal: admin interface
├── dashboard_portal/   # Portal: user dashboard
└── public_portal/      # Portal: public read-only
```

Each portal can:
- Have different authentication
- Show different fields
- Allow different actions
- Use different layouts

## Portal-Specific Overrides

### Override Definition

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
class AdminPortal::PostDefinition < ::PostDefinition
  # Add portal-specific scopes
  scope :my_posts, -> { where(user: current_user) }
end
```

### Override Policy

```ruby
# packages/admin_portal/app/policies/admin_portal/post_policy.rb
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  def destroy?
    true  # Admins can delete
  end

  def permitted_attributes_for_create
    %i[title content featured internal_notes]  # More fields
  end
end
```

### Override Controller

```ruby
# packages/admin_portal/app/controllers/admin_portal/posts_controller.rb
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller

  private

  def preferred_action_after_submit
    "index"
  end
end
```

## Controller Hierarchy

Portal controllers inherit from the feature package's controller if one exists (and include the portal's `Concerns::Controller`). If no feature package controller exists, they inherit from the portal's `ResourceController`.

```ruby
# With feature package controller:
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller
end

# Without feature package controller:
class AdminPortal::PostsController < AdminPortal::ResourceController
end
```

## Related

- [Adding Resources](./adding-resources)
- [Authentication](./authentication)
- [Multi-tenancy](./multi-tenancy)
