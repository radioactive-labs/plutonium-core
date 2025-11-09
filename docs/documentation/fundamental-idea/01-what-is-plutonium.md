# What is Plutonium?

Plutonium is a Rapid Application Development (RAD) toolkit that extends Rails with powerful conventions, patterns, and tools to accelerate application development while maintaining flexibility and maintainability.

It acts as a higher-level abstraction on top of Rails, providing ready-to-use solutions for common application needs while preserving Rails' elegance.

Skip the long talk and [Get Started](/documentation/installation/01-installation)

## Core Architecture

### Rails-Native Design

Plutonium integrates seamlessly with Rails, extending its conventions rather than replacing them:

```ruby
# Plutonium controllers inherit from your ApplicationController
class ResourceController < ApplicationController
  include Plutonium::Resource::Controller
end

# Plutonium controllers are Rails controllers
class ProductsController < ResourceController
  # Enhanced with resource capabilities
  def custom_action
    # Regular Rails code works just fine
    respond_to do |format|
      format.html
      format.json
    end
  end
end
```

### Resource-Oriented Architecture

Resources are the building blocks of Plutonium applications:

```ruby
class ProductDefinition < ResourceDefinition
  # Declarative field definitions
  field :name, as: :string
  field :description, as: :markdown
  field :price_cents, as: :money

  # Resource-level search
  search do |scope, query|
    scope.where("name LIKE ?", "%#{query}%")
  end

  # Business actions
  action :publish, interaction: PublishProduct
  action :archive, interaction: ArchiveProduct
end
```

### Modular by Design

Plutonium's packaging system helps organize code into focused, reusable modules:

```ruby
# Generate different types of packages
rails generate pu:pkg:portal admin
rails generate pu:pkg:package inventory

# Packages are isolated and focused
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
  end
end

AdminPortal::Engine.routes.draw do
  register_resource ::Product
end
```

### Progressive Enhancement

Built on modern web technologies like Hotwire, delivering rich interactivity without sacrificing simplicity:

```ruby
class PublishProduct < ResourceInteraction
  attribute :schedule_for, :datetime
  attribute :notify_users, :boolean

  def execute
    resource.publish!(schedule_for:)
    notify_users! if notify_users

    success(resource)
      .with_message("Product scheduled for publishing")
      .with_render_response(NotificationComponent.new)
  end
end
```

## Use Cases

### Business Applications

::: details Enterprise Resource Planning (ERP)

```ruby
class InvoiceDefinition < ResourceDefinition
  # Rich field handling
  field :line_items, as: :nested, limit: 20
  field :attachments, as: :document, multiple: true

  # Business actions
  action :submit_for_approval, interaction: SubmitForApproval
  action :approve, interaction: ApproveInvoice
  action :reject, interaction: RejectInvoice

  # Workflow states
  scope :draft
  scope :pending_approval
  scope :approved
end
```

:::

::: details Multi-tenant SaaS

```ruby
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Package::Engine
    # Automatic tenant isolation
    scope_to_entity Organization
  end
end
```

:::

### Administrative Systems

::: details Back-office Applications

```ruby
class OrderDefinition < ResourceDefinition
  # Advanced filtering
  filter :status, with: SelectFilter, choices: Order.statuses
  filter :created_at, with: DateRangeFilter

  # Bulk actions
  action :process_batch, interaction: ProcessPendingOrders
  action :export_to_csv, interaction: ExportOrders

  # Complex displays
  display :summary do |field|
    OrderSummaryComponent.new(field)
  end
end
```

:::

::: details Content Management

```ruby
class ArticleDefinition < ResourceDefinition
  field :content, as: :markdown
  field :featured_image, as: :image

  # Publishing workflow
  action :publish, interaction: PublishArticle
  action :schedule, interaction: ScheduleArticle

  # Content organization
  scope :draft
  scope :published
  scope :scheduled
end
```

:::

## Key Benefits

### Accelerated Development

- Pre-built components for common functionality
- Smart generators for boilerplate code
- Convention-based resource handling
- Integrated authentication and authorization

### Maintainable Architecture

- Clear separation of concerns through packages
- Consistent patterns across the application
- Deep Rails integration
- Progressive enhancement

### Enterprise Ready

- Flexible and robust access control
- Multi-tenancy support
- Extensible component system
- Mobile-friendly by default

## Best For

::: tip IDEAL USE CASES

- Complex business applications
- Multi-tenant SaaS platforms
- Administrative systems
- Content management systems
- Resource management systems
  :::

::: warning MIGHT NOT BE THE BEST FIT

- Simple blogs or brochure sites
- Basic CRUD applications
- Pure API-only services
  :::

## Prerequisites

- Ruby 3.2.2 or higher
- Rails 7.1 or higher
- Node.js and Yarn
- Basic understanding of Ruby on Rails
