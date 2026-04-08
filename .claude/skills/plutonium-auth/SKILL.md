---
name: plutonium-auth
description: Use BEFORE configuring Rodauth, account types, login flows, or building a profile / account settings page. Also when including Plutonium::Auth::Rodauth in a controller. Covers authentication and user profile pages.
---

# Plutonium Authentication (Rodauth + Profile)

## 🚨 Critical (read first)
- **Use the generators.** `pu:rodauth:install`, `pu:rodauth:account`, `pu:rodauth:admin`, `pu:saas:setup`, `pu:profile:install`, `pu:profile:conn` — never hand-write Rodauth plugin files, account models, or profile resources.
- **Role index 0 is the most privileged** (`owner`, `super_admin`). Invite interactions default new invitees to index 1. `pu:saas:setup` always prepends `owner` — don't include it in `--roles`.
- **`pu:saas:setup` is a meta-generator** that also runs `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, and `pu:invites:install`. Don't re-run them manually.
- **Profile association is always `:profile`** regardless of the model class — `current_user.profile`, `build_profile`, etc.
- **Related skills:** `plutonium-installation` (initial setup), `plutonium-portal` (portal auth), `plutonium-invites` (multi-tenant invitations), `plutonium-entity-scoping` (tenant scoping).

Plutonium integrates with [Rodauth](http://rodauth.jeremyevans.net/) via [rodauth-rails](https://github.com/janko/rodauth-rails) for authentication. This skill covers the full auth surface: installing Rodauth, configuring account types, building login/password flows, and adding a user profile / account settings page.

## Contents
- [Rodauth setup](#rodauth-setup)
- [Account types](#account-types)
- [Connecting auth to controllers](#connecting-auth-to-controllers)
- [Customization](#customization)
- [Email configuration](#email-configuration)
- [Portal integration](#portal-integration)
- [API authentication](#api-authentication)
- [Profile page](#profile-page)
- [Gotchas](#gotchas)

## Rodauth setup

### Step 1: Install Rodauth Base

```bash
rails generate pu:rodauth:install
```

This installs:
- Required gems (`rodauth-rails`, `bcrypt`, `sequel-activerecord_connection`)
- `app/rodauth/rodauth_app.rb` - Main Roda app
- `app/rodauth/rodauth_plugin.rb` - Base plugin
- `app/controllers/rodauth_controller.rb` - Base controller
- `config/initializers/rodauth.rb` - Configuration
- `app/views/layouts/rodauth.html.erb` - Auth layout
- PostgreSQL extension migration (if using PostgreSQL)

### Step 2: Create Account Type

```bash
# Basic user account
rails generate pu:rodauth:account user

# Admin with 2FA and security features
rails generate pu:rodauth:admin admin

# SaaS user with entity/organization (multi-tenant)
rails generate pu:saas:setup --user Customer --entity Organization
```

## Account types

### Basic Account (`pu:rodauth:account`)

```bash
rails generate pu:rodauth:account user [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--defaults` | Enable default features (login, logout, remember, password reset) |
| `--kitchen_sink` | Enable ALL available features |
| `--primary` | Mark as primary account (no URL prefix) |
| `--no-mails` | Skip mailer setup |
| `--argon2` | Use Argon2 instead of bcrypt for password hashing |
| `--api_only` | Configure for JSON API only (no sessions) |

**Feature Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--login` | ✓ | Login functionality |
| `--logout` | ✓ | Logout functionality |
| `--remember` | ✓ | "Remember me" cookies |
| `--create_account` | ✓ | User registration |
| `--verify_account` | ✓ | Email verification |
| `--reset_password` | ✓ | Password reset via email |
| `--change_password` | ✓ | Change password |
| `--change_login` | ✓ | Change email |
| `--verify_login_change` | ✓ | Verify email change |
| `--otp` | | TOTP two-factor auth |
| `--webauthn` | | WebAuthn/passkeys |
| `--recovery_codes` | | Recovery codes for 2FA |
| `--lockout` | | Account lockout after failed attempts |
| `--active_sessions` | | Track active sessions |
| `--audit_logging` | | Audit authentication events |
| `--close_account` | | Allow account deletion |
| `--email_auth` | | Passwordless login via email |
| `--sms_codes` | | SMS-based 2FA |
| `--jwt` | | JWT token authentication |
| `--jwt_refresh` | | JWT refresh tokens |

### Admin Account (`pu:rodauth:admin`)

Creates a secure admin account with multi-phase login, TOTP 2FA (required), recovery codes, account lockout, active session tracking, audit logging, role-based access control, invite interaction, and no public signup.

```bash
rails generate pu:rodauth:admin admin
rails generate pu:rodauth:admin admin --roles=super_admin,admin,viewer
rails generate pu:rodauth:admin admin --extra-attributes=name:string,department:string
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--roles` | super_admin,admin | Comma-separated roles for admin accounts |
| `--extra_attributes` | | Additional model attributes (e.g., name:string) |

**Role ordering convention:** Roles are stored as a positional enum — **index 0 is the most privileged** (`super_admin`, `owner`, etc.). The generated invite interaction defaults new invitees to `roles[1]`, so the order in `--roles=` matters.

```ruby
# app/models/admin.rb
enum :role, super_admin: 0, admin: 1
```

```ruby
# app/interactions/admin/invite_interaction.rb
class Admin::InviteInteraction < Plutonium::Interaction::Base
  attribute :email, :string
  attribute :role, default: :admin
  # ...
end
```

Rake task for direct creation:
```bash
rails rodauth_admin:create[admin@example.com,password123]
```

### SaaS Setup (`pu:saas:setup`)

> **This is a meta-generator.** In addition to creating the user + entity + membership, `pu:saas:setup` also runs:
> - `pu:saas:portal` → a full `{Entity}Portal` scoped to the entity
> - `pu:profile:setup` → a `Profile` model and association on the user
> - `pu:saas:welcome` → the onboarding / select-entity flow
> - `pu:invites:install` → the entire invites package
>
> Don't generate another entity portal after running this. Pass `--force` if re-running.

```bash
rails generate pu:saas:setup --user Customer --entity Organization
rails generate pu:saas:setup --user Customer --entity Organization --roles=member,admin,owner
rails generate pu:saas:setup --user Customer --entity Organization --no-allow-signup
rails generate pu:saas:setup --user Customer --entity Organization --user-attributes=name:string --entity-attributes=slug:string
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--user=NAME` | (required) | User account model name |
| `--entity=NAME` | (required) | Entity model name |
| `--allow-signup` | true | Allow public registration |
| `--roles` | admin,member | Additional membership roles. **`owner` is always prepended as index 0** — don't include it. |
| `--skip-entity` | false | Skip entity model generation |
| `--skip-membership` | false | Skip membership model generation |
| `--user-attributes` | | Additional user model attributes |
| `--entity-attributes` | | Additional entity model attributes |
| `--membership-attributes` | | Additional membership model attributes |

Individual generators: `pu:saas:user`, `pu:saas:entity`, `pu:saas:membership`.

```ruby
# app/models/customer.rb
class Customer < ApplicationRecord
  include Rodauth::Rails.model(:customer)
  has_many :organization_customers, dependent: :destroy
  has_many :organizations, through: :organization_customers
end

# app/models/organization_customer.rb
class OrganizationCustomer < ApplicationRecord
  belongs_to :organization
  belongs_to :customer
  enum :role, member: 0, owner: 1

  validates :customer, uniqueness: {
    scope: :organization_id,
    message: "is already a member of this organization"
  }
end
```

## Connecting auth to controllers

```ruby
# app/controllers/resource_controller.rb
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller
  include Plutonium::Auth::Rodauth(:user)
end
```

Multiple account types:

```ruby
class AdminController < PlutoniumController
  include Plutonium::Resource::Controller
  include Plutonium::Auth::Rodauth(:admin)
end
```

Including `Plutonium::Auth::Rodauth(:name)` adds `current_user`, `logout_url`, and `rodauth`.

## Customization

### Custom Login Redirect

```ruby
configure do
  login_redirect do
    if rails_account.admin?
      "/admin"
    else
      "/dashboard"
    end
  end
end
```

### Custom Validation

```ruby
configure do
  before_create_account do
    throw_error_status(422, "name", "must be present") if param("name").empty?
  end

  after_create_account do
    Profile.create!(account_id: account_id, name: param("name"))
  end
end
```

### Password Requirements

```ruby
configure do
  password_minimum_length 12

  password_meets_requirements? do |password|
    super(password) && password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
  end
end
```

### Multi-Phase Login

```ruby
configure do
  use_multi_phase_login? true
end
```

### Prevent Public Signup

```ruby
configure do
  before_create_account_route do
    request.halt unless internal_request?
  end
end
```

## Email configuration

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.example.com",
  port: 587,
  user_name: ENV["SMTP_USER"],
  password: ENV["SMTP_PASSWORD"]
}
```

Override templates in `app/views/rodauth/user_mailer/`.

## Portal integration

```bash
rails generate pu:pkg:portal admin
# Select "Rodauth account" → "admin"
```

Manual:

```ruby
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.before_initialize do
      config.to_prepare do
        AdminPortal::ResourceController.class_eval do
          include Plutonium::Auth::Rodauth(:admin)
          before_action :require_authenticated

          private

          def require_authenticated
            redirect_to rodauth.login_path unless current_user
          end
        end
      end
    end
  end
end
```

## API authentication

```bash
rails generate pu:rodauth:account api_user --api_only --jwt --jwt_refresh
```

```
POST /api_users/login
{"login": "user@example.com", "password": "secret"}
# → {"access_token": "...", "refresh_token": "..."}

GET /api/posts
Authorization: Bearer <access_token>
```

## Profile page

Plutonium provides a Profile resource generator for managing Rodauth account settings. Users can view/edit their profile, access Rodauth security features (change password, 2FA, etc.), and manage account settings in one place.

### Quick setup

```bash
rails g pu:profile:setup date_of_birth:date bio:text \
    --dest=competition \
    --portal=competition_portal
```

### Step-by-step install

```bash
rails generate pu:profile:install --dest=main_app
```

| Option | Default | Description |
|--------|---------|-------------|
| `--dest=DESTINATION` | (prompts) | Target package or main_app |
| `--user-model=NAME` | User | Rodauth user model name |

With fields:

```bash
rails g pu:profile:install \
    bio:text \
    avatar:attachment \
    'timezone:string?' \
    --dest=customer
```

Custom name:

```bash
rails g pu:profile:install AccountSettings bio:text --dest=main_app
```

### What gets created

The generator creates a standard Plutonium resource. **By default the model is named `{UserModel}Profile`** (e.g. `UserProfile`, `StaffUserProfile`) — derived from `--user-model`. Pass an explicit name as the first positional argument to override.

```
app/models/[package/]user_profile.rb              # {UserModel}Profile model
db/migrate/xxx_create_user_profiles.rb            # Migration
app/controllers/[package/]user_profiles_controller.rb
app/policies/[package/]user_profile_policy.rb
app/definitions/[package/]user_profile_definition.rb
```

And modifies:
- **User model**: Adds `has_one :profile, class_name: "{UserModel}Profile", dependent: :destroy`
  > The association is **always named `:profile`** regardless of the class, so `current_user.profile` / `build_profile` / `params.require(:profile)` work uniformly.
- **Definition**: Injects custom ShowPage with SecuritySection

### The SecuritySection component

```ruby
class ProfileDefinition < Plutonium::Resource::Definition
  class ShowPage < ShowPage
    private

    def render_after_content
      render Plutonium::Profile::SecuritySection.new
    end
  end
end
```

Dynamically checks enabled Rodauth features and displays links for:

| Feature | Label |
|---------|-------|
| `change_password` | Change Password |
| `change_login` | Change Email |
| `otp` | Two-Factor Authentication |
| `recovery_codes` | Recovery Codes |
| `webauthn` | Security Keys |
| `active_sessions` | Active Sessions |
| `close_account` | Close Account |

### After generation

1. `rails db:migrate`
2. Connect to portal: `rails g pu:profile:conn --dest=customer_portal` — registers as singular resource (`/profile`) and enables `profile_url` helper.
3. Ensure users have a profile row:

```ruby
class User < ApplicationRecord
  after_create :create_profile!

  private

  def create_profile!
    create_profile
  end
end
```

### Customizing the profile definition

```ruby
class ProfileDefinition < Plutonium::Resource::Definition
  form do |f|
    f.field :bio
    f.field :avatar
    f.field :website
  end

  display do |d|
    d.field :bio
    d.field :avatar
    d.field :website
  end

  class ShowPage < ShowPage
    private

    def render_after_content
      render Plutonium::Profile::SecuritySection.new
    end
  end
end
```

### Profile link in header

```ruby
if respond_to?(:profile_url)
  link_to "Profile", profile_url
end
```

## Gotchas

- **Role index 0 is the most privileged.** For admin/saas roles, index 0 is owner/super_admin. Invite interactions default new invitees to index 1.
- **`owner` is always prepended** in `pu:saas:setup --roles`. Don't include it manually.
- **Profile association is always `:profile`**, even if the model class is `StaffUserProfile`.
- **`pu:saas:setup` is a meta-generator** — it also runs `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, and `pu:invites:install`. Don't rerun them separately.
- **Profile requires a connected portal** — without `pu:profile:conn`, `profile_url` is missing and the user menu link won't render.
- **Users need a profile row.** Add an `after_create` callback or use `find_or_create`.

## Feature reference

| Feature | Description |
|---------|-------------|
| `login` | Basic login/logout |
| `create_account` | User registration |
| `verify_account` | Email verification |
| `reset_password` | Password reset via email |
| `change_password` | Change password when logged in |
| `change_login` | Change email address |
| `verify_login_change` | Verify email change |
| `remember` | "Remember me" functionality |
| `otp` | TOTP two-factor authentication |
| `sms_codes` | SMS-based 2FA |
| `recovery_codes` | Backup codes for 2FA |
| `webauthn` | WebAuthn/passkey authentication |
| `lockout` | Lock account after failed attempts |
| `active_sessions` | Track/manage active sessions |
| `audit_logging` | Log authentication events |
| `email_auth` | Passwordless email login |
| `jwt` | JWT token authentication |
| `jwt_refresh` | JWT refresh tokens |
| `close_account` | Allow account deletion |

## Related skills

- `plutonium-installation` - Initial Plutonium setup
- `plutonium-portal` - Portal configuration
- `plutonium-policy` - Authorization after authentication
- `plutonium-invites` - User invitation system for multi-tenant apps
- `plutonium-definition` - Customizing the profile definition
- `plutonium-views` - Custom pages and components
