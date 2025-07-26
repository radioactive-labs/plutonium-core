---
title: Generator Module
---

# Generator Module

The Generator module provides comprehensive code generation and scaffolding capabilities for Plutonium applications. It offers a suite of Rails generators that automate the creation of packages, resources, authentication setups, and other common development patterns.

::: tip
The Generator module is located in `lib/generators/pu/`.
:::

## Overview

- **Code Scaffolding**: Automated generation of models, controllers, policies, and definitions.
- **Package Creation**: Portal and feature package generators with proper structure.
- **Resource Management**: Complete resource scaffolding with CRUD operations.
- **Authentication Setup**: Rodauth integration with multi-account support.
- **Interactive CLI**: TTY-powered interactive prompts for generator options.

## Core Generators

### Installation Generator (`pu:core:install`)

Sets up the base requirements for a Plutonium application.

::: code-group

```bash [Command]
rails generate pu:core:install
```

```text [Generated Structure]
config/
├── packages.rb          # Package loading configuration
└── initializers/
    └── plutonium.rb     # Plutonium configuration

packages/                # Package directory
└── .keep

app/
├── controllers/
│   ├── application_controller.rb    # Enhanced with Plutonium
│   ├── plutonium_controller.rb      # Base Plutonium controller
│   └── resource_controller.rb       # Resource CRUD controller
└── models/
    └── application_record.rb        # Enhanced with Plutonium::Resource::Record

app/views/
└── layouts/
    └── resource.html.erb            # Ejected layout for customization
```

:::

### Package Generators

#### Portal Generator (`pu:pkg:portal`)

Creates a complete portal package, which acts as a user-facing entry point to your application, often with its own authentication.

::: code-group

```bash [Command]
# Creates an "admin" portal with authentication
rails generate pu:pkg:portal admin

# Creates a "customer" portal with public access
rails generate pu:pkg:portal customer --public
```

```text [Generated Structure]
packages/admin_portal/
├── lib/
│   └── engine.rb                    # Portal engine with entity scoping
├── config/
│   └── routes.rb                    # Portal-specific routes
└── app/
    ├── controllers/
    │   └── admin_portal/
    │       ├── concerns/controller.rb # Portal controller concern
    │       ├── plutonium_controller.rb
    │       ├── resource_controller.rb
    │       └── dashboard_controller.rb
    ├── policies/
    │   └── admin_portal/
    └── definitions/
        └── admin_portal/
```

```ruby [Authentication Integration]
# Automatic Rodauth integration is added to the controller concern
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb

module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      # Generated based on generator selection (e.g., :admin)
      include Plutonium::Auth::Rodauth(:admin)
    end
  end
end
```

:::

#### Package Generator (`pu:pkg:package`)

Creates a standard feature package for encapsulating domain logic.

::: code-group

```bash [Command]
rails generate pu:pkg:package blogging
```

```text [Generated Structure]
packages/blogging/
├── lib/
│   └── engine.rb        # Package engine
└── app/
    ├── models/
    │   └── blogging/
    ├── controllers/
    │   └── blogging/
    ├── policies/
    │   └── blogging/
    ├── definitions/
    │   └── blogging/
    └── interactions/
        └── blogging/
```

:::

### Resource Generators

#### Scaffold Generator (`pu:res:scaffold`)

Creates a complete resource with a model, controller, policy, and definition, including full CRUD operations.

::: code-group

```bash [Command]
# Generate a new resource with attributes, placing it in the 'blogging' package
rails generate pu:res:scaffold Post title:string content:text author:references published:boolean --dest=blogging
```

```ruby [Generated Model]
# packages/blogging/app/models/blogging/post.rb
class Blogging::Post < Blogging::ResourceRecord
  belongs_to :author, class_name: 'UserManagement::User'

  validates :title, presence: true
  validates :content, presence: true
end
```

```ruby [Generated Policy]
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging B::ResourcePolicy
  def create?
    user.present?
  end

  def update?
    user == record.author
  end
end
```

```ruby [Generated Definition]
# packages/blogging/app/definitions/blogging/post_definition.rb
class Blogging::PostDefinition < Blogging::ResourceDefinition
  # Display configuration
  display :title, :author, :published, :created_at

  # Search configuration
  search :title, :content

  # Filter configuration
  filter :published, with: :boolean
  filter :author, with: :select
end
```

:::

### Authentication Generators

#### Rodauth Customer Generator (`pu:rodauth:customer`)

Easily add multitenancy and SaaS-ready authentication to your Plutonium app. This generator creates a customer-oriented Rodauth account, an entity model, and a membership join model, wiring up all necessary relationships for multi-tenant architectures.

> **Note:** If you omit the `--entity` parameter, the entity name will default to `Entity` and the join relation will be `EntityCustomer`. **It is strongly recommended to always provide a meaningful entity name using `--entity=YourEntityName` to ensure clarity and proper model relationships in your application.**

> **Option:** `--allow-signup` determines whether the customer user is allowed to sign up on the platform. If not allowed, new customer accounts will typically be created by platform admins and users notified. Use `--no-allow-signup` to restrict self-signup.

::: code-group

```bash [Command]
rails generate pu:rodauth:customer Customer --entity=Organization
```

```text [Generated Structure]
app/
├── models/
│   ├── customer.rb
│   ├── organization.rb
│   └── organization_customer.rb
└── rodauth/
    ├── customer_rodauth.rb
    └── customer_rodauth_plugin.rb
db/
└── migrate/
    ├── ..._create_customers.rb
    ├── ..._create_organizations.rb
    └── ..._create_organization_customers.rb
```

```ruby [Generated Models]
# app/models/organization.rb
class Organization < ::ResourceRecord
  has_many :organization_customers
  has_many :customers, through: :organization_customers
end

# app/models/customer.rb
class Customer < ResourceRecord
  include Rodauth::Rails.model(:customer)

  has_many :organization_customers
  has_many :organizations, through: :organization_customers
end

# app/models/organization_customer.rb
class OrganizationCustomer < ::ResourceRecord
  enum :role, member: 0, owner: 1

  belongs_to :organization
  belongs_to :customer
end
```

:::

> **Note:** If you already have a customer user model and want to add an entity (for example, as your project evolves into a SaaS), use the Entity Resource Generator below to generate just the entity and membership join model.

#### Rodauth Account Generator (`pu:rodauth:account`)

Generates the necessary files for a Rodauth authentication setup for a given account type.

::: code-group

```bash [Command]
# Generate a 'user' account with common features
rails generate pu:rodauth:account user --features login logout create-account verify-account reset-password remember
```

```text [Generated Structure]
app/
├── controllers/
│   └── rodauth/
│       └── user_controller.rb
├── mailers/
│   └── user_mailer.rb
├── models/
│   └── user.rb
└── rodauth/
    ├── user_rodauth.rb
    └── user_rodauth_plugin.rb
db/
└── migrate/
    └── ..._create_users.rb
```

:::

#### Rodauth Admin Generator (`pu:rodauth:admin`)

A specialized generator for creating a secure admin account with enhanced features like MFA and audit logging.

::: code-group

```bash [Command]
rails generate pu:rodauth:admin admin
```

```ruby [Generated Plugin]
# app/rodauth/admin_rodauth_plugin.rb
class AdminRodauthPlugin < RodauthPlugin
  configure do
    enable :login, :logout, :remember,
           :otp, :recovery_codes, :lockout,
           :active_sessions, :audit_logging,
           :password_grace_period, :internal_request

    # ... and other secure defaults
  end
end
```

:::

### Entity Resource Generator (`pu:res:entity`)

Creates an entity model and a membership join model for associating customers with entities. Use this if you already have a customer model and want to add multitenancy or evolve your project into a SaaS platform.

::: code-group

```bash [Command]
rails generate pu:res:entity Organization --auth-account=Customer
```

```text [Generated Structure]
app/
├── models/
│   ├── organization.rb
│   └── organization_customer.rb
db/
└── migrate/
    ├── ..._create_organizations.rb
    └── ..._create_organization_customers.rb
```

```ruby [Generated Membership Model]
# app/models/organization_customer.rb
class OrganizationCustomer < ResourceRecord
  belongs_to :organization
  belongs_to :customer

  enum role: { member: 0, admin: 1 } # not added by default
end
```

:::

### Ejection Generators

#### Layout Ejection (`pu:eject:layout`)

Ejects Plutonium layouts for customization:

```bash
rails generate pu:eject:layout --dest=admin_portal
```

#### Shell Ejection (`pu:eject:shell`)

Ejects shell components and assets:

```bash
rails generate pu:eject:shell --dest=admin_portal
```

## Generator Configuration

### Interactive Mode

Many generators support interactive prompts:

```bash
# Interactive package selection
rails generate pu:res:scaffold Post title:string
# Prompts: "Select destination feature: [blogging, user_management, main_app]"

# Non-interactive mode
rails generate pu:res:scaffold Post title:string --dest=blogging
```

## Development Workflow Integration

### IDE Integration

Add generator shortcuts to your IDE:

```json
// .vscode/tasks.json
{
  "tasks": [
    {
      "label": "Generate Resource",
      "type": "shell",
      "command": "rails generate pu:res:scaffold ${input:resourceName}",
      "group": "build"
    },
    {
      "label": "Generate Portal",
      "type": "shell",
      "command": "rails generate pu:pkg:portal ${input:portalName}",
      "group": "build"
    }
  ]
}
```

The Generator module provides a comprehensive foundation for rapid application development with Plutonium, automating repetitive tasks while maintaining flexibility and customization options.
