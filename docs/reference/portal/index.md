# Portal Reference

Complete reference for portal configuration.

## Overview

Portals are web interfaces that expose resources to users. Each portal can have:
- Its own authentication
- Custom authorization rules
- UI customizations
- Entity scoping (multi-tenancy)

## Creating a Portal

```bash
rails generate pu:pkg:portal admin
```

### Generator Options

| Option | Description |
|--------|-------------|
| `--auth NAME` | Rodauth account to authenticate with (e.g., `--auth=user`) |
| `--public` | Grant public access (no authentication) |
| `--byo` | Bring your own authentication |

```bash
# Non-interactive examples
rails generate pu:pkg:portal admin --auth=admin
rails generate pu:pkg:portal api --public
rails generate pu:pkg:portal custom --byo
```

Without flags, the generator prompts interactively for authentication choice.

## Base Configuration

```ruby
# packages/admin_portal/lib/admin_portal/engine.rb
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    # Configuration here
  end
end
```

## Authentication

Authentication is configured in the portal's controller concern.

### Basic Authentication

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

### Public Portal (No Authentication)

```ruby
# packages/public_portal/app/controllers/public_portal/concerns/controller.rb
module PublicPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Public
    end
  end
end
```

### Multiple Account Types

```ruby
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:admin)

# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:customer)
```

### Accessing Current User

```ruby
# In controllers
current_user

# In views
current_user

# In policies
user  # The authenticated user
```

## Entity Scoping (Multi-tenancy)

### Basic Scoping

```ruby
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization
    end
  end
end
```

### With Strategy Options

```ruby
config.after_initialize do
  # Path-based (default): /organizations/:organization_id/posts
  scope_to_entity Organization, strategy: :path

  # Custom param key
  scope_to_entity Organization, strategy: :path, param_key: :org_id
end
```

See the [Multi-tenancy Guide](/guides/multi-tenancy) for complete documentation.

## Routing

### Mounting the Portal

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount AdminPortal::Engine, at: "/admin"
end
```

### Portal Routes

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  resources :posts
  resources :users

  # Nested routes
  resources :posts do
    resources :comments
  end

  # Custom routes
  get "dashboard", to: "dashboard#index"
end
```

### Root Route

```ruby
AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"

  resources :posts
end
```

## Controllers

### Resource Controllers

Portal-specific controllers inherit from the feature package's controller and include the portal's controller concern:

```ruby
# packages/admin_portal/app/controllers/admin_portal/posts_controller.rb
class AdminPortal::PostsController < ::PostsController
  include AdminPortal::Concerns::Controller

  private

  def build_resource
    super.tap do |post|
      post.user = current_user
    end
  end
end
```

Controllers are auto-created if not defined. When accessing `AdminPortal::PostsController`, Plutonium will dynamically create it by inheriting from `::PostsController` and including `AdminPortal::Concerns::Controller`.

## Portal-Specific Overrides

### Definitions

```ruby
# packages/admin_portal/app/definitions/admin_portal/post_definition.rb
module AdminPortal
  class PostDefinition < ::PostDefinition
    # Add admin-only fields
    field :internal_notes
    field :moderation_status

    # Admin-only action
    action :feature, interaction: FeaturePost
  end
end
```

### Policies

```ruby
# packages/admin_portal/app/policies/admin_portal/post_policy.rb
module AdminPortal
  class PostPolicy < ::PostPolicy
    # Admins can do everything
    def update?
      true
    end

    def destroy?
      true
    end

    def relation_scope(relation)
      relation  # No restrictions
    end
  end
end
```

### Views

```ruby
# packages/admin_portal/app/views/admin_portal/posts/index_page.rb
module AdminPortal
  module Posts
    class IndexPage < Plutonium::UI::Page::Index
      def page_title
        "Manage Posts"
      end
    end
  end
end
```

## Layouts

### Custom Layout

```ruby
# packages/admin_portal/app/views/layouts/admin_portal/application.rb
module AdminPortal
  class ApplicationLayout < Plutonium::UI::Layout::Application
    def render_logo
      img(src: asset_path("admin-logo.svg"), class: "h-8")
    end

    def nav_items
      [
        { label: "Dashboard", path: admin_root_path, icon: Phlex::TablerIcons::Home },
        { label: "Posts", path: admin_posts_path, icon: Phlex::TablerIcons::FileText },
        { label: "Users", path: admin_users_path, icon: Phlex::TablerIcons::Users }
      ]
    end

    def render_user_menu
      div(class: "flex items-center gap-4") do
        span(class: "text-sm") { current_user.email }
        link_to "Logout", logout_path, class: "text-gray-500 hover:text-gray-700"
      end
    end
  end
end
```

## Public Routes

To allow unauthenticated access to specific actions:

```ruby
class AdminPortal::PagesController < AdminPortal::PlutoniumController
  skip_before_action :authenticate, only: [:health]

  def health
    render json: { status: "ok" }
  end
end
```

## Dashboard

### Dashboard Controller

```ruby
# packages/admin_portal/app/controllers/admin_portal/dashboard_controller.rb
module AdminPortal
  class DashboardController < PlutoniumController
    def index
      @stats = {
        posts: Post.count,
        users: User.count,
        comments: Comment.count
      }
    end
  end
end
```

### Dashboard View

```ruby
# packages/admin_portal/app/views/admin_portal/dashboard/index_page.rb
module AdminPortal
  module Dashboard
    class IndexPage < Plutonium::UI::Page::Base
      def initialize(stats:)
        @stats = stats
      end

      def view_template
        h1(class: "text-2xl font-bold mb-6") { "Dashboard" }

        div(class: "grid grid-cols-3 gap-6") do
          @stats.each do |label, value|
            stat_card(label.to_s.titleize, value)
          end
        end
      end

      private

      def stat_card(label, value)
        div(class: "bg-white rounded-lg shadow p-6") do
          p(class: "text-gray-500 text-sm") { label }
          p(class: "text-3xl font-bold") { value.to_s }
        end
      end
    end
  end
end
```

## Configuration Options

### Engine Options

| Option | Description |
|--------|-------------|
| `scope_to_entity` | Entity class for multi-tenancy scoping |

### Controller Concern Options

| Include | Description |
|---------|-------------|
| `Plutonium::Auth::Rodauth(:name)` | Authenticate with Rodauth account type |
| `Plutonium::Auth::Public` | No authentication required |

## Related

- [Authentication Guide](/guides/authentication)
- [Multi-tenancy Guide](/guides/multi-tenancy)
