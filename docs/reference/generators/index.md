# Generators Reference

Complete reference for Plutonium CLI generators.

## Overview

Plutonium provides generators for scaffolding:
- Resources (model, controller, definition, policy)
- Packages (feature and portal)
- Authentication (Rodauth)
- Assets and configuration

## Resource Generators

### pu:res:scaffold

Generate a complete resource with model, controller, definition, and policy.

```bash
rails generate pu:res:scaffold Post title:string body:text published:boolean
```

#### Options

| Option | Description |
|--------|-------------|
| `--dest NAME` | Destination package (prompted if not provided) |
| `--no-model` | Skip model generation (use for existing models) |

#### Examples

```bash
# Basic resource (prompts for destination)
rails generate pu:res:scaffold Post title:string body:text

# Import existing model (no attributes needed)
rails generate pu:res:scaffold Post

# With associations
rails generate pu:res:scaffold Comment body:text user:belongs_to post:belongs_to

# Skip model generation for existing models
rails generate pu:res:scaffold Post title:string --no-model
```

### Field Types

| Type | Example | Database Type |
|------|---------|---------------|
| `string` | `title:string` | `string` |
| `text` | `body:text` | `text` |
| `integer` | `count:integer` | `integer` |
| `float` | `rating:float` | `float` |
| `decimal` | `price:decimal` | `decimal` |
| `boolean` | `active:boolean` | `boolean` |
| `date` | `published_on:date` | `date` |
| `datetime` | `published_at:datetime` | `datetime` |
| `time` | `starts_at:time` | `time` |
| `json` | `metadata:json` | `json` |
| `belongs_to` | `user:belongs_to` | `references` |
| `references` | `user:references` | `references` |
| `rich_text` | `content:rich_text` | Action Text |

#### Nullable Fields

Append `?` to make a field nullable:

```bash
rails generate pu:res:scaffold Post title:string description:text?
```

#### Money Fields (has_cents)

Integer fields ending in `_cents` are treated as money fields:

```bash
rails generate pu:res:scaffold Product name:string price_cents:integer
```

### pu:res:conn

Connect a resource to a portal.

```bash
rails generate pu:res:conn Post --dest=admin_portal
```

Creates portal-specific controller, definition, and policy (if needed) and registers the resource in the portal routes.

#### Options

| Option | Description |
|--------|-------------|
| `--dest NAME` | Destination portal (prompted if not provided) |
| `--singular` | Register as a singular resource (e.g., profile, dashboard) |

#### Examples

```bash
# Connect a resource to a portal
rails generate pu:res:conn Post --dest=admin_portal

# Connect multiple resources
rails generate pu:res:conn Post Comment --dest=admin_portal

# Connect a singular resource
rails generate pu:res:conn Profile --dest=customer_portal --singular

# Interactive mode (prompts for resource and portal)
rails generate pu:res:conn
```

::: tip Nested Resources
Nesting is automatic based on `belongs_to` associations. If `Comment` belongs to `Post`, nested routes are created automatically when both are registered in the same portal.
:::

### pu:res:model

Generate just a model with migration.

```bash
rails generate pu:res:model Post title:string body:text
```

## Package Generators

### pu:pkg:package

Generate a feature package for organizing domain code.

```bash
rails generate pu:pkg:package blogging
```

#### Generated Structure

```
packages/blogging/
├── app/
│   ├── controllers/blogging/
│   ├── definitions/blogging/
│   ├── interactions/blogging/
│   ├── models/blogging/
│   ├── policies/blogging/
│   └── views/blogging/
└── lib/
    └── engine.rb
```

### pu:pkg:portal

Generate a portal package (web interface).

```bash
rails generate pu:pkg:portal admin
```

#### Options

| Option | Description |
|--------|-------------|
| `--auth NAME` | Rodauth account to authenticate with (e.g., `--auth=user`) |
| `--public` | Grant public access (no authentication) |
| `--byo` | Bring your own authentication |
| `--scope CLASS` | Entity class to scope to for multi-tenancy (e.g., `--scope=Organization`) |

#### Examples

```bash
# Interactive mode (prompts for auth choice)
rails generate pu:pkg:portal admin

# Non-interactive with Rodauth account
rails generate pu:pkg:portal admin --auth=admin

# Public access portal
rails generate pu:pkg:portal api --public

# Bring your own authentication
rails generate pu:pkg:portal custom --byo

# With entity scoping (multi-tenancy)
rails generate pu:pkg:portal admin --auth=admin --scope=Organization
```

Without flags, the generator prompts for authentication configuration:
- Select a Rodauth account (if Rodauth is installed)
- Grant public access (no authentication)
- Bring your own auth (configure manually)

#### Generated Structure

```
packages/admin_portal/
├── app/
│   ├── controllers/admin_portal/
│   │   ├── concerns/controller.rb
│   │   ├── plutonium_controller.rb
│   │   └── dashboard_controller.rb
│   ├── definitions/admin_portal/
│   ├── policies/admin_portal/
│   └── views/admin_portal/
├── config/
│   └── routes.rb
└── lib/
    └── engine.rb
```

## Authentication Generators

### pu:rodauth:install

Install Rodauth authentication framework.

```bash
rails generate pu:rodauth:install
```

This creates:
- `app/rodauth/rodauth_app.rb` - Main Roda app
- `app/rodauth/rodauth_plugin.rb` - Base plugin
- `app/controllers/rodauth_controller.rb` - Base controller
- `config/initializers/rodauth.rb` - Configuration
- PostgreSQL extension migration (if using PostgreSQL)

### pu:rodauth:account

Generate a user account with configurable features.

```bash
rails generate pu:rodauth:account user
```

#### Options

| Option | Description |
|--------|-------------|
| `--primary` | Mark as primary account (no URL prefix) |
| `--no-mails` | Skip mailer setup |
| `--argon2` | Use Argon2 for password hashing |
| `--api_only` | Configure for JSON API only |
| `--defaults` | Enable default features (default: true) |
| `--kitchen_sink` | Enable ALL features |

#### Feature Options

Default features (enabled with `--defaults`):

| Feature | Description |
|---------|-------------|
| `--login` | Login functionality |
| `--logout` | Logout functionality |
| `--remember` | "Remember me" cookies |
| `--create_account` | User registration |
| `--verify_account` | Email verification |
| `--verify_account_grace_period` | Grace period for verification |
| `--reset_password` | Password reset via email |
| `--reset_password_notify` | Notify on password reset |
| `--change_login` | Change email address |
| `--verify_login_change` | Verify email changes |
| `--change_password` | Change password |
| `--change_password_notify` | Notify on password change |
| `--case_insensitive_login` | Case insensitive email |
| `--internal_request` | Internal request support |

Additional features:

| Feature | Description |
|---------|-------------|
| `--otp` | TOTP two-factor auth |
| `--recovery_codes` | Recovery codes for 2FA |
| `--sms_codes` | SMS-based 2FA |
| `--webauthn` | WebAuthn/passkeys |
| `--lockout` | Account lockout |
| `--active_sessions` | Track active sessions |
| `--audit_logging` | Log auth events |
| `--close_account` | Allow account deletion |
| `--email_auth` | Passwordless email login |
| `--jwt` | JWT authentication |
| `--jwt_refresh` | JWT refresh tokens |
| `--password_expiration` | Force password changes |
| `--disallow_password_reuse` | Prevent password reuse |

#### Examples

```bash
# Basic account with defaults
rails generate pu:rodauth:account user

# Primary account (no /users prefix)
rails generate pu:rodauth:account user --primary

# With 2FA features
rails generate pu:rodauth:account user --otp --recovery_codes

# API-only with JWT
rails generate pu:rodauth:account api_user --api_only --jwt --jwt_refresh

# Everything enabled
rails generate pu:rodauth:account user --kitchen_sink
```

### pu:rodauth:admin

Generate an admin account with enhanced security.

```bash
rails generate pu:rodauth:admin admin
```

Pre-configured with:
- Multi-phase login (email first, then password)
- TOTP two-factor authentication (required)
- Recovery codes
- Account lockout
- Active sessions tracking
- Audit logging
- No public signup

Creates a rake task for account creation:

```bash
rails rodauth_admin:create[admin@example.com,password123]
```

## SaaS Generators

### pu:saas:setup

Generate a complete multi-tenant SaaS setup with user, entity, and membership.

```bash
rails generate pu:saas:setup --user Customer --entity Organization
rails generate pu:saas:setup --user Customer --entity Organization --roles=member,admin,owner
rails generate pu:saas:setup --user Customer --entity Organization --no-allow-signup
```

#### Options

| Option | Description |
|--------|-------------|
| `--user NAME` | User account model name (required) |
| `--entity NAME` | Entity model name (required) |
| `--allow-signup` | Allow public registration (default: true) |
| `--roles` | Comma-separated membership roles (default: member,owner) |
| `--skip-entity` | Skip entity model generation |
| `--skip-membership` | Skip membership model generation |
| `--user-attributes` | Additional user model attributes |
| `--entity-attributes` | Additional entity model attributes |
| `--membership-attributes` | Additional membership model attributes |

Creates:
- User account model with Rodauth authentication
- Entity model with unique name
- Membership join model with role enum
- Has-many-through associations with `dependent: :destroy`

### pu:saas:user

Generate just a SaaS user account.

```bash
rails generate pu:saas:user Customer
rails generate pu:saas:user Customer --no-allow-signup
rails generate pu:saas:user Customer --extra-attributes=name:string
```

### pu:saas:entity

Generate just an entity model.

```bash
rails generate pu:saas:entity Organization
rails generate pu:saas:entity Organization --extra-attributes=slug:string
```

### pu:saas:membership

Generate just a membership model (requires user and entity to exist).

```bash
rails generate pu:saas:membership --user Customer --entity Organization
rails generate pu:saas:membership --user Customer --entity Organization --roles=member,admin,owner
```

## Core Generators

### pu:core:install

Install Plutonium in an existing Rails app.

```bash
rails generate pu:core:install
```

Creates:
- `config/initializers/plutonium.rb` - Configuration
- Base classes (ResourceRecord, ResourcePolicy, etc.)
- Package loading configuration

### pu:core:assets

Setup custom TailwindCSS and Stimulus assets.

```bash
rails generate pu:core:assets
```

This:
1. Installs npm packages (`@radioactive-labs/plutonium`, TailwindCSS plugins)
2. Creates `tailwind.config.js` extending Plutonium's config
3. Imports Plutonium CSS into your stylesheet
4. Registers Plutonium's Stimulus controllers
5. Updates Plutonium config to use your assets

## Eject Generators

### pu:eject:layout

Eject layout views for customization.

```bash
rails generate pu:eject:layout
```

Copies layout files to your portal for customization.

### pu:eject:shell

Eject shell components (sidebar, header).

```bash
rails generate pu:eject:shell
```

## Common Patterns

### Full Application Setup

```bash
# Create Rails app with Plutonium template
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb

# Or add to existing app
rails generate pu:core:install
rails generate pu:rodauth:install

# Create admin account type
rails generate pu:rodauth:admin admin

# Create resources
rails generate pu:res:scaffold Post title:string body:text
rails generate pu:res:scaffold Comment body:text post:belongs_to

# Create portal (prompts for auth)
rails generate pu:pkg:portal admin

# Connect resources
rails generate pu:res:conn Post Comment --dest=admin_portal

# Run migrations
rails db:migrate

# Create admin account
rails rodauth_admin:create[admin@example.com,password123]
```

### Adding a New Resource

```bash
# Generate the resource
rails generate pu:res:scaffold Product name:string price_cents:integer

# Connect to portal
rails generate pu:res:conn Product --dest=admin_portal

# Run migration
rails db:migrate
```

### Adding a New Portal

```bash
# Create SaaS setup (user + entity + membership)
rails generate pu:saas:setup --user Customer --entity Organization

# Create portal
rails generate pu:pkg:portal customer

# Connect resources
rails generate pu:res:conn Order --dest=customer_portal

# Run migrations
rails db:migrate
```

## Undoing Generators

```bash
rails destroy pu:res:scaffold Post
rails destroy pu:pkg:portal admin
```

## Troubleshooting

### Generator Not Found

Ensure Plutonium is installed:

```ruby
# Gemfile
gem "plutonium"
```

### Package Not Found

Generators run from Rails root. Package names are case-sensitive.

### Migration Already Exists

If a migration with the same timestamp exists, wait a second and retry.

## Related

- [Adding Resources Guide](/guides/adding-resources)
- [Creating Packages Guide](/guides/creating-packages)
- [Authentication Guide](/guides/authentication)
