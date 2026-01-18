# Authentication

This guide covers setting up user authentication with Rodauth.

## Overview

Plutonium uses [Rodauth](http://rodauth.jeremyevans.net/) via [rodauth-rails](https://github.com/janko/rodauth-rails) for authentication, providing:
- User registration and login
- Password reset
- Email verification
- Multi-factor authentication (OTP, WebAuthn, SMS)
- Session management
- Account lockout

## Installation

### New Applications

The Plutonium template installs Rodauth automatically:

```bash
rails new myapp -m https://radioactive-labs.github.io/plutonium-core/templates/plutonium.rb
```

### Existing Applications

```bash
rails g pu:rodauth:install
rails db:migrate
```

This installs:
- Required gems (`rodauth-rails`, `bcrypt`, `sequel-activerecord_connection`)
- `app/rodauth/rodauth_app.rb` - Main Roda app
- `app/rodauth/rodauth_plugin.rb` - Base plugin
- `app/controllers/rodauth_controller.rb` - Base controller
- `config/initializers/rodauth.rb` - Configuration

## Creating Account Types

### Basic User Account

```bash
rails g pu:rodauth:account user
rails db:migrate
```

**Default features** (enabled with `--defaults`, which is on by default):
- `login`, `logout`, `remember`
- `create_account`, `verify_account`, `verify_account_grace_period`
- `reset_password`, `reset_password_notify`
- `change_login`, `verify_login_change`
- `change_password`, `change_password_notify`
- `case_insensitive_login`, `internal_request`

### Admin Account

```bash
rails g pu:rodauth:admin admin
rails db:migrate
```

Includes all base features plus:
- Multi-phase login (email first, then password)
- TOTP two-factor authentication (required)
- Recovery codes
- Account lockout
- Active sessions tracking
- Audit logging
- **No public signup** - accounts created via rake task

### Customer Account

```bash
rails g pu:rodauth:customer customer
rails g pu:rodauth:customer customer --entity=Organization
rails g pu:rodauth:customer customer --no-allow_signup
rails db:migrate
```

Creates a customer account with an associated entity model (for multi-tenancy):
- Customer account model
- Entity model (Organization, Company, etc.)
- Membership join model with has-many-through associations

## Generator Options

### Feature Options

```bash
# Enable all supported features
rails g pu:rodauth:account user --kitchen_sink

# Disable default features (explicit selection only)
rails g pu:rodauth:account user --no-defaults

# Enable specific features
rails g pu:rodauth:account user --otp --recovery_codes --lockout

# Skip email setup
rails g pu:rodauth:account user --no-mails

# API-only mode (JWT, no sessions)
rails g pu:rodauth:account user --api_only --jwt --jwt_refresh

# Use Argon2 instead of bcrypt
rails g pu:rodauth:account user --argon2

# Mark as primary account (no URL prefix)
rails g pu:rodauth:account user --primary
```

### Available Features

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

## Generated Files

```
app/
├── controllers/rodauth/
│   └── user_controller.rb          # Account-specific controller
├── mailers/rodauth/
│   └── user_mailer.rb              # Account-specific mailer
├── models/
│   └── user.rb                     # Account model
├── rodauth/
│   ├── rodauth_app.rb              # Main Roda app
│   ├── rodauth_plugin.rb           # Base plugin
│   └── user_rodauth_plugin.rb      # Account-specific config
├── policies/
│   └── user_policy.rb              # Account policy
├── definitions/
│   └── user_definition.rb          # Account definition
└── views/rodauth/
    └── user_mailer/                # Email templates
db/migrate/
└── xxx_create_users.rb             # Account table migration
```

## Connecting Auth to Controllers

Include the auth module in your controller to require authentication:

```ruby
# app/controllers/resource_controller.rb
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller
  include Plutonium::Auth::Rodauth(:user)
end
```

This provides:

| Method | Description |
|--------|-------------|
| `current_user` | The authenticated account |
| `logout_url` | URL to logout |
| `rodauth` | Access to Rodauth instance |

### Portal Configuration

For portals, include the auth module in the controller concern:

```ruby
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:admin)
    end
  end
end
```

## Accessing the Current User

```ruby
# In controllers
def index
  @user_posts = current_user.posts
end

# In views (helper method)
<% if current_user.present? %>
  Welcome, <%= current_user.email %>
<% end %>
```

## Rodauth Plugin Configuration

The generated plugin file contains configuration options:

```ruby
# app/rodauth/user_rodauth_plugin.rb
class UserRodauthPlugin < RodauthPlugin
  configure do
    # Features enabled for this account
    enable :login, :logout, :remember, :create_account, ...

    # URL prefix (non-primary accounts)
    prefix "/users"

    # Store password in column (not separate table)
    account_password_hash_column :password_hash

    # Controller for views
    rails_controller { Rodauth::UserController }

    # Model
    rails_account_model { User }

    # Redirects
    login_redirect "/"
    logout_redirect "/"

    # Session configuration
    session_key "_user_session"
    remember_cookie_key "_user_remember"
  end
end
```

### Custom Login Redirect

```ruby
configure do
  login_redirect { "/dashboard" }

  # Or dynamically
  login_redirect do
    if rails_account.admin?
      "/admin"
    else
      "/dashboard"
    end
  end
end
```

### Password Requirements

```ruby
configure do
  # Minimum length (default: 8)
  password_minimum_length 12

  # Custom complexity
  password_meets_requirements? do |password|
    super(password) && password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
  end
end
```

### Multi-Phase Login

```ruby
configure do
  # Ask for email first, then password
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

## Email Configuration

Emails are sent via Action Mailer.

### Development

```ruby
# Gemfile
gem "letter_opener", group: :development

# config/environments/development.rb
config.action_mailer.delivery_method = :letter_opener
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
```

### Production

```ruby
# config/environments/production.rb
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV['SMTP_HOST'],
  port: ENV['SMTP_PORT'],
  user_name: ENV['SMTP_USER'],
  password: ENV['SMTP_PASSWORD']
}
```

### Custom Email Templates

Override templates in `app/views/rodauth/user_mailer/`:

```erb
<%# app/views/rodauth/user_mailer/reset_password.text.erb %>
Hi <%= @account.email %>,

Someone requested a password reset for your account.

Reset your password: <%= @reset_password_url %>

If you didn't request this, ignore this email.
```

## Customizing Views

Generate views to customize:

```bash
# Generate views for specific features
rails g pu:rodauth:views user --features login create_account reset_password

# Generate all views
rails g pu:rodauth:views user --all
```

Views are copied to `app/views/rodauth/user/` and can be customized as standard ERB templates.

## Multiple Account Types

### Different Portals, Different Accounts

```ruby
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:admin)
    end
  end
end

# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
module CustomerPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Rodauth(:customer)
    end
  end
end
```

### Shared Account Type

Multiple portals can share an account type:

```ruby
# Both portals include the same auth module
include Plutonium::Auth::Rodauth(:user)
```

## Public Portals

For portals that don't require authentication, use `Plutonium::Auth::Public`:

```ruby
# packages/public_portal/app/controllers/public_portal/concerns/controller.rb
module PublicPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller
      include Plutonium::Auth::Public
    end
  end
end
```

This provides a `current_user` method that returns `"Guest"`.

## Two-Factor Authentication

### Enable During Generation

```bash
rails g pu:rodauth:account user --otp --recovery_codes
```

### Add to Existing Account

```ruby
# app/rodauth/user_rodauth_plugin.rb
configure do
  enable :otp, :recovery_codes

  # Require 2FA
  two_factor_auth_required? true
end
```

Note: The `pu:rodauth:admin` generator automatically enables OTP and recovery codes.

## Creating Accounts

### Admin Accounts

Admin accounts are created via rake task (web registration is disabled):

```bash
# Interactive prompt for email
rails rodauth:admin

# With EMAIL environment variable
EMAIL=admin@example.com rails rodauth:admin
```

The task name matches the account name (e.g., `rails rodauth:admin` for an account named `admin`).

### Programmatic Account Creation

For accounts with self-registration enabled, use internal requests:

```ruby
# Create account via internal request
RodauthApp.rodauth(:user).create_account(
  login: "user@example.com",
  password: "secure_password"
)
```

In seeds:

```ruby
# db/seeds.rb
RodauthApp.rodauth(:user).create_account(
  login: "user@example.com",
  password: "password123"
)
```

## API Authentication

For JSON API authentication:

```bash
rails g pu:rodauth:account api_user --api_only --jwt --jwt_refresh
```

This enables:
- JWT token authentication
- Refresh tokens
- No session/cookie handling

### Using JWT

```bash
# Login
curl -X POST http://localhost:3000/api_users/login \
  -H "Content-Type: application/json" \
  -d '{"login": "user@example.com", "password": "secret"}'

# Response includes tokens
{"access_token": "...", "refresh_token": "..."}

# Authenticated requests
curl http://localhost:3000/api/posts \
  -H "Authorization: Bearer <access_token>"
```

## Troubleshooting

### Routes Not Working

Restart the server after installing Rodauth:

```bash
bin/rails restart
```

### Emails Not Sending

Check Action Mailer configuration:

```ruby
# Verify mailer config
Rails.application.config.action_mailer.delivery_method
Rails.application.config.action_mailer.default_url_options
```

Use letter_opener in development to view emails in browser.

### Session Issues

Clear session cookies in the browser, or for active_sessions feature:

```ruby
# In rails runner
User.find_by(email: "user@example.com").active_session_keys.delete_all
```

### Migration Issues

Ensure all migrations have run:

```bash
rails db:migrate:status
rails db:migrate
```

### Account Not Verified

For development, you can manually verify accounts:

```ruby
# In rails runner
user = User.find_by(email: "user@example.com")
user.update!(status: 2)  # 2 = verified
```

## Related

- [Authorization](./authorization)
- [Multi-tenancy](./multi-tenancy)
