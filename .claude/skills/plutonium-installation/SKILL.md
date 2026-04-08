---
name: plutonium-installation
description: Use BEFORE installing Plutonium in a Rails app, running pu:core:install, or configuring initial Plutonium setup. Covers generators, gemfile, and initial config.
---

# Plutonium Installation

## 🚨 Critical (read first)
- **Use the generators.** `pu:core:install`, `pu:rodauth:install`, `pu:pkg:portal`, `pu:res:scaffold`, `pu:res:conn` — never hand-write base controllers, policies, or layouts.
- **Use `base.rb`, not `plutonium.rb`, for existing apps.** The `plutonium.rb` template reruns the full bootstrap (dotenv, annotate, solid_*, assets) and clobbers git history. For any pre-existing app, use `base.rb`.
- **Pass `--dest`, `--force`, `--auth`, `--skip-bundle` for unattended runs** so generators don't block on prompts. See `plutonium` index for the full flag matrix.
- **Related skills:** `plutonium` (architecture overview), `plutonium-auth` (Rodauth setup), `plutonium-portal` (portal config), `plutonium-create-resource` (scaffolding resources).

## Quick checklist

Fresh install in a new Rails app:

1. Generate the Rails app with `rails new myapp -a propshaft -j esbuild -c tailwind -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb` (greenfield) OR `bin/rails app:template LOCATION=.../base.rb` (existing app).
2. Run `bundle install` if you added the gem manually.
3. Run `rails generate pu:core:install` to create base controllers, policies, definitions, and config.
4. Run `rails generate pu:rodauth:install` + `rails generate pu:rodauth:account user` for auth.
5. Run `rails generate pu:pkg:portal admin --auth=user` to create a portal.
6. Run `rails generate pu:res:scaffold Post title:string 'content:text?' --dest=main_app` for a first resource.
7. Run `rails db:migrate`.
8. Run `rails generate pu:res:conn Post --dest=admin_portal` to connect the resource.
9. Mount the portal in `config/routes.rb`: `mount AdminPortal::Engine, at: "/admin"`.
10. Start the server and visit `/admin`.

## New Rails App (Recommended)

Use the Rails template for a fully configured setup:

```bash
rails new myapp -a propshaft -j esbuild -c tailwind \
  -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

This sets up Rails with Propshaft, esbuild, TailwindCSS, and Plutonium in one command.

## Existing Rails App

> **⚠️ Use `base.rb`, not `plutonium.rb`.** The `plutonium.rb` template is for `rails new` only — it re-runs the full app bootstrap (dotenv, annotate, solid_*, assets) and creates generic "initial commit" commits that clobber history. For any pre-existing app, always use `base.rb`.

### Option 1: Rails Template

```bash
bin/rails app:template \
  LOCATION=https://radioactive-labs.github.io/plutonium-core/templates/base.rb
```

### Option 2: Manual Installation

```bash
# Add to Gemfile
gem "plutonium"

# Install
bundle install
rails generate pu:core:install
```

## What Gets Generated

After `pu:core:install`:

```
app/
├── controllers/
│   ├── plutonium_controller.rb    # Base controller
│   └── resource_controller.rb     # Resource CRUD base
├── definitions/
│   └── resource_definition.rb     # Definition base class
├── interactions/
│   └── resource_interaction.rb    # Interaction base class
├── models/
│   └── resource_record.rb         # Abstract model base
├── policies/
│   └── resource_policy.rb         # Policy base class
└── views/
    └── layouts/
        └── resource.html.erb      # Base layout

config/
├── initializers/
│   └── plutonium.rb               # Configuration
└── packages.rb                    # Package loader

packages/
└── .keep
```

## Base Classes

### ResourceController

```ruby
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller
  # Provides: index, show, new, create, edit, update, destroy
  # Plus: interactive actions, authorization, query handling
end
```

### ResourcePolicy

```ruby
class ResourcePolicy < Plutonium::Resource::Policy
  def create?
    true  # Override with your logic
  end

  def read?
    true
  end
end
```

### ResourceDefinition

```ruby
class ResourceDefinition < Plutonium::Resource::Definition
  # Add app-wide definition defaults here
end
```

### ResourceRecord

```ruby
class ResourceRecord < ApplicationRecord
  self.abstract_class = true
  # Models inherit from this for Plutonium features
end
```

## Authentication Setup

### Install Rodauth

```bash
rails generate pu:rodauth:install
```

### Create Account Types

```bash
# Basic user account
rails generate pu:rodauth:account user

# Admin with 2FA, lockout, audit logging
rails generate pu:rodauth:admin admin

# SaaS user with entity/organization (multi-tenant)
rails generate pu:saas:setup --user Customer --entity Organization
```

### Account Options

| Option | Description |
|--------|-------------|
| `--defaults` | Enable common features (login, logout, remember, reset_password) |
| `--kitchen_sink` | Enable all available features |
| `--no-allow-signup` | Disable public signup |

### Connect Auth to Controllers

```ruby
# app/controllers/resource_controller.rb
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller
  include Plutonium::Auth::Rodauth(:user)  # Add this
end
```

## Creating Your First Resource

```bash
rails generate pu:res:scaffold Post user:belongs_to title:string content:text
rails db:migrate
```

## Creating a Portal

```bash
rails generate pu:pkg:portal admin
```

Select authentication when prompted:
- **Rodauth account** - Use existing auth
- **Public access** - No authentication
- **Bring your own** - Custom implementation

### Mount the Portal

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount AdminPortal::Engine, at: "/admin"
end
```

### Connect Resources to Portal

```bash
rails generate pu:res:conn Post --dest=admin_portal
```

## Configuration

```ruby
# config/initializers/plutonium.rb
Plutonium.configure do |config|
  config.load_defaults 1.0

  # Custom assets (optional)
  # config.assets.stylesheet = "custom_stylesheet"
  # config.assets.script = "custom_script"
  # config.assets.logo = "custom_logo.png"
end
```

## Package System

Packages are loaded from `config/packages.rb`:

```ruby
Dir.glob(File.expand_path("../packages/**/lib/engine.rb", __dir__)) { |package| load package }
```

Create packages in `packages/` directory:
- **Feature packages** - Business logic (`rails g pu:pkg:package blogging`)
- **Portal packages** - Web interfaces (`rails g pu:pkg:portal admin`)

## Post-Installation Checklist

1. **Install core**
   ```bash
   rails generate pu:core:install
   ```

2. **Setup authentication** (if needed)
   ```bash
   rails generate pu:rodauth:install
   rails generate pu:rodauth:account user
   ```

3. **Create a portal**
   ```bash
   rails generate pu:pkg:portal admin
   ```

4. **Create resources**
   ```bash
   rails generate pu:res:scaffold Post title:string content:text
   ```

5. **Connect resources to portal**
   ```bash
   rails generate pu:res:conn Post --dest=admin_portal
   ```

6. **Run migrations**
   ```bash
   rails db:migrate
   ```

7. **Mount portal** (add to `config/routes.rb`)
   ```ruby
   mount AdminPortal::Engine, at: "/admin"
   ```

8. **Start server**
   ```bash
   rails server
   ```

## Converting Existing Models

For models that already exist in your app:

1. Include the module:
   ```ruby
   class Post < ApplicationRecord
     include Plutonium::Resource::Record
   end
   ```

2. Generate supporting files (skips model/migration):
   ```bash
   rails g pu:res:scaffold Post
   ```

3. Connect to portal:
   ```bash
   rails g pu:res:conn Post --dest=admin_portal
   ```

## Generator Reference

| Generator | Purpose |
|-----------|---------|
| `pu:core:install` | Initial Plutonium setup |
| `pu:rodauth:install` | Setup Rodauth authentication |
| `pu:rodauth:account NAME` | Create user account type |
| `pu:rodauth:admin NAME` | Create admin account with 2FA |
| `pu:saas:setup` | Create SaaS user + entity + membership |
| `pu:saas:user NAME` | Create SaaS user account |
| `pu:saas:entity NAME` | Create entity model |
| `pu:saas:membership` | Create membership join table |
| `pu:pkg:package NAME` | Create feature package |
| `pu:pkg:portal NAME` | Create portal package |
| `pu:res:scaffold NAME` | Create resource (model, policy, definition, controller) |
| `pu:res:conn NAME` | Connect resource to portal |
| `pu:eject:layout` | Eject layout files for customization |
| `pu:skills:sync` | Sync Claude Code skills to project |

## Related Skills

- `plutonium` - Resource architecture overview
- `plutonium-auth` - Authentication setup and configuration
- `plutonium-package` - Feature and portal packages
- `plutonium-portal` - Portal configuration
- `plutonium-views` - Custom pages, layouts, and Phlex components
- `plutonium-assets` - TailwindCSS and custom styling
- `plutonium-create-resource` - Resource scaffold options
- `plutonium-portal` - Portal connection
