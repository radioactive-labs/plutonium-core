---
title: Core Module
---

# Core Module

The Core module (`Plutonium::Core::Controller`) provides the foundational controller functionality that all Plutonium applications depend on. It's a lean, focused module that handles essential framework integration, URL generation, and controller bootstrapping.

::: tip
The Core module is automatically included when you use `Plutonium::Resource::Controller` or `Plutonium::Portal::Controller`. You typically don't include it directly.
:::

## What the Core Module Provides

The Core module includes three essential controller concerns:

- **Bootable**: Package and engine detection with automatic view path configuration
- **EntityScoping**: Multi-tenancy support with entity-based scoping
- **Authorizable**: ActionPolicy integration for authorization

## Core Controller Features

### Smart URL Generation

The Core module provides intelligent URL generation that works with Plutonium's package system and entity scoping:

```ruby
# Generate URLs for resources with proper routing context
resource_url_for(@user)                    # => "/users/1"
resource_url_for(@user, action: :edit)     # => "/users/1/edit"
resource_url_for(User)                     # => "/users"

# Handle nested resources and packages
resource_url_for(@user, Post)              # => "/users/1/posts"
resource_url_for(@post, parent: @user)     # => "/users/1/posts/1"

# Build URL arguments for complex routing scenarios
args = resource_url_args_for(@user, Post)
# => {controller: "/users/posts", user_id: 1}
```

### Enhanced Flash Messages

Extends Rails' default flash types with additional semantic types:

```ruby
# Available flash types: :notice, :alert, :success, :warning, :error
redirect_to posts_path, success: "Post created successfully!"
redirect_to posts_path, warning: "Post saved with warnings"
redirect_to posts_path, error: "Failed to save post"
```

### Helper Methods

The Core module provides several helper methods available in controllers and views:

```ruby
# Page title management
set_page_title("Dashboard")
make_page_title("Users") # => "Users | App Name"

# Package and engine information
current_package  # => AdminPortal (if in a package)
current_engine   # => AdminPortal::Engine

# Resource registry access
registered_resources # => Array of registered resource classes

# Application branding
app_name # => Your application name
```

## Package Integration (Bootable)

The Bootable concern automatically detects which package and engine a controller belongs to:

```ruby
# In packages/admin_portal/app/controllers/users_controller.rb
class UsersController < PlutoniumController
  # Automatically detects:
  # current_package => AdminPortal
  # current_engine  => AdminPortal::Engine

  # View paths automatically configured:
  # - packages/admin_portal/app/views (prepended)
  # - app/views (Rails default)
end
```

### Automatic View Path Configuration

Each package gets its own view path automatically prepended:

```ruby
# For AdminPortal::UsersController
# View lookup order:
# 1. packages/admin_portal/app/views/users/
# 2. packages/admin_portal/app/views/
# 3. app/views/users/
# 4. app/views/
```

## Entity Scoping (Multi-tenancy)

The EntityScoping concern provides multi-tenancy support when configured:

```ruby
# In your engine configuration
class AdminPortal::Engine < Rails::Engine
  include Plutonium::Portal

  # Enable entity scoping
  scope_to_entity Organization, strategy: :path
end
```

### Available Scoping Methods

When entity scoping is enabled:

```ruby
# Check if scoped to an entity
scoped_to_entity? # => true/false

# Get current scoped entity
current_scoped_entity # => #<Organization id: 1>

# Get scoping configuration
scoped_entity_strategy    # => :path
scoped_entity_param_key   # => :organization_id
scoped_entity_class       # => Organization
```

### Entity Scoping Strategies

**Path Strategy** (most common):
```ruby
# URLs include entity parameter: /organizations/1/users
scope_to_entity Organization, strategy: :path
```

**Custom Strategy**:
```ruby
# Define your own scoping method
scope_to_entity Organization, strategy: :current_organization

private

def current_organization
  current_user.organization
end
```

## Authorization Integration (Authorizable)

The Authorizable concern integrates ActionPolicy for authorization:

```ruby
# Authorization is automatically configured with:
authorize :user, through: :current_user
authorize :entity_scope, through: :entity_scope_for_authorize

# Helper methods available:
policy_for(@user)                    # Get policy for record
authorized_resource_scope(User)      # Get authorized scope
```

### Authorization Context

The Core module provides entity scoping context for authorization:

```ruby
# In your policies, you can access:
class UserPolicy < ApplicationPolicy
  def index?
    # entity_scope is automatically available
    user.admin? || entity_scope == user.organization
  end
end
```

## Framework Integration

### ActiveStorage Integration

Automatically configures ActiveStorage URL options:

```ruby
# Configured in before_action
ActiveStorage::Current.url_options = {
  protocol: request.protocol,
  host: request.host,
  port: request.port
}
```

### Layout Configuration

Sets up dynamic layout selection:

```ruby
# Automatically uses 'resource' layout unless in Turbo Frame
layout -> { turbo_frame_request? ? false : "resource" }
```

### Helper Integration

Includes all Plutonium helpers:

```ruby
helper Plutonium::Helpers
# Includes: ApplicationHelper, AttachmentHelper, ContentHelper,
#          DisplayHelper, TableHelper, TurboHelper, etc.
```

## Usage Patterns

### Basic Controller Setup

The Core module is typically used through other Plutonium modules:

```ruby
# For resource controllers
class UsersController < PlutoniumController
  include Plutonium::Resource::Controller
  # Core module included automatically
end

# For portal controllers
class DashboardController < PlutoniumController
  include Plutonium::Portal::Controller
  # Core module included automatically
end
```

### Direct Usage (Advanced)

If you need just the core functionality:

```ruby
class CustomController < ApplicationController
  include Plutonium::Core::Controller

  def index
    set_page_title("Custom Page")
    # Core functionality available
  end
end
```

## Configuration

The Core module respects Plutonium's main configuration:

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  # These affect Core module behavior:
  config.development = Rails.env.development?
  config.cache_discovery = !Rails.env.development?
end
```

## Best Practices

### URL Generation

Always use `resource_url_for` instead of Rails' `url_for` for Plutonium resources:

```ruby
# ✅ Good - respects packages and entity scoping
resource_url_for(@user)

# ❌ Avoid - doesn't understand Plutonium routing
user_url(@user)
```

### Page Titles

Set page titles in controller actions for consistent branding:

```ruby
def show
  set_page_title(resource_record!.to_label)
  # Automatically becomes "User Name | App Name"
end
```

### Package Organization

Let the Bootable concern handle package detection automatically:

```ruby
# ✅ Good - automatic detection
class AdminPortal::UsersController < PlutoniumController
  # Package and engine automatically detected
end

# ❌ Avoid - manual configuration
class UsersController < PlutoniumController
  def current_package
    AdminPortal # Don't override unless necessary
  end
end
```

## Integration with Other Modules

- **[Resource](./resource.md)** - Builds on Core for full CRUD functionality
- **[Portal](./portal.md)** - Uses Core for multi-tenant portal applications
- **[Routing](./routing.md)** - Works with Core's URL generation methods
- **[Auth](./auth.md)** - Integrates with Core's authorization system

The Core module provides a solid, focused foundation that other Plutonium modules build upon, handling the essential plumbing that makes the framework's conventions work seamlessly.
