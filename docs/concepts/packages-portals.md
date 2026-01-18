# Packages and Portals

Plutonium organizes applications using two types of packages: **Feature Packages** for business logic and **Portal Packages** for web interfaces.

## Why Packages?

Packages provide:
- **Modularity** - Features are isolated and self-contained
- **Reusability** - Share features across multiple interfaces
- **Scalability** - Large apps stay organized
- **Team collaboration** - Teams can own specific packages

## Feature Packages

Feature packages contain your business logic: models, definitions, policies, interactions, and controllers.

### Creating a Feature Package

```bash
rails generate pu:pkg:package blogging
```

This creates:

```
packages/blogging/
├── app/
│   ├── controllers/blogging/
│   ├── definitions/blogging/
│   ├── interactions/blogging/
│   ├── models/blogging/
│   ├── policies/blogging/
│   └── views/blogging/
└── lib/
    └── engine.rb
```

### Feature Package Structure

```ruby
# packages/blogging/lib/engine.rb
module Blogging
  class Engine < Rails::Engine
    include Plutonium::Package::Engine

    # Package configuration here
  end
end
```

### Adding Resources to a Feature Package

```bash
rails generate pu:res:scaffold Post title:string body:text --package blogging
```

Resources are namespaced under the package:

```ruby
# packages/blogging/app/models/blogging/post.rb
module Blogging
  class Post < Blogging::ResourceRecord
  end
end
```

## Portal Packages

Portal packages are web interfaces that expose resources to users. Each portal can have its own authentication, authorization, and UI customizations.

### Creating a Portal Package

```bash
rails generate pu:pkg:portal admin
```

This creates:

```
packages/admin_portal/
├── app/
│   ├── controllers/admin_portal/
│   └── views/admin_portal/
├── config/
│   └── routes.rb
├── lib/
│   └── admin_portal/
│       └── engine.rb
├── admin_portal.gemspec
└── Gemfile
```

### Portal Engine

```ruby
# packages/admin_portal/lib/admin_portal/engine.rb
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      # Optional: Scope to an entity (multi-tenancy)
      scope_to_entity Organization
    end
  end
end
```

### Portal Authentication

Authentication is configured in the controller concern:

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

### Connecting Resources to Portals

```bash
rails generate pu:res:conn Post --package blogging --portal admin
```

This:
1. Creates portal-specific routes
2. Optionally creates portal-specific controller
3. Registers the resource with the portal

## Multiple Portals

A common pattern is having different portals for different user types:

```
packages/
├── admin_portal/      # Full access for administrators
├── author_portal/     # Content management for authors
└── customer_portal/   # Public-facing interface
```

Each portal can:
- Use different authentication
- Show different fields
- Apply different policies
- Have unique UI customization

### Example: Same Resource, Different Portals

```ruby
# Admin sees everything
# packages/admin_portal/app/policies/admin_portal/blogging/post_policy.rb
module AdminPortal
  module Blogging
    class PostPolicy < ::Blogging::PostPolicy
      def read?
        true  # Admins see all posts
      end
    end
  end
end

# Authors see only their posts
# packages/author_portal/app/policies/author_portal/blogging/post_policy.rb
module AuthorPortal
  module Blogging
    class PostPolicy < ::Blogging::PostPolicy
      def read?
        record.user_id == user.id
      end
    end
  end
end
```

## Package Dependencies

Feature packages can depend on each other:

```ruby
# packages/blogging/blogging.gemspec
Gem::Specification.new do |spec|
  spec.add_dependency "users"  # Depends on users package
end
```

## Mounting Packages

Packages are mounted in the main application routes:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount AdminPortal::Engine, at: "/admin"
  mount AuthorPortal::Engine, at: "/author"
  mount CustomerPortal::Engine, at: "/"
end
```

## Authentication per Portal

Each portal can use different authentication via its controller concern:

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

# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
module CustomerPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:customer)
    end
  end
end
```

## Entity Scoping (Multi-tenancy)

Portals can be scoped to an entity:

```ruby
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      # All resources scoped to current organization
      scope_to_entity Organization
    end
  end
end
```

With entity scoping:
- All queries automatically filter by entity
- New records automatically belong to entity
- Users can only access their entity's data

## Portal Customization

### Custom Layouts

```ruby
# packages/admin_portal/app/views/layouts/admin_portal/application.rb
module AdminPortal
  class ApplicationLayout < Plutonium::UI::Layout::Application
    def render_logo
      img(src: asset_path("admin-logo.svg"))
    end
  end
end
```

### Portal-Specific Definitions

```ruby
# packages/admin_portal/app/definitions/admin_portal/blogging/post_definition.rb
module AdminPortal
  module Blogging
    class PostDefinition < ::Blogging::PostDefinition
      # Add admin-specific fields
      field :internal_notes, as: :text
    end
  end
end
```

## Best Practices

### 1. One Feature, One Package
Keep packages focused. A "blogging" package shouldn't handle user management.

### 2. Portal-Specific Overrides
Put customizations in the portal package, not the feature package.

### 3. Shared Logic in Features
Business logic goes in feature packages, UI customization in portals.

### 4. Clear Naming
- Feature packages: noun (blogging, inventory, billing)
- Portal packages: role + portal (admin_portal, customer_portal)

## Related Topics

- [Architecture](./architecture) - How layers work together
- [Resources](./resources) - Understanding resources
- [Portal Reference](/reference/portal/) - Portal configuration
