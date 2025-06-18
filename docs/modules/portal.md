---
title: Portal Module
---

# Portal Module

The Portal module provides application segmentation and multi-tenancy capabilities for Plutonium applications. It enables the creation of isolated application contexts with their own routing, authentication, and resource access patterns.

::: tip
The Portal module is located in `lib/plutonium/portal/`. Portals are typically generated in the `packages/` directory.
:::

## Overview

- **Application Segmentation**: Create distinct web interfaces (e.g., admin, customer, public).
- **Multi-Tenant Architecture**: Scope resources to specific entities like organizations or accounts.
- **Isolated Routing**: Each portal has its own independent route namespace.
- **Portal-Specific Authentication**: Apply different authentication strategies to each portal.

## Defining a Portal

Portals are Rails Engines that include `Plutonium::Portal::Engine`. They are best created with the `pu:pkg:portal` generator.

::: code-group
```bash [Generate a Portal]
rails generate pu:pkg:portal admin
```
```ruby [packages/admin_portal/lib/engine.rb]
module AdminPortal
  class Engine < ::Rails::Engine
    # This inclusion provides all portal functionality.
    include Plutonium::Portal::Engine

    # (Optional) Configure entity scoping for multi-tenancy.
    scope_to_entity Organization, strategy: :path
  end
end
```
```ruby [packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb]
# A base concern is created for portal-wide logic.
module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller

      # Include authentication specific to this portal.
      include Plutonium::Auth::Rodauth(:admin)

      included do
        # Add portal-specific logic, e.g., authorization.
        before_action :ensure_admin_access
        layout "admin_portal"
      end

      private

      def ensure_admin_access
        redirect_to root_path unless current_user&.admin?
      end
    end
  end
end
```
:::

## Multi-Tenancy and Entity Scoping

Portals can automatically scope all data to a "scoping entity," such as an `Organization` or `Account`.

### Path-Based Scoping

The most common strategy is `:path`, which uses a URL parameter like `/organizations/:organization_id/...`.

::: code-group
```ruby [Engine Configuration]
# packages/admin_portal/lib/engine.rb
scope_to_entity Organization, strategy: :path
```
```ruby [Route Configuration]
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  # These routes are now automatically nested under /organizations/:organization_id
  register_resource Blog::Post
  register_resource Blog::Comment
end
# Generates routes like:
# /organizations/:organization_id/posts/:id
```
```ruby [Controller Behavior]
# In any controller within the Admin Portal...
class AdminPortal::PostsController < AdminPortal::ResourceController
  def index
    # `current_scoped_entity` returns the Organization from the URL.
    # Queries are automatically scoped. This becomes:
    # @posts = current_scoped_entity.posts.authorized_scope(...)
  end
end
```
:::

::: details Custom Scoping Strategies
You can implement custom scoping strategies, such as by subdomain.
```ruby
# 1. Configure the engine
scope_to_entity Account, strategy: :subdomain

# 2. Implement the lookup in your portal's base controller
class CustomerPortal::ResourceController < Plutonium::Resource::Controller
  private

  # This method is used by Plutonium to get the current tenant
  def current_scoped_entity
    @current_scoped_entity ||= Account.find_by!(subdomain: request.subdomain)
  end
end
```
:::

### Database Association Scoping

For automatic scoping to work, Plutonium needs to find a path from the resource to the scoping entity (`Organization` in this case).

::: code-group
```ruby [Direct Association]
# Plutonium will automatically find this.
class Post < ApplicationRecord
  belongs_to :organization
end
```
```ruby [Indirect Association]
# Plutonium can traverse one level of `has_one` or `belongs_to`.
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'
  has_one :organization, through: :author # This works
end
```
```ruby [Manual Scope]
# For complex cases, define a scope named `associated_with_<entity_name>`.
class Comment < ApplicationRecord
  belongs_to :post

  scope :associated_with_organization, ->(organization) do
    joins(post: :author).where(users: { organization_id: organization.id })
  end
end
```
:::

## Portal Examples

::: details Admin Portal
An internal interface for managing the entire application, scoped to a tenant.
```ruby
# packages/admin_portal/lib/engine.rb
scope_to_entity Organization, strategy: :path

# packages/admin_portal/config/routes.rb
register_resource User
register_resource Organization
register_resource Blog::Post

# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:admin)
before_action :require_admin
```
:::

::: details Customer Portal
A self-service interface for customers, often scoped by subdomain.
```ruby
# packages/customer_portal/lib/engine.rb
scope_to_entity Organization, strategy: :subdomain

# packages/customer_portal/config/routes.rb
register_resource Project
register_resource Invoice
register_resource SupportTicket

# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:customer)
```
:::

::: details Public Portal
A public-facing portal with no authentication.
```ruby
# packages/public_portal/lib/engine.rb
# No `scope_to_entity`

# packages/public_portal/config/routes.rb
register_resource Blog::Post # e.g., for a public blog

# packages/public_portal/app/controllers/public_portal/concerns/controller.rb
include Plutonium::Auth::Public # No authentication
```
:::

## Authentication Integration

### Rodauth Integration

Portals integrate seamlessly with Rodauth for authentication:

```ruby
# config/rodauth.rb
class RodauthApp < Roda
  plugin :rodauth, json: :only do
    # Admin authentication
    rodauth :admin do
      enable :login, :logout, :create_account, :verify_account,
             :reset_password, :change_password, :otp, :recovery_codes

      rails_account_model { Admin }
      rails_controller { Rodauth::AdminController }
      prefix "/admin/auth"

      # Require MFA for admin accounts
      two_factor_auth_required? true
    end

    # Customer authentication
    rodauth :customer do
      enable :login, :logout, :create_account, :verify_account,
             :reset_password, :change_password, :remember

      rails_account_model { Customer }
      rails_controller { Rodauth::CustomerController }
      prefix "/auth"
    end
  end
end

# Portal-specific authentication
module AdminPortal
  module Concerns
    module Controller
      include Plutonium::Auth::Rodauth(:admin)
    end
  end
end

module CustomerPortal
  module Concerns
    module Controller
      include Plutonium::Auth::Rodauth(:customer)
    end
  end
end
```

### Route Constraints

Authentication can be enforced at the routing level:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Admin portal requires admin authentication
  constraints Rodauth::Rails.authenticate(:admin) do
    mount AdminPortal::Engine, at: "/admin"
  end

  # Customer portal requires customer authentication
  constraints Rodauth::Rails.authenticate(:customer) do
    mount CustomerPortal::Engine, at: "/app"
  end

  # Public portal has no authentication constraint
  mount PublicPortal::Engine, at: "/"
end
```

## Resource Registration and Access Control

### Resource Registration

Resources are explicitly registered with each portal:

```ruby
# Admin portal - full access
AdminPortal::Engine.routes.draw do
  register_resource User
  register_resource Organization
  register_resource Blog::Post
  register_resource Blog::Comment
  register_resource Analytics::Report
  register_resource Billing::Invoice
end

# Customer portal - limited access
CustomerPortal::Engine.routes.draw do
  register_resource Project
  register_resource Billing::Invoice, only: [:index, :show]
  register_resource SupportTicket
end

# Public portal - read-only access
PublicPortal::Engine.routes.draw do
  register_resource Blog::Post, only: [:index, :show]
  register_resource Page, only: [:show]
end
```

### Conditional Resource Registration

```ruby
# Dynamic resource registration based on configuration
AdminPortal::Engine.routes.draw do
  register_resource User
  register_resource Organization

  # Feature flags
  register_resource Blog::Post if Rails.application.config.enable_blog
  register_resource Analytics::Report if Rails.application.config.enable_analytics

  # Environment-specific resources
  register_resource SystemLog if Rails.env.development?
end
```

### Portal-Specific Policies

Each portal can have its own policy implementations:

```ruby
# packages/admin_portal/app/policies/admin_portal/user_policy.rb
module AdminPortal
  class UserPolicy < ::UserPolicy
    # Admins can do everything
    def create?
      user.super_admin?
    end

    def destroy?
      user.super_admin? && record != user
    end
  end
end

# packages/customer_portal/app/policies/customer_portal/project_policy.rb
module CustomerPortal
  class ProjectPolicy < ::ProjectPolicy
    # Customers can only see their own projects
    def index?
      true
    end

    def show?
      record.organization == user.organization
    end

    def create?
      user.can_create_projects?
    end
  end
end
```

## Advanced Portal Configuration

### Portal-Specific Layouts

Each portal can have its own layout and styling:

```erb
<!-- packages/admin_portal/app/views/layouts/admin_portal.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title>Admin Portal</title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "admin_portal", "data-turbo-track": "reload" %>
    <%= javascript_include_tag "admin_portal", "data-turbo-track": "reload", defer: true %>
  </head>

  <body class="admin-theme">
    <nav class="admin-nav">
      <%= link_to "Dashboard", admin_portal.root_path %>
      <%= link_to "Users", admin_portal.users_path %>
      <%= link_to "Organizations", admin_portal.organizations_path %>
    </nav>

    <main>
      <%= yield %>
    </main>
  </body>
</html>
```

### Portal-Specific Components

```ruby
# packages/admin_portal/app/components/admin_portal/sidebar_component.rb
module AdminPortal
  class SidebarComponent < Plutonium::UI::Component::Base
    def view_template
      aside(class: "admin-sidebar") do
        nav do
          ul do
            li { link_to "Dashboard", root_path }
            li { link_to "Users", users_path }
            li { link_to "Organizations", organizations_path }

            if current_user.super_admin?
              li { link_to "System Logs", system_logs_path }
            end
          end
        end
      end
    end
  end
end
```

## Portal Generation and Setup

### Generating Portals

Plutonium provides generators for creating portals:

```bash
# Generate a new admin portal
rails generate pu:pkg:portal admin --auth=admin

# Generate a customer portal
rails generate pu:pkg:portal customer --auth=customer

# Generate a public portal
rails generate pu:pkg:portal public --public

# Connect resources to portals
rails generate pu:res:conn post --dest=admin_portal
rails generate pu:res:conn project --dest=customer_portal
```

### Portal Structure

Generated portals follow a consistent structure:

```
packages/admin_portal/
├── app/
│   ├── controllers/
│   │   └── admin_portal/
│   │       ├── concerns/
│   │       │   └── controller.rb
│   │       ├── dashboard_controller.rb
│   │       ├── plutonium_controller.rb
│   │       └── resource_controller.rb
│   ├── policies/
│   │   └── admin_portal/
│   ├── definitions/
│   │   └── admin_portal/
│   └── views/
│       └── layouts/
│           └── admin_portal.html.erb
├── config/
│   └── routes.rb
└── lib/
    └── engine.rb
```

## Best Practices

### Portal Design

1. **Single Responsibility**: Each portal should serve a specific user type or use case
2. **Clear Boundaries**: Maintain clear separation between different portal contexts
3. **Consistent Navigation**: Provide intuitive navigation within each portal
4. **Security First**: Apply appropriate authentication and authorization for each portal

### Multi-Tenancy

1. **Entity Modeling**: Design clear entity relationships for scoping

### Resource Management

1. **Explicit Registration**: Always explicitly register resources with portals
2. **Portal-Specific Policies**: Create portal-specific policies when needed

### Authentication Strategy

1. **Portal-Specific Auth**: Use appropriate authentication for each portal type
2. **Security Headers**: Implement proper security headers for each portal
3. **Session Management**: Handle sessions appropriately across portals
4. **Route Constraints**: Use route constraints to enforce authentication

## Integration Points

- **Core Module**: Provides base controller functionality and entity scoping
- **Authentication Module**: Portal-specific authentication strategies
- **Policy Module**: Entity-aware authorization and scoping
- **Package Module**: Package-based organization and resource registration
- **Resource Module**: Resource controllers work seamlessly within portals
