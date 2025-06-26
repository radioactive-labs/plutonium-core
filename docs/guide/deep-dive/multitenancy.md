# Deep Dive: Multitenancy

Plutonium is designed to make building sophisticated, multi-tenant applications straightforward. Multitenancy allows you to serve distinct groups of users (like different companies or teams) from a single application instance, ensuring each group's data is kept private and isolated.

This is achieved through a powerful feature called **Entity Scoping**, which automates data isolation, URL generation, and authorization with minimal setup.

::: tip What You'll Learn
- The core concept of Entity Scoping
- A step-by-step guide to configuring multitenancy
- The practical benefits of automatic data isolation and routing
- Advanced patterns for complex multi-tenant scenarios
- Best practices for security, testing, and performance
:::

## How Entity Scoping Works

Entity Scoping is the heart of Plutonium's multitenancy. Instead of manually filtering data in every controller and model, you declare a **Scoping Entity** for a user-facing **Portal**. This entity is typically a model like `Organization`, `Account`, or `Workspace`.

Once configured, Plutonium handles the rest automatically.

::: code-group
```ruby [Without Plutonium Scoping]
# Manual filtering is required everywhere
class PostsController < ApplicationController
  def index
    # Manually find the organization and scope posts
    @organization = Organization.find(params[:organization_id])
    @posts = @organization.posts
  end

  def create
    # Manually associate new records with the organization
    @organization = Organization.find(params[:organization_id])
    @post = @organization.posts.build(post_params)
    # ...
  end
end
```

```ruby [With Plutonium Scoping]
# Scoping is automatic and declarative
class PostsController < ResourceController
  def index
    # current_authorized_scope automatically returns posts scoped to the current organization
    # When using path strategy: URL -> /organizations/123/posts
    # When using subdomain strategy: URL -> /posts (on acme.yourapp.com)
  end

  def create
    # resource_params automatically includes the current organization association
    # Scoping works regardless of the strategy used
  end
end
```
:::

## Setting Up Your Multi-Tenant Portal

Configuring multitenancy involves three main steps: defining your strategy, implementing it, and ensuring your models are correctly associated.

### 1. Configure Your Portal Engine

First, you tell your portal which entity to scope to and which strategy to use. This is done in the portal's `engine.rb` file using `scope_to_entity`.

A **Scoping Strategy** tells Plutonium how to identify the current tenant for each request.

::: code-group
```ruby [Path Strategy (Most Common)]
# packages/admin_portal/lib/engine.rb
# Tenant is identified by a URL parameter, e.g., /organizations/:organization_id
scope_to_entity Organization, strategy: :path
```

```ruby [Custom Strategy (Subdomain)]
# packages/customer_portal/lib/engine.rb
# Tenant is identified by the a custom strategy that checks the subdomain, e.g., acme.yourapp.com
scope_to_entity Organization, strategy: :current_organization
```

```ruby [Custom Parameter Key]
# packages/client_portal/lib/engine.rb
# Same as :path, but with a custom parameter name.
scope_to_entity Client,
  strategy: :path,
  param_key: :client_slug # URL -> /clients/:client_slug
```
:::

You can also use any custom name for your strategy method (the method name becomes the strategy).

### 2. Implement the Strategy Method

If you use any strategy other than `:path`, you must implement a controller method that returns the current tenant object. The method name must exactly match the strategy name.

This logic typically lives in your portal's base controller concern.

::: code-group
```ruby [Subdomain Strategy]
# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
private

# Method name :current_organization matches the strategy
def current_organization
  @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
rescue ActiveRecord::RecordNotFound
  redirect_to root_path, error: "Invalid organization subdomain"
end
```

```ruby [Session-Based Strategy]
# packages/internal_portal/app/controllers/internal_portal/concerns/controller.rb
# In engine.rb: scope_to_entity Workspace, strategy: :current_workspace
private

def current_workspace
  return @current_workspace if defined?(@current_workspace)

  workspace_id = session[:workspace_id] || params[:workspace_id]
  @current_workspace = current_user.workspaces.find(workspace_id)

  session[:workspace_id] = @current_workspace.id # Remember for next request
  @current_workspace
rescue ActiveRecord::RecordNotFound
  redirect_to workspace_selection_path, error: "Please select a workspace"
end
```
:::

### 3. Connect Your Models

Plutonium needs to understand how your resources relate to the scoping entity. It automatically discovers these relationships in three ways:

::: code-group
```ruby [1. Direct Association (Preferred)]
# The model belongs directly to the scoping entity.
class Post < ApplicationRecord
  belongs_to :organization # Direct link
end
```

```ruby [2. Indirect Association]
# The model belongs to another model that has the direct link.
# Plutonium automatically follows the chain: Comment -> Post -> Organization
class Comment < ApplicationRecord
  belongs_to :post
  has_one :organization, through: :post # Indirect link
end
```

```ruby [3. Custom Scope (For Complex Cases)]
# For complex relationships, you can define an explicit scope.
# The scope name must be `associated_with_#{scoping_entity_name}`.
class Invoice < ApplicationRecord
  belongs_to :customer

  scope :associated_with_organization, ->(organization) do
    joins(customer: :organization_memberships)
      .where(organization_memberships: { organization_id: organization.id })
  end
end
```
:::

## The Benefits in Practice

With this setup complete, you gain several powerful features across your portal.

### Tenant-Aware Routing

Your application's URLs are automatically transformed to include the tenant context, and Plutonium's URL helpers adapt accordingly.

- **URL Transformation:** Routes like `/posts` and `/posts/123` become `/:organization_id/posts` and `/:organization_id/posts/123`.
- **Automatic URL Generation:** The `resource_url_for` helper automatically includes the current tenant in all generated URLs, so links and forms work without any changes.

```ruby
# Both of these helpers are automatically aware of the current tenant.
resource_url_for(Post) # => "/organizations/456/posts"
form_with model: @post # action -> "/organizations/456/posts/123"
```

### Secure Data Scoping

All data access is automatically and securely filtered to the current tenant.

- **Query Scoping:** A query like `Post.all` is automatically converted to `current_scoped_entity.posts`. This prevents accidental data leaks.
- **Record Scoping:** When fetching a single record (e.g., for `show` or `edit`), Plutonium ensures it belongs to the current tenant. If not, it raises an `ActiveRecord::RecordNotFound` error, just as if the record didn't exist.

### Integrated Authorization

The current `entity_scope` is seamlessly passed to your authorization policies, allowing for fine-grained, tenant-aware rules.

```ruby
class PostPolicy < Plutonium::Resource::Policy
  # `entity_scope` is automatically available in all policy methods.
  authorize :entity_scope, allow_nil: true

  def update?
    # A user can only update a post if it belongs to their current tenant
    # AND they are the author of the post.
    record.organization == entity_scope && record.author == user
  end

  relation_scope do |relation|
    # `super` automatically applies the base entity scoping.
    relation = super(relation)

    # Add more logic: Admins can see all posts within their organization,
    # but others can only see published posts.
    user.admin? ? relation : relation.where(published: true)
  end
end
```

## Security Best Practices

Securing a multi-tenant application is critical. While Plutonium provides strong defaults, you must ensure your implementation is secure.

::: warning Always Validate Tenant Access
A user might belong to multiple tenants. It's crucial to verify that the logged-in user has permission to access the tenant specified in the URL. Failure to do so could allow a user to see data from another organization they don't belong to.
:::

```ruby
# ✅ Good: Proper tenant validation
# In your custom strategy method or a before_action:
private

def current_organization
  @current_organization ||= begin
    # Find the organization from the URL
    organization = Organization.find(params[:organization_id])

    # CRITICAL: Verify the current user is a member of that organization
    unless current_user.organizations.include?(organization)
      raise ActionPolicy::Unauthorized, "Access denied to organization"
    end

    organization
  end
end

# ❌ Dangerous: No access validation
def current_organization
  # This allows ANY authenticated user to access ANY organization's data
  # simply by changing the ID in the URL.
  Organization.find(params[:organization_id])
end
```

## Advanced Patterns

Plutonium's scoping is flexible enough to handle more complex scenarios.

- **Multi-Level Tenancy:** For hierarchical tenancy (e.g., Company -> Department), you can apply the primary scope at the engine level and add secondary scoping logic inside your policies' `relation_scope`.
- **Cross-Tenant Data Access:** For resources that can be shared, define a custom `associated_with_...` scope that includes both shared records and records belonging to the current tenant.
- **Tenant Switching:** Build a controller that allows users to change their active tenant by updating a `session` key, then use a session-based scoping strategy to read it.
- **API Multitenancy:** Create a custom scoping strategy (e.g., `:api_tenant`) that authenticates and identifies the tenant based on an API key or JWT from the request headers.
