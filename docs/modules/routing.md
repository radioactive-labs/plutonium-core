---
title: Routing Module
---

# Routing Module

Plutonium's routing system transforms the way you think about Rails routing. Instead of manually defining dozens of routes, you simply register your resources and Plutonium automatically generates comprehensive routing structures including CRUD operations, nested associations, interactive actions, and multi-tenant scoping.

::: tip
The Routing module is located in `lib/plutonium/routing/` and seamlessly extends Rails' built-in routing system.
:::

## The Routing Revolution

Traditional Rails routing requires you to manually define every route, leading to repetitive, error-prone route files. Plutonium's approach is radically different:

**Traditional Rails Approach:**
```ruby
# Lots of manual route definition
resources :posts do
  member do
    post :publish
    post :archive
  end

  resources :comments, except: [:new, :edit]
end

resources :users do
  resources :posts, controller: 'users/posts'
  resources :comments, controller: 'users/comments'
end
```

**Plutonium Approach:**
```ruby
# Simple, declarative registration
register_resource Post
register_resource Comment
register_resource User

# Plutonium automatically generates:
# - All CRUD routes
# - Nested association routes
# - Interactive action routes
# - Multi-tenant scoped routes
```

## Core Routing Principles

Plutonium's routing system is built on four fundamental concepts:

- **Declarative Registration**: Register resources instead of defining individual routes
- **Intelligent Generation**: Routes are created based on your model associations and definitions
- **Entity Scoping**: Automatic multi-tenant routing with parameter injection
- **Interactive Actions**: Dynamic routes for business operations and user interactions

## Resource Registration: The Foundation

### Basic Resource Registration

The heart of Plutonium routing is the `register_resource` method:

```ruby
# packages/admin_portal/config/routes.rb
AdminPortal::Engine.routes.draw do
  root to: "dashboard#index"

  # Register your resources - that's it!
  register_resource User
  register_resource Post
  register_resource Comment
end
```

### What Registration Creates

When you register a single resource, Plutonium automatically generates:

```ruby
register_resource Post

# Standard CRUD routes:
# GET    /posts                    # index - list all posts
# GET    /posts/new                # new - form for creating posts
# POST   /posts                    # create - handle post creation
# GET    /posts/:id                # show - display specific post
# GET    /posts/:id/edit           # edit - form for editing posts
# PATCH  /posts/:id                # update - handle post updates
# PUT    /posts/:id                # update - alternative update method
# DELETE /posts/:id                # destroy - delete posts

# Interactive action routes:
# GET    /posts/resource_actions/:action     # Resource-level operations
# POST   /posts/resource_actions/:action     # Execute resource operations
# GET    /posts/:id/record_actions/:action   # Individual record operations
# POST   /posts/:id/record_actions/:action   # Execute record operations
# GET    /posts/bulk_actions/:action         # Bulk operations on multiple records
# POST   /posts/bulk_actions/:action         # Execute bulk operations

# Nested association routes (if Post has_many :comments):
# GET    /posts/:post_id/nested_comments     # Comments belonging to a post
# GET    /posts/:post_id/nested_comments/:id # Specific comment in context
```

### Advanced Registration Options

#### Singular Resources

For resources that don't need collection routes:

```ruby
register_resource Profile, singular: true

# Generates singular routes:
# GET    /profile          # show
# GET    /profile/new      # new
# POST   /profile          # create
# GET    /profile/edit     # edit
# PATCH  /profile          # update
# DELETE /profile          # destroy
```

#### Custom Routes with Blocks

Add custom routes alongside the standard ones:

```ruby
register_resource Post do
  # Member routes (operate on specific posts)
  member do
    get :publish      # GET /posts/1/publish
    post :archive     # POST /posts/1/archive
    patch :featured   # PATCH /posts/1/featured
  end

  # Collection routes (operate on post collection)
  collection do
    get :search       # GET /posts/search
    get :recent       # GET /posts/recent
    post :bulk_update # POST /posts/bulk_update
  end

  # Nested resources for complex relationships
  resources :comments, only: [:index, :show]

  # Alternative syntax for single routes
  get :preview, on: :member  # GET /posts/1/preview
end
```

**Handling Custom Routes in Controllers:**
```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  # Custom member actions
  def publish
    authorize_current!(resource_record!)
    resource_record!.update!(published: true)
    redirect_to resource_url_for(resource_record!), success: "Post published!"
  end

  def archive
    authorize_current!(resource_record!)
    resource_record!.update!(archived: true)
    redirect_to resource_url_for(resource_class), success: "Post archived!"
  end

  # Custom collection actions
  def search
    authorize_current!(resource_class)
    @query = params[:q]
    @posts = resource_scope.where("title ILIKE ?", "%#{@query}%")
    render :index
  end
end
```

## Automatic Nested Resource Generation

One of Plutonium's most powerful features is automatic nested route generation based on your ActiveRecord associations.

### How Association-Based Routing Works

```ruby
# Define your model associations
class User < ApplicationRecord
  include Plutonium::Resource::Record

  has_many :posts
  has_many :comments
  has_many :projects
end

class Post < ApplicationRecord
  include Plutonium::Resource::Record

  belongs_to :user
  has_many :comments
end

# Register resources normally
AdminPortal::Engine.routes.draw do
  register_resource User
  register_resource Post
  register_resource Comment
end
```

**Plutonium automatically generates nested routes:**
```ruby
# User's nested resources:
# GET /users/:user_id/nested_posts           # User's posts
# GET /users/:user_id/nested_posts/:id       # Specific post by user
# GET /users/:user_id/nested_comments        # User's comments
# GET /users/:user_id/nested_projects        # User's projects

# Post's nested resources:
# GET /posts/:post_id/nested_comments        # Post's comments
# GET /posts/:post_id/nested_comments/:id    # Specific comment on post
```

### Nested Route Naming Convention

Nested routes use the `nested_#{resource_name}` pattern to avoid conflicts:

- **Standard route**: `/posts` → `PostsController#index`
- **Nested route**: `/users/:user_id/nested_posts` → `PostsController#index` (with `current_parent`)

### Automatic Parent Resolution

Controllers automatically handle parent relationships in nested contexts:

```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  def index
    # When accessed via /users/123/nested_posts
    current_parent           # => User.find(123) - automatically resolved
    parent_route_param       # => :user_id
    parent_input_param       # => :user (the belongs_to association name)

    # Parameters are automatically merged for creation
    resource_params          # => includes user: current_parent

    # URLs automatically include parent context
    resource_url_for(Post)   # => "/users/123/nested_posts"
    resource_url_for(@post)  # => "/users/123/nested_posts/456"
  end
end
```

## Entity Scoping: Multi-Tenant Routing

Entity scoping automatically transforms your routes to support multi-tenancy, where all data is scoped to a parent entity like Organization or Account.

### Path-Based Scoping

The most common approach uses URL path parameters:

```ruby
# Engine configuration
class AdminPortal::Engine < Rails::Engine
  include Plutonium::Portal::Engine

  scope_to_entity Organization, strategy: :path
end
```

**Route Transformation:**
```ruby
# Without scoping:
# GET /posts
# GET /posts/:id

# With path scoping:
# GET /:organization_id/posts
# GET /:organization_id/posts/:id
```

### Custom Scoping Strategies

For more sophisticated multi-tenancy patterns:

```ruby
# Subdomain-based scoping
scope_to_entity Organization, strategy: :current_organization

# Custom parameter key
scope_to_entity Organization,
  strategy: :path,
  param_key: :org_slug

# Routes become: GET /:org_slug/posts
```

**Required Controller Implementation:**
```ruby
module AdminPortal::Concerns::Controller
  private

  # Method name MUST match the strategy name exactly
  def current_organization
    @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, error: "Invalid organization"
  end
end
```

### Entity Scoping with Nested Routes

Scoping applies to both standard and nested routes:

```ruby
scope_to_entity Organization, strategy: :path

# Standard scoped routes:
# GET /:organization_id/users
# GET /:organization_id/posts

# Nested scoped routes:
# GET /:organization_id/users/:user_id/nested_posts
# GET /:organization_id/posts/:post_id/nested_comments
```

## Smart URL Generation

Plutonium provides intelligent URL generation that handles scoping, nesting, and context automatically.

### The `resource_url_for` Method

This is your go-to method for generating resource URLs:

```ruby
# Basic usage
resource_url_for(User)                      # => "/users"
resource_url_for(@user)                     # => "/users/123"
resource_url_for(@user, action: :edit)      # => "/users/123/edit"

# With entity scoping
resource_url_for(@user)                     # => "/organizations/456/users/123"

# Nested resources
resource_url_for(Post, parent: @user)       # => "/users/123/nested_posts"
resource_url_for(@post, parent: @user)      # => "/users/123/nested_posts/789"

# Override parent context
resource_url_for(@post, parent: nil)        # => "/posts/789"

# Different actions
resource_url_for(@post, action: :edit, parent: @user)
# => "/users/123/nested_posts/789/edit"
```

### Interactive Action URLs

Special URL generation for interactive actions:

```ruby
# Record-level actions (operate on specific records)
record_action_url(@post, :publish)
# => "/posts/123/record_actions/publish"

# Resource-level actions (operate on the resource class)
resource_action_url(Post, :import)
# => "/posts/resource_actions/import"

# Bulk actions (operate on multiple records)
bulk_action_url(Post, :archive, ids: [1, 2, 3])
# => "/posts/bulk_actions/archive?ids[]=1&ids[]=2&ids[]=3"
```

### Context-Aware URL Generation

In nested controller contexts, URLs automatically include proper context:

```ruby
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  def show
    # When accessed via /users/123/nested_posts/456

    # These automatically include the user context:
    resource_url_for(Post)                  # => "/users/123/nested_posts"
    resource_url_for(@post, action: :edit)  # => "/users/123/nested_posts/456/edit"

    # Parent is automatically detected:
    current_parent                          # => User.find(123)
  end
end
```

## Advanced Routing Patterns

### Multiple Engine Mounting

Different engines can have different routing strategies:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Admin portal with organization scoping
  constraints Rodauth::Rails.authenticate(:admin) do
    mount AdminPortal::Engine, at: "/admin"
  end

  # Customer portal with account scoping
  constraints Rodauth::Rails.authenticate(:customer) do
    mount CustomerPortal::Engine, at: "/app"
  end

  # Public portal with no scoping or authentication
  mount PublicPortal::Engine, at: "/"
end
```

### Route Constraints and Conditions

```ruby
Rails.application.routes.draw do
  # Subdomain-based portal mounting
  constraints subdomain: 'admin' do
    mount AdminPortal::Engine, at: "/"
  end

  # Feature flag-based mounting
  constraints ->(request) { FeatureFlag.enabled?(:beta_portal) } do
    mount BetaPortal::Engine, at: "/beta"
  end

  # IP-based constraints for admin access
  constraints ip: /192\.168\.1\.\d+/ do
    mount AdminPortal::Engine, at: "/secure-admin"
  end
end
```

### Route Generation Lifecycle

Understanding how Plutonium generates routes helps with debugging:

**1. Registration Phase:**
```ruby
register_resource Post
# - Resource is registered with the engine
# - Route configuration is created and stored
# - Concern name is generated (posts_routes)
```

**2. Route Definition Phase:**
```ruby
concern :posts_routes do
  resources :posts, controller: "posts", concerns: [:interactive_resource_actions] do
    # Nested routes for has_many associations
    resources "nested_comments", controller: "comments"
  end
end
```

**3. Route Materialization Phase:**
```ruby
scope :organization_id, as: :organization_id do
  concerns :posts_routes, :comments_routes, :users_routes
end
# - All registered concerns are materialized within appropriate scope
# - Entity scoping parameters are applied
# - Final route table is generated
```

## Debugging and Troubleshooting

### Inspecting Generated Routes

```ruby
# View all routes for an engine
AdminPortal::Engine.routes.routes.each do |route|
  puts "#{route.verb.ljust(6)} #{route.path.spec}"
end

# View registered resources
AdminPortal::Engine.resource_register.resources
# => [User, Post, Comment]

# View route configurations
AdminPortal::Engine.routes.resource_route_config_lookup
# => { "posts" => {...}, "users" => {...} }

# Check available route helpers
AdminPortal::Engine.routes.url_helpers.methods.grep(/path|url/)
```

### Common Issues and Solutions

**Missing Nested Routes:**
```ruby
# Ensure the association exists
User.reflect_on_association(:posts)  # Should not be nil

# Check association route discovery
User.has_many_association_routes     # Should include "posts"
```

**Incorrect Entity Scoping:**
```ruby
# Verify engine configuration
AdminPortal::Engine.scoped_to_entity?     # => true
AdminPortal::Engine.scoped_entity_class   # => Organization
AdminPortal::Engine.scoped_entity_strategy # => :path
```

**Interactive Action Routes Missing:**
```ruby
# Ensure action is defined in resource definition
PostDefinition.new.defined_actions.keys  # Should include your action
```

**Route Helper Not Found:**
```ruby
# Include the engine's route helpers
include AdminPortal::Engine.routes.url_helpers

# Test URL generation
posts_path  # => "/posts" or "/organizations/:organization_id/posts"
```

## Best Practices

### Route Organization

**Register Resources Logically:**
```ruby
# ✅ Good - logical grouping
AdminPortal::Engine.routes.draw do
  # Core entities first
  register_resource Organization
  register_resource User

  # Business domain resources
  register_resource Project
  register_resource Task

  # Supporting resources
  register_resource Comment
  register_resource Attachment
end
```

**Leverage Entity Scoping:**
```ruby
# ✅ Good - consistent scoping strategy
class AdminPortal::Engine < Rails::Engine
  scope_to_entity Organization, strategy: :path
end

# All resources automatically scoped to organization
# Consistent URL structure: /:organization_id/resources
```

### Security Considerations

```ruby
# ✅ Good - proper scoping for multi-tenancy
scope_to_entity Organization, strategy: :path

# ✅ Good - route-level authentication
constraints Rodauth::Rails.authenticate(:admin) do
  mount AdminPortal::Engine, at: "/admin"
end

# ✅ Good - controller-level authorization
class PostsController < ApplicationController
  include Plutonium::Resource::Controller

  private

  def current_authorized_scope
    super.where(organization: current_scoped_entity)
  end
end
```

## Integration with Other Modules

### With Resource Module

Routes automatically integrate with resource definitions:

```ruby
class PostDefinition < Plutonium::Resource::Definition
  # These create interactive action routes automatically
  action :publish, interaction: PublishPostInteraction
  action :archive, interaction: ArchivePostInteraction
end
```

### With Portal Module

Portals provide routing contexts and scoping:

```ruby
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    # This affects all routes in this portal
    scope_to_entity Organization, strategy: :path
  end
end
```

### With Authentication Module

Routes can be protected by authentication constraints:

```ruby
Rails.application.routes.draw do
  # Only authenticated admins can access admin routes
  constraints Rodauth::Rails.authenticate(:admin) do
    mount AdminPortal::Engine, at: "/admin"
  end

  # Customer authentication for customer portal
  constraints Rodauth::Rails.authenticate(:customer) do
    mount CustomerPortal::Engine, at: "/app"
  end
end
```

## Related Modules

The Routing module works seamlessly with other Plutonium components:

- **[Controller](./controller.md)**: HTTP request handling and URL generation methods
- **[Resource Record](./resource_record.md)**: Resource definitions that drive route generation
- **[Portal](./portal.md)**: Multi-tenant portal functionality and route scoping
- **[Action](./action.md)**: Interactive actions that create dynamic routes
- **[Authentication](./authentication.md)**: Route protection and authentication constraints
