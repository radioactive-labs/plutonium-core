---
title: Portal Module
---

# Portal Module

The Portal module is your key to building sophisticated, multi-tenant applications with distinct user experiences. Think of portals as separate "faces" of your application—each designed for different types of users, with their own authentication, styling, and access controls, while sharing the same underlying business logic.

::: tip
The Portal module is located in `lib/plutonium/portal/`. Portals are typically generated as packages in the `packages/` directory.
:::

## What Portals Solve

Modern applications often need to serve different types of users with completely different interfaces:

- **Admin Portal**: Full system access for administrators and staff
- **Customer Portal**: Self-service interface for customers and clients
- **Partner Portal**: Specialized access for business partners
- **Public Portal**: Public-facing content and marketing pages

Each portal can have its own authentication system, visual design, feature set, and data access patterns, while sharing the same core business logic and data models.

## Core Portal Capabilities

- **Application Segmentation**: Create completely isolated user experiences
- **Multi-Tenant Architecture**: Automatically scope data to organizations, accounts, or other entities
- **Independent Routing**: Each portal has its own URL structure and route namespace
- **Portal-Specific Authentication**: Different login systems and security requirements per portal
- **Flexible Access Control**: Fine-grained permissions tailored to each user type

## Creating a Portal

Portals are Rails Engines enhanced with Plutonium's portal functionality. The easiest way to create one is with the generator:

::: code-group
```bash [Generate a Portal]
rails generate pu:pkg:portal admin
```

```ruby [packages/admin_portal/lib/engine.rb]
module AdminPortal
  class Engine < ::Rails::Engine
    # This inclusion provides all portal functionality
    include Plutonium::Portal::Engine

    # Optional: Configure multi-tenancy
    scope_to_entity Organization, strategy: :path
  end
end
```

```ruby [packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb]
# A base concern is created for portal-wide logic
module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller

      # Include authentication specific to this portal
      include Plutonium::Auth::Rodauth(:admin)

      included do
        # Add portal-specific logic
        before_action :ensure_admin_access
        layout "admin_portal"

        # Portal-wide error handling
        rescue_from AdminPortal::AccessDenied, with: :handle_access_denied
      end

      private

      def ensure_admin_access
        redirect_to root_path, error: "Admin access required" unless current_user&.admin?
      end

      def handle_access_denied(exception)
        redirect_to admin_root_path, error: "Access denied: #{exception.message}"
      end
    end
  end
end
```
:::

## Multi-Tenancy with Entity Scoping

One of the most powerful features of portals is automatic multi-tenancy through entity scoping. When you scope a portal to an entity (like Organization or Account), all data access is automatically filtered and secured.

### Path-Based Scoping

The most straightforward approach uses URL parameters to identify the tenant:

::: code-group
```ruby [Engine Configuration]
# packages/admin_portal/lib/engine.rb
scope_to_entity Organization, strategy: :path
```

```ruby [Route Configuration]
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  # These routes are automatically nested under /organizations/:organization_id
  register_resource Blog::Post
  register_resource Blog::Comment
end

# Generated routes:
# GET /organizations/:organization_id/posts
# GET /organizations/:organization_id/posts/:id
# POST /organizations/:organization_id/posts
```

```ruby [Automatic Data Scoping]
# In any controller within the Admin Portal
class AdminPortal::PostsController < AdminPortal::ResourceController
  def index
    # current_scoped_entity returns the Organization from the URL
    # All queries are automatically scoped to this organization
    # @posts = current_scoped_entity.posts.authorized_scope(...)
  end
end
```
:::

### Custom Scoping Strategies

For more sophisticated multi-tenancy, implement custom scoping strategies:

::: code-group
```ruby [Engine Configuration]
# Use subdomain-based tenancy
scope_to_entity Account, strategy: :current_account
```

```ruby [Controller Implementation]
module CustomerPortal::Concerns::Controller
  private

  # Method name must match the strategy name exactly
  def current_account
    @current_account ||= Account.find_by!(subdomain: request.subdomain)
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, error: "Invalid account subdomain"
  end
end
```
:::

### Database Association Requirements

For automatic scoping to work, Plutonium needs to find a path from your resources to the scoping entity:

::: code-group
```ruby [Direct Association (Preferred)]
# Plutonium automatically finds this relationship
class Post < ApplicationRecord
  belongs_to :organization
end
```

```ruby [Indirect Association]
# Plutonium can traverse one level of has_one or belongs_to
class Post < ApplicationRecord
  belongs_to :author, class_name: 'User'
  has_one :organization, through: :author
end
```

```ruby [Manual Scope (For Complex Cases)]
# Define a scope for complex relationships
class Comment < ApplicationRecord
  belongs_to :post

  scope :associated_with_organization, ->(organization) do
    joins(post: :author).where(users: { organization_id: organization.id })
  end
end
```
:::

## Portal Examples and Use Cases

### Admin Portal: Internal Management

Perfect for system administrators and internal staff who need full access:

::: code-group
```ruby [Configuration]
# packages/admin_portal/lib/engine.rb
scope_to_entity Organization, strategy: :path

# packages/admin_portal/config/routes.rb
register_resource User
register_resource Organization
register_resource Blog::Post
register_resource Analytics::Report
```

```ruby [Authentication & Authorization]
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:admin)

included do
  before_action :require_admin_role
  before_action :set_admin_context
end

private

def require_admin_role
  redirect_to root_path unless current_user&.admin?
end
```
:::

### Customer Portal: Self-Service Interface

Designed for customers to manage their own accounts and data:

::: code-group
```ruby [Configuration]
# packages/customer_portal/lib/engine.rb
scope_to_entity Organization, strategy: :current_organization

# packages/customer_portal/config/routes.rb
register_resource Project
register_resource Invoice
register_resource SupportTicket
```

```ruby [Custom Scoping]
# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:customer)

private

def current_organization
  @current_organization ||= current_user&.organization
end
```
:::

### Public Portal: No Authentication Required

For marketing sites, blogs, and public content:

::: code-group
```ruby [Configuration]
# packages/public_portal/lib/engine.rb
# No scope_to_entity - public data

# packages/public_portal/config/routes.rb
register_resource Blog::Post
register_resource Page
register_resource ContactForm
```

```ruby [Public Access]
# packages/public_portal/app/controllers/public_portal/concerns/controller.rb
# No authentication required
include Plutonium::Portal::Controller

# Custom public-specific logic
before_action :track_visitor_analytics
```
:::

## Authentication Integration

### Rodauth Multi-Account Setup

Portals integrate seamlessly with Rodauth for sophisticated authentication:

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

    # Customer authentication with user-friendly features
    rodauth :customer do
      enable :login, :logout, :create_account, :verify_account,
             :reset_password, :change_password, :remember

      rails_account_model { Customer }
      rails_controller { Rodauth::CustomerController }
      prefix "/auth"

      # Remember me functionality
      remember_deadline 30.days
    end
  end
end
```

### Portal-Specific Authentication

Each portal includes its appropriate authentication:

```ruby
# Admin Portal - High security
module AdminPortal
  module Concerns
    module Controller
      include Plutonium::Auth::Rodauth(:admin)
    end
  end
end

# Customer Portal - User-friendly
module CustomerPortal
  module Concerns
    module Controller
      include Plutonium::Auth::Rodauth(:customer)
    end
  end
end
```

### Route-Level Authentication

Enforce authentication at the routing level:

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

## Resource Management and Access Control

### Resource Registration

Resources must be explicitly registered with each portal:

```ruby
# Admin portal - comprehensive access
AdminPortal::Engine.routes.draw do
  register_resource User
  register_resource Organization
  register_resource Blog::Post
  register_resource Blog::Comment
  register_resource Analytics::Report
  register_resource Billing::Invoice
end

# Customer portal - limited, relevant resources
CustomerPortal::Engine.routes.draw do
  register_resource Project
  register_resource Billing::Invoice  # Access controlled via policy
  register_resource SupportTicket
end

# Public portal - read-only, published content
PublicPortal::Engine.routes.draw do
  register_resource Blog::Post  # Only published posts via policy
  register_resource Page        # Only public pages via policy
end
```

### Conditional Resource Registration

Dynamically register resources based on configuration or environment:

```ruby
AdminPortal::Engine.routes.draw do
  register_resource User
  register_resource Organization

  # Feature flags
  register_resource Blog::Post if Rails.application.config.enable_blog
  register_resource Analytics::Report if Rails.application.config.enable_analytics

  # Environment-specific resources
  register_resource SystemLog if Rails.env.development?
  register_resource PerformanceMetric if Rails.env.production?
end
```

### Portal-Specific Access Control

Since `register_resource` doesn't support Rails' `only:` and `except:` options, access control is handled through portal-specific policies:

```ruby
# Customer portal - read-only invoice access
class CustomerPortal::Billing::InvoicePolicy < Plutonium::Resource::Policy
  def create?
    false  # Customers can't create invoices
  end

  def update?
    false  # Customers can't modify invoices
  end

  def destroy?
    false  # Customers can't delete invoices
  end

  def read?
    record.organization == user.organization  # Only their org's invoices
  end
end

# Public portal - only published content
class PublicPortal::Blog::PostPolicy < Plutonium::Resource::Policy
  def create?
    false  # No creation in public portal
  end

  def update?
    false  # No editing in public portal
  end

  def destroy?
    false  # No deletion in public portal
  end

  def read?
    record.published? && record.public?  # Only published, public posts
  end
end
```

### Portal-Specific Policy Inheritance

Create portal-specific policy variations:

```ruby
# Admin portal - enhanced permissions for admins
module AdminPortal
  class UserPolicy < ::UserPolicy
    def create?
      user.super_admin?  # Only super admins can create users
    end

    def destroy?
      user.super_admin? && record != user  # Can't delete themselves
    end

    def impersonate?
      user.super_admin? && Rails.env.development?
    end
  end
end

# Customer portal - restricted permissions
module CustomerPortal
  class ProjectPolicy < ::ProjectPolicy
    def index?
      true  # Can list their projects
    end

    def show?
      record.organization == user.organization  # Only their org's projects
    end

    def create?
      user.can_create_projects? && user.organization.active?
    end

    def destroy?
      false  # Customers can't delete projects
    end
  end
end
```

## Advanced Portal Customization

### Portal-Specific Layouts and Styling

Each portal can have completely different visual designs:

```erb
<!-- packages/admin_portal/app/views/layouts/admin_portal.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <title>Admin Portal - <%= @page_title || "Dashboard" %></title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= stylesheet_link_tag "admin_portal", "data-turbo-track": "reload" %>
    <%= javascript_include_tag "admin_portal", "data-turbo-track": "reload", defer: true %>
  </head>

  <body class="admin-theme dark-mode">
    <!-- Admin-specific navigation -->
    <nav class="admin-nav">
      <%= link_to "Dashboard", admin_portal.root_path, class: "nav-link" %>
      <%= link_to "Users", admin_portal.users_path, class: "nav-link" %>
      <%= link_to "Organizations", admin_portal.organizations_path, class: "nav-link" %>

      <div class="nav-user">
        <%= current_user.name %>
        <%= link_to "Logout", admin_portal.logout_path, method: :delete %>
      </div>
    </nav>

    <main class="admin-content">
      <!-- Flash messages with admin styling -->
      <% flash.each do |type, message| %>
        <div class="alert alert-<%= type %> admin-alert">
          <%= message %>
        </div>
      <% end %>

      <%= yield %>
    </main>
  </body>
</html>
```

### Portal-Specific Components

Create reusable components tailored to each portal:

```ruby
# packages/admin_portal/app/components/admin_portal/sidebar_component.rb
module AdminPortal
  class SidebarComponent < Plutonium::UI::Component::Base
    def view_template
      aside(class: "admin-sidebar") do
        nav do
          ul(class: "nav-menu") do
            li { link_to "Dashboard", root_path, class: nav_link_class("dashboard") }
            li { link_to "Users", users_path, class: nav_link_class("users") }
            li { link_to "Organizations", organizations_path, class: nav_link_class("organizations") }

            # Conditional navigation based on permissions
            if current_user.super_admin?
              li { link_to "System Logs", system_logs_path, class: nav_link_class("logs") }
              li { link_to "Analytics", analytics_path, class: nav_link_class("analytics") }
            end

            # Feature-flagged navigation
            if FeatureFlag.enabled?(:billing_portal)
              li { link_to "Billing", billing_path, class: nav_link_class("billing") }
            end
          end
        end
      end
    end

    private

    def nav_link_class(section)
      base_class = "nav-link"
      base_class += " active" if current_section == section
      base_class
    end
  end
end
```

## Portal Generation and Setup

### Using Generators

Plutonium provides comprehensive generators for portal creation:

```bash
# Generate a full-featured admin portal
rails generate pu:pkg:portal admin

# Generate a customer portal
rails generate pu:pkg:portal customer

# Generate a public portal
rails generate pu:pkg:portal public

# Connect existing resources to portals
rails generate pu:res:conn post --dest=admin_portal
rails generate pu:res:conn project --dest=customer_portal
```

### Generated Portal Structure

Generators create a well-organized portal structure:

```
packages/admin_portal/
├── app/
│   ├── controllers/
│   │   └── admin_portal/
│   │       ├── concerns/
│   │       │   └── controller.rb          # Portal-wide controller logic
│   │       ├── dashboard_controller.rb     # Portal dashboard
│   │       ├── plutonium_controller.rb     # Base controller
│   │       └── resource_controller.rb      # Resource controller base
│   ├── policies/
│   │   └── admin_portal/                   # Portal-specific policies
│   ├── definitions/
│   │   └── admin_portal/                   # Portal-specific resource definitions
│   └── views/
│       └── layouts/
│           └── admin_portal.html.erb       # Portal-specific layout
├── config/
│   └── routes.rb                           # Portal routes
└── lib/
    └── engine.rb                           # Portal engine configuration
```

## Best Practices

### Multi-Tenancy Best Practices

**Entity Modeling**
Design clear entity relationships:

```ruby
# ✅ Good - clear entity hierarchy
class Organization < ApplicationRecord
  has_many :users
  has_many :projects
  has_many :invoices
end

class User < ApplicationRecord
  belongs_to :organization
  has_many :projects
end

class Project < ApplicationRecord
  belongs_to :organization
  belongs_to :user
end
```

**Consistent Scoping**
Use the same scoping strategy throughout your portal:

```ruby
# ✅ Good - consistent scoping
class AdminPortal::Engine < Rails::Engine
  scope_to_entity Organization, strategy: :path
end

# All controllers automatically scope to organization
# All policies receive the scoped organization context
```

### Security First

**Portal-Specific Authentication**
Use appropriate authentication for each portal:

```ruby
# ✅ Good - tailored authentication
module AdminPortal::Concerns::Controller
  include Plutonium::Auth::Rodauth(:admin)
end

module CustomerPortal::Concerns::Controller
  include Plutonium::Auth::Rodauth(:customer)
end
```

**Route Constraints**
Enforce authentication at the routing level:

```ruby
# ✅ Good - route-level security
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:admin) do
    mount AdminPortal::Engine, at: "/admin"
  end

  constraints Rodauth::Rails.authenticate(:customer) do
    mount CustomerPortal::Engine, at: "/app"
  end
end
```

## Integration with Other Modules

The Portal module works seamlessly with other Plutonium components:

- **[Core](./core.md)**: Provides base controller functionality and entity scoping capabilities
- **[Authentication](./authentication.md)**: Portal-specific authentication strategies and session management
- **[Policy](./policy.md)**: Entity-aware authorization and portal-specific access control
- **[Package](./package.md)**: Package-based organization and resource registration
- **[Resource Record](./resource_record.md)**: Resource controllers work seamlessly within portal contexts
- **[Routing](./routing.md)**: Automatic route generation with entity scoping and portal isolation
