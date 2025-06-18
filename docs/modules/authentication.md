---
title: Authentication Module
---

# Authentication Module

The Authentication module provides comprehensive authentication capabilities for Plutonium applications. It integrates seamlessly with Rodauth for authentication while offering flexibility for different application security needs.

::: tip
The Authentication module is located in `lib/plutonium/auth/`.
:::

## Overview

- **Rodauth Integration**: Seamless integration with Rodauth authentication
- **Public Access Support**: Optional public access for applications without authentication
- **Multi-Account Support**: Support for multiple user types and authentication contexts
- **Portal-Aware Security**: Authentication scoped to specific portals/packages
- **Flexible Configuration**: Support for custom authentication systems
- **Security Features**: Built-in security best practices and configurations

## Core Components

::: code-group
```ruby [Rodauth Integration]
# lib/plutonium/auth/rodauth.rb
# Basic Rodauth integration
module MyApp
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Auth::Rodauth(:main)

      # Automatically provides:
      # - current_user helper method
      # - logout_url helper method
      # - Proper URL options handling
    end
  end
end
```

```ruby [Public Access]
# For applications that don't require authentication
module MyApp
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Auth::Public
    end
  end
end
```

```ruby [Custom Authentication]
# For applications using custom authentication systems
module MyApp
  module Concerns
    module Controller
      extend ActiveSupport::Concern

      included do
        helper_method :current_user
      end

      def current_user
        # Your custom authentication logic
        @current_user ||= User.find(session[:user_id]) if session[:user_id]
      end
    end
  end
end
```
:::

### Automatic Helper Methods

When you include `Plutonium::Auth::Rodauth`, you automatically get:

- `current_user`: Returns the authenticated user/account (available in controllers and views).
- `logout_url`: Returns the logout URL for the current account type (available in controllers and views).
- `rodauth`: Access to the Rodauth instance (available in controllers only).

## Rodauth Configuration

### Account Generation

Plutonium provides generators for creating Rodauth accounts:

::: code-group
```bash [Basic User Account]
rails generate pu:rodauth:account user
```

```bash [Admin Account]
rails generate pu:rodauth:admin admin
```

```bash [Custom Features]
rails generate pu:rodauth:account customer \
  --no-defaults \
  --login --logout --create-account --verify-account \
  --reset-password --change-password --remember
```
:::

### Configuration Examples

::: details Standard Rodauth Plugin Configuration
```ruby
# app/rodauth/user_rodauth_plugin.rb
class UserRodauthPlugin < RodauthPlugin
  configure do
    # Enable features
    enable :login, :logout, :create_account, :verify_account,
           :reset_password, :change_password, :remember

    # Account model
    rails_account_model { User }

    # Controller for views and CSRF
    rails_controller { Rodauth::UserController }

    # Redirects
    login_redirect "/"
    logout_redirect "/"
    create_account_redirect "/"

    # Email configuration
    create_reset_password_email do
      UserMailer.reset_password(account_id, reset_password_key_value)
    end

    # Remember feature
    after_login { remember_login }
    extend_remember_deadline? true

    # Password requirements
    password_minimum_length 8

    # Custom validation
    before_create_account do
      throw_error_status(422, "name", "must be present") if param("name").empty?
    end
  end
end
```
:::

::: details Enhanced Admin Configuration with MFA
```ruby
# app/rodauth/admin_rodauth_plugin.rb
class AdminRodauthPlugin < RodauthPlugin
  configure do
    enable :login, :logout, :create_account, :verify_account,
           :reset_password, :change_password, :remember,
           :otp, :recovery_codes, :lockout, :active_sessions,
           :audit_logging, :password_grace_period, :internal_request

    # Account model
    rails_account_model { Admin }

    # Controller
    rails_controller { Rodauth::AdminController }

    # Prefix for admin routes
    prefix "/admin"

    # Require MFA setup
    two_factor_not_setup_error_flash "You need to setup two factor authentication"
    two_factor_auth_return_to_requested_location? true

    # Multi-phase login for enhanced security
    use_multi_phase_login? true

    # Prevent web signup for admin accounts
    before_create_account_route do
      request.halt unless internal_request?
    end

    # Enhanced security settings
    max_invalid_logins 3
    lockout_deadline_interval Hash[minutes: 60]

    # Session security
    session_key "_admin_session"
    remember_cookie_key "_admin_remember"
  end
end
```
:::

## Portal Integration

Each portal can have its own authentication requirements, allowing you to secure different parts of your application with different user types.

::: code-group
```ruby [Admin Portal]
# Admin portal with admin authentication
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

```ruby [Customer Portal]
# Customer portal with customer authentication
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

```ruby [Public Portal]
# Public portal without authentication
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
:::
