# Plutonium Framework Development Guide

This guide helps AI agents understand and build Plutonium applications effectively. Plutonium is a Rails RAD framework that extends Rails conventions with application-level concepts.

## Quick Start

### New Application
```bash
rails new app_name -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

### Essential Commands
```bash
# Setup auth
rails generate pu:rodauth:install
rails generate pu:rodauth:account user

# Create feature + portal
rails generate pu:pkg:package blog_management
rails generate pu:pkg:portal admin_portal

# Create complete resource
rails generate pu:res:scaffold Post user:belongs_to title:string content:text --dest=blog_management

# Connect to portal
rails generate pu:res:conn BlogManagement::Post --dest=admin_portal
```

### Start Building
```bash
rails db:migrate
bin/dev  # Visit http://localhost:3000
```

## Core Concepts

### 1. Architecture
- **Packages**: Modular organization using Rails engines
  - **Feature Packages**: Contain business logic (models, interactions, policies)
  - **Portal Packages**: Provide web interfaces with authentication
- **Resources**: Complete CRUD entities with models, definitions, policies, controllers
- **Entity Scoping**: Built-in multi-tenancy support

### 2. Key Components
- **Models**: ActiveRecord + `Plutonium::Resource::Record` for enhanced functionality
- **Definitions**: Declarative UI configuration (how fields render)
- **Policies**: Authorization control (what users can access)
- **Interactions**: Business logic encapsulation (what actions do)
- **Controllers**: Auto-generated CRUD with customization points

## Essential Generators

### Project Setup
```bash
# New app with Plutonium template
rails new app_name -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb

# Add to existing app
rails generate pu:core:install
```

### Authentication Setup
```bash
# Install Rodauth
rails generate pu:rodauth:install

# Create user account with auth
rails generate pu:rodauth:account user

# Create admin account with enhanced security
rails generate pu:rodauth:admin admin

# Multi-tenant customer setup
rails generate pu:rodauth:customer Customer --entity=Organization
```

### Package Generators
```bash
# Create feature package for business logic
rails generate pu:pkg:package blog_management

# Create portal package for web interface
rails generate pu:pkg:portal admin_dashboard
```

### Resource Generators (Most Important)
```bash
# Complete resource scaffold (preferred) - use --dest for package
rails generate pu:res:scaffold Post user:belongs_to title:string content:text 'published_at:datetime?' --dest=blogging

# Referencing namespaced models in associations
rails generate pu:res:scaffold Comment user:belongs_to blogging/post:belongs_to body:text --dest=comments
rails generate pu:res:scaffold Order customer:belongs_to inventory/product:belongs_to quantity:integer --dest=commerce

# Model only - use --dest for package
rails generate pu:res:model Article title:string body:text author:belongs_to --dest=blogging
rails generate pu:res:model Review user:belongs_to inventory/product:belongs_to rating:integer --dest=reviews

# Connect resources to portals (can be non-interactive with explicit args)
rails generate pu:res:conn BlogManagement::Post BlogManagement::Comment --dest=admin_portal
# Or interactive mode (will prompt for selection)
rails generate pu:res:conn
```

### Other Useful Generators
```bash
# Entity for multi-tenancy
rails generate pu:res:entity Organization --auth-account=Customer

# Eject components for customization
rails generate pu:eject:layout --dest=admin_portal
rails generate pu:eject:shell --dest=admin_portal

# Development tools
rails generate pu:gem:annotated    # Model annotations
rails generate pu:gem:standard     # Ruby Standard linter
rails generate pu:gem:dotenv       # Environment variables
```

## File Structure Patterns

### Feature Package Structure
```
packages/blog_management/
├── lib/
│   └── engine.rb                           # Package engine
└── app/
    ├── models/blog_management/
    │   ├── post.rb                         # Business models
    │   └── resource_record.rb              # Base class
    ├── policies/blog_management/
    │   ├── post_policy.rb                  # Authorization rules
    │   └── resource_policy.rb              # Base policy
    ├── definitions/blog_management/
    │   ├── post_definition.rb              # UI configuration
    │   └── resource_definition.rb          # Base definition
    ├── interactions/blog_management/
    │   └── post_interactions/
    │       └── publish.rb                  # Business logic
    └── controllers/blog_management/
        └── posts_controller.rb             # Optional custom controller
```

### Portal Package Structure
```
packages/admin_portal/
├── lib/
│   └── engine.rb                           # Portal engine
├── config/
│   └── routes.rb                           # Portal routes
└── app/
    ├── controllers/admin_portal/
    │   ├── concerns/controller.rb          # Auth integration
    │   ├── dashboard_controller.rb         # Dashboard
    │   ├── plutonium_controller.rb         # Base controller
    │   └── resource_controller.rb          # Resource base
    ├── policies/admin_portal/
    │   └── resource_policy.rb              # Portal-specific policies
    └── definitions/admin_portal/
        └── resource_definition.rb          # Portal-specific definitions
```

## Development Patterns

### 1. Resource Definition (UI Configuration)
```ruby
class PostDefinition < Plutonium::Resource::Definition
  # All model attributes auto-detected - only declare overrides

  # Form inputs (only override when changing auto-detected behavior)
  input :content, as: :rich_text
  input :published_at, as: :date
  input :category, as: :select, choices: %w[Tech Business]

  # Display formatting (only override when changing auto-detected behavior)
  display :content, as: :markdown
  display :published_at, as: :datetime

  # Table columns (only override when changing auto-detected behavior)
  column :published_at, as: :datetime

  # Search functionality
  search do |scope, query|
    scope.where("title ILIKE ? OR content ILIKE ?", "%#{query}%", "%#{query}%")
  end

  # Filters (currently only Text filter available)
  filter :status, with: Plutonium::Query::Filters::Text, predicate: :eq

  # Scopes (named scopes defined on the model. they that appear as filter buttons)
  scope :published
  scope :drafts

  # Custom actions
  action :publish, interaction: PostInteractions::Publish
  action :archive, interaction: PostInteractions::Archive
end
```

### 2. Policy Configuration (Authorization)
```ruby
class PostPolicy < Plutonium::Resource::Policy
  # Basic permissions (required - secure by default)
  def create?
    user.present?
  end

  def update?
    record.user_id == user.id || user.admin?
  end

  def destroy?
    user.admin?
  end

  # Custom action permissions
  def publish?
    update? && record.published_at.nil?
  end

  # Attribute permissions (what fields are visible/editable)
  def permitted_attributes_for_read
    attrs = [:title, :content, :published_at, :created_at]
    attrs << :admin_notes if user.admin?
    attrs
  end

  def permitted_attributes_for_create
    [:title, :content, :user_id]
  end

  def permitted_attributes_for_update
    permitted_attributes_for_create
  end

  # Data scoping (what records are visible)
  relation_scope do |scope|
    scope = super(scope) # Important: call super for entity scoping

    if user.admin?
      scope
    else
      scope.where(user: user).or(scope.where(published: true))
    end
  end
end
```

### 3. Interaction Implementation (Business Logic)
```ruby
module PostInteractions
  class Publish < Plutonium::Resource::Interaction
    # Define what this interaction accepts
    attribute :resource, class: "Post"
    attribute :published_at, :datetime, default: -> { Time.current }

    # UI presentation
    presents label: "Publish Post",
             icon: Phlex::TablerIcons::Send,
             description: "Make this post public"

    # Validations
    validates :resource, presence: true

    private

    # Business logic
    def execute
      if resource.update(published_at: published_at, status: 'published')
        succeed(resource)
          .with_message("Post published successfully")
          .with_redirect_response(resource_url_for(resource))
      else
        failed(resource.errors)
      end
    end
  end
end
```

### 4. Model Setup
```ruby
class Post < BlogManagement::ResourceRecord
  # Associations
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_one_attached :featured_image

  # Validations
  validates :title, presence: true
  validates :content, presence: true

  # Enums
  enum status: { draft: 0, published: 1, archived: 2 }

  # Scopes
  scope :published, -> { where.not(published_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  # Monetary fields (if needed)
  has_cents :price_cents

  # Custom path parameters (class methods, not instance methods)
  # path_parameter :username          # Uses username in URLs
  # dynamic_path_parameter :title     # Creates SEO URLs like "1-my-title"

  # Custom labeling (optional)
  def to_label
    title.presence || "Post ##{id}"
  end
end

# Example with cross-package associations
class Comment < Comments::ResourceRecord
  belongs_to :user
  belongs_to :post, class_name: "Blogging::Post"  # Cross-package reference

  validates :body, presence: true
end
```

## Best Practices

### 1. File Organization
- Use packages to organize related features
- Keep business logic in feature packages
- Use portal packages for different user interfaces
- Follow namespacing conventions strictly

### 2. Security First
- Always define explicit permissions in policies
- Use relation_scope for data access control
- Leverage entity scoping for multi-tenancy
- Test authorization thoroughly

### 3. Generator Usage
- Start with `pu:res:scaffold` for complete resources
- Use `--dest=package_name` to specify target package
- Use `pu:res:conn` with explicit resource names for connections
- Definitions only need overrides - auto-detection handles defaults

### 4. UI Customization
- Policies control WHAT (authorization)
- Definitions control HOW (presentation)
- Interactions control business logic
- Use auto-detection, override selectively

### 5. Common Field Types
**Input Types**: `:string`, `:text`, `:rich_text`, `:email`, `:url`, `:tel`, `:password`, `:number`, `:boolean`, `:date`, `:datetime`, `:select`, `:file`, `:uppy`, `:association`

**Display Types**: `:string`, `:text`, `:markdown`, `:email`, `:url`, `:boolean`, `:date`, `:datetime`, `:association`, `:attachment`

**Action Options**: `category: :primary/:secondary/:danger`, `position: 10`, `record_action: true`, `collection_record_action: true`, `resource_action: true`, `bulk_action: true`, `confirmation: "message"`, `icon: Phlex::TablerIcons::IconName`

## Migration Tips

### Database Setup
- Use standard Rails migration conventions
- Always inline indexes and constraints in create_table blocks
- Use nullable fields with `'field:type?'` syntax
- Reference namespaced models: `package_name/model:belongs_to`
- Leverage Rails associations (`belongs_to`, `has_many`, etc.)

### Cross-Package Associations
```bash
# When generating models that reference other packages
rails generate pu:res:scaffold Comment user:belongs_to blogging/post:belongs_to body:text --dest=comments

# This creates the correct association:
# belongs_to :post, class_name: "Blogging::Post"
```

### Entity Scoping (Multi-Tenancy) Setup

Plutonium provides powerful multi-tenancy through Entity Scoping, which automatically isolates data by tenant.

#### 1. Configure Portal Engine
```ruby
# In packages/admin_portal/lib/engine.rb
scope_to_entity Organization, strategy: :path  # URLs: /organizations/:organization_id/posts

# Custom strategy (subdomain-based)
scope_to_entity Organization, strategy: :current_organization  # URLs: /posts on acme.app.com

# Custom parameter name
scope_to_entity Client, strategy: :path, param_key: :client_slug  # URLs: /clients/:client_slug/posts
```

#### 2. Implement Custom Strategy Methods
```ruby
# In packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
private

def current_organization
  @current_organization ||= begin
    organization = Organization.find_by!(subdomain: request.subdomain)

    # CRITICAL: Verify user has access to this organization
    unless current_user.organizations.include?(organization)
      raise ActionPolicy::Unauthorized, "Access denied to organization"
    end

    organization
  end
rescue ActiveRecord::RecordNotFound
  redirect_to root_path, error: "Invalid organization subdomain"
end
```

#### 3. Model Association Setup
```ruby
# Direct association (preferred)
class Post < ApplicationRecord
  belongs_to :organization  # Direct link
end

# Indirect association (automatic chain discovery)
class Comment < ApplicationRecord
  belongs_to :post
  has_one :organization, through: :post  # Chain: Comment -> Post -> Organization
end

# Custom scope for complex relationships
class Invoice < ApplicationRecord
  belongs_to :customer

  scope :associated_with_organization, ->(organization) do
    joins(customer: :organization_memberships)
      .where(organization_memberships: { organization_id: organization.id })
  end
end
```

#### 4. Policy Integration
```ruby
class PostPolicy < Plutonium::Resource::Policy
  authorize :entity_scope, allow_nil: true  # Access to current tenant

  def update?
    # Ensure record belongs to current tenant AND user can edit
    record.organization == entity_scope && record.author == user
  end

  relation_scope do |relation|
    relation = super(relation)  # Apply entity scoping first

    # Add additional tenant-aware filtering
    user.admin? ? relation : relation.where(published: true)
  end
end
```

## Quick Reference Commands

```bash
# Essential workflow
rails generate pu:pkg:package feature_name                    # Create feature package
rails generate pu:res:scaffold Resource --dest=feature_name   # Create complete resource
rails generate pu:pkg:portal portal_name                      # Create portal
rails generate pu:res:conn Feature::Resource --dest=portal    # Connect resources to portal

# Authentication
rails generate pu:rodauth:install              # Install auth system
rails generate pu:rodauth:account user         # Create user account
rails generate pu:rodauth:admin admin          # Create admin account

# Database
rails db:migrate                                # Run migrations
rails db:seed                                   # Seed data

# Development
rails server                                    # Start server
rails console                                   # Rails console
rails runner "code"                             # Run code (prefer over console)
```

## Troubleshooting

### Common Issues
- **Missing permissions**: Check policy methods return true
- **Fields not showing**: Verify policy permits attributes
- **Actions not visible**: Ensure action policy method exists
- **Routing errors**: Check portal routes registration
- **Package not loading**: Verify engine is properly configured

This guide provides the foundation for building robust Plutonium applications with proper separation of concerns, security, and maintainability.
