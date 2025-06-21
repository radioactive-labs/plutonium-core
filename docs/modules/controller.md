---
title: Controller Module
---

# Controller Module

The Controller module is your gateway to handling HTTP requests in Plutonium applications. It combines Rails' ActionController with Plutonium-specific enhancements to create a powerful, convention-over-configuration approach that eliminates boilerplate while providing enterprise-grade features like authorization and multi-tenancy.

::: tip Module Organization
Controller functionality is distributed across multiple focused modules:
- `lib/plutonium/core/controller.rb` - Foundation and core utilities
- `lib/plutonium/resource/controller.rb` - Complete CRUD operations
- `lib/plutonium/portal/controller.rb` - Portal-specific features and multi-tenancy
:::

## Core Philosophy

Plutonium's controller system is built on three fundamental principles:

- **Convention over Configuration**: Intelligent defaults that work out of the box with minimal setup
- **Modular Architecture**: Mix and match functionality based on your needs
- **Enterprise Readiness**: Built-in authentication, authorization and multi-tenancy

## Understanding Resource Registration

Before diving into controllers, it's crucial to understand how Plutonium connects your resources to the web through registration and routing.

### Registering Resources

Resources must be registered with each portal to become accessible through the web interface:

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"

  # Basic resource registration
  register_resource User
  register_resource Post
  register_resource Comment

  # Advanced registration with options
  register_resource Profile, singular: true  # Creates singular routes
  register_resource Report do
    # Add custom routes alongside the standard ones
    member do
      get :download
      post :regenerate
    end
  end
end
```

### What Registration Gives You

When you register a resource, Plutonium automatically creates:

1. **Complete CRUD routes**: All standard RESTful endpoints
2. **Nested association routes**: Based on your model's `has_many` relationships
3. **Interactive action routes**: For custom business operations
4. **Entity-scoped routes**: If your portal uses multi-tenancy

```ruby
# This simple registration:
register_resource Post

# Automatically generates:
# GET    /posts                    # index - list all posts
# GET    /posts/new                # new - form for creating posts
# POST   /posts                    # create - handle post creation
# GET    /posts/:id                # show - display a specific post
# GET    /posts/:id/edit           # edit - form for editing posts
# PATCH  /posts/:id                # update - handle post updates
# DELETE /posts/:id                # destroy - delete posts

# Plus interactive action routes:
# GET    /posts/resource_actions/:interactive_action     # Resource-level actions
# POST   /posts/resource_actions/:interactive_action
# GET    /posts/:id/record_actions/:interactive_action   # Individual record actions
# POST   /posts/:id/record_actions/:interactive_action

# Plus nested routes for associations (if Post has_many :comments):
# GET    /posts/:post_id/nested_comments
```

### Entity Scoping in Routes

If your portal is scoped to an entity (like Organization), all routes are automatically nested:

```ruby
# Engine configuration
class AdminPortal::Engine < Rails::Engine
  include Plutonium::Portal::Engine
  scope_to_entity Organization, strategy: :path
end

# Your routes become:
# GET    /:organization_id/posts
# GET    /:organization_id/posts/:id
# All data is automatically scoped to the organization
```

## Controller Components

### Base Controller: The Foundation

Every Plutonium controller starts with `Plutonium::Core::Controller`, which provides essential framework integration:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Plutonium::Core::Controller

  # You now have access to all Plutonium controller features
end
```

**Key Capabilities:**
- **Smart URL Generation**: Automatic resource URL creation with proper routing
- **Enhanced Flash Messages**: Extended message types (`:success`, `:warning`, `:error`)
- **View Integration**: Automatic view path resolution and layout management
- **Resource Management**: Access to registered resources and metadata

**Essential Methods:**
```ruby
# URL generation that understands your resource structure
resource_url_for(@user)                    # => "/users/1"
resource_url_for(@user, action: :edit)     # => "/users/1/edit"
resource_url_for(User)                     # => "/users"

# Build complex URL arguments for nested resources
resource_url_args_for(@user, Post)         # => {controller: "/users/posts", user_id: 1}

# Access application metadata
registered_resources                       # => [User, Post, Comment, ...]

# Page title management
set_page_title("User Profile")
make_page_title("Dashboard")               # => "Dashboard | MyApp"
```

### Resource Controller: Complete CRUD Operations

The Resource Controller provides full CRUD functionality with zero configuration:

```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  # That's it! All CRUD actions are automatically available:
  # index, show, new, create, edit, update, destroy
end
```

**What You Get Automatically:**
- **Complete CRUD Operations**: All RESTful actions implemented
- **Smart Parameter Handling**: Automatic parameter processing and validation
- **Authorization Integration**: Policy checks on every action
- **Query Integration**: Automatic filtering, searching, and sorting
- **Interaction Support**: Business logic through interaction classes
- **Nested Resource Support**: Handles parent-child relationships automatically
- **Pagination**: Built-in pagination with sensible defaults

**Key Methods Available:**
```ruby
# Resource management
resource_class                    # => Post
resource_record!                  # => @post (raises if not found)
resource_record?                  # => @post or nil
current_parent                    # => parent record for nested routes

# Parameter handling with automatic authorization
resource_params                   # => processed params with proper scoping
submitted_resource_params         # => raw submitted parameters

# View builders for consistent UI
build_form                        # => form builder for the resource
build_detail                      # => detail view builder
build_collection                  # => collection view builder

# Query objects for data access
current_query_object              # => handles filtering, searching, sorting
```

### Portal Controller: Multi-Tenancy and Segmentation

Portal Controllers provide specialized functionality for multi-tenant applications and user segmentation:

```ruby
module AdminPortal
  class PostsController < PlutoniumController
    include AdminPortal::Concerns::Controller

    # Automatically inherits from ::PostsController
    # Includes portal-specific concerns and scoping
  end
end
```

## Controller Concerns: Modular Functionality

Plutonium's controller system uses several modular concerns that provide specific capabilities:

### Bootable: Initialization and Setup

Handles the foundational setup that makes everything work smoothly:

```ruby
# Automatically included - provides:
# ✓ Package detection and engine resolution
# ✓ View path configuration for proper template loading
# ✓ Flash message type registration

# Available methods:
current_package                   # => current package module (e.g., AdminPortal)
current_engine                    # => current Rails engine instance
```

### Entity Scoping: Multi-Tenancy Made Simple

Provides powerful multi-tenancy capabilities with automatic data scoping:

```ruby
# Check if the controller is scoped to an entity
scoped_to_entity?                 # => true/false

# Get the current scoped entity
current_scoped_entity             # => current organization/tenant

# Access scoping configuration
scoped_entity_strategy            # => :path, :subdomain, :custom_method
scoped_entity_param_key           # => :organization_id
scoped_entity_class               # => Organization
```

#### Setting Up Entity Scoping

Configure scoping at the engine level and implement custom strategies as needed:

```ruby
# 1. Configure in your engine
class AdminPortal::Engine < Rails::Engine
  include Plutonium::Portal::Engine

  # Path-based scoping (URLs like /organizations/123/posts)
  scope_to_entity Organization, strategy: :path

  # Or custom strategy for more control
  scope_to_entity Organization, strategy: :current_organization
end

# 2. For custom strategies, implement the method in your controller concern
module AdminPortal::Concerns::Controller
  private

  # Method name MUST match the strategy name exactly
  def current_organization
    # Custom logic - could be subdomain, session, JWT, etc.
    @current_organization ||= begin
      # Primary: subdomain lookup
      Organization.find_by(subdomain: request.subdomain) ||
      # Fallback: session-based lookup
      current_user.organizations.find(session[:org_id])
    end
  end
end
```

### Authorizable: Comprehensive Security

Integrates with ActionPolicy to provide robust authorization throughout your application:

```ruby
# Authorization methods that work automatically
authorize_current!(resource_record!)     # Check permissions for current resource
authorize_current!(resource_class)       # Check permissions for resource class
authorize_current!(record, to: :interactive_action?) # Check specific action permission

# Policy access and queries
current_policy                           # Get policy for current resource
current_policy.allowed_to?(:show?)       # Check if action is allowed
policy_for(@user)                        # Get policy for specific resource
authorized_resource_scope(User)          # Get authorized scope for resource class

# Permission helpers
permitted_attributes                     # Get allowed attributes for current action
permitted_associations                   # Get allowed associations
```

**Authorization Examples:**
```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  def index
    # Authorization is automatically checked against PostPolicy#index?
    # No additional code needed
  end

  def custom_publish
    # Check custom permissions
    authorize_current!(resource_record!, to: :publish?)

    # Your business logic here
    PublishPostInteraction.call(post: resource_record!)

    redirect_to resource_url_for(resource_record!), success: "Post published!"
  end

  def conditional_action
    # Check permissions before taking action
    if current_policy.allowed_to?(:edit?)
      redirect_to resource_url_for(resource_record!, action: :edit)
    else
      redirect_to resource_url_for(resource_record!),
                  warning: "You don't have permission to edit this post"
    end
  end

  private

  def resource_params
    # Only permit attributes that the policy allows
    params.require(:post).permit(*permitted_attributes)
  end
end
```

## Advanced Usage Patterns


### Nested Resources: Automatic Relationship Handling

Plutonium automatically handles nested resources based on your ActiveRecord associations:

```ruby
# Your models define the relationships
class User < ResourceRecord
  has_many :posts
  has_many :comments
end

class Post < ResourceRecord
  belongs_to :user
  has_many :comments
end

# Register resources normally
AdminPortal::Engine.routes.draw do
  register_resource User
  register_resource Post
  register_resource Comment
end

# Plutonium automatically creates nested routes:
# /users/:user_id/nested_posts
# /users/:user_id/nested_comments
# /posts/:post_id/nested_comments
```

**Automatic Parent Resolution:**
```ruby
# In a nested route like /users/123/nested_posts/456
current_parent           # => User.find(123) - automatically resolved
parent_route_param       # => :user_id
parent_input_param       # => :user (the belongs_to association name)

# Parameters are automatically merged
resource_params          # => includes user: current_parent
```

**Smart URL Generation:**
```ruby
# From within a nested controller context
resource_url_for(Post)                    # => "/users/123/nested_posts"
resource_url_for(@post)                   # => "/users/123/nested_posts/456"
resource_url_for(@post, action: :edit)    # => "/users/123/nested_posts/456/edit"

# Explicit parent specification
resource_url_for(Post, parent: @user)     # => "/users/123/nested_posts"
```

### Multi-Format Response Handling

Plutonium automatically handles different response formats for you.
It currently supports HTML, JSON, and Turbo Streams.

## Related Modules

The Controller module works seamlessly with other Plutonium components:

- **[Core](./core.md)**: Foundation and essential utilities
- **[Resource](./resource.md)**: CRUD operations and resource management
- **[Portal](./portal.md)**: Multi-tenant portal functionality
- **[Authentication](./authentication.md)**: User authentication and session management
- **[Policy](./policy.md)**: Authorization and access control
- **[Interaction](./interaction.md)**: Business logic encapsulation
- **[Routing](./routing.md)**: Resource registration and route generation
