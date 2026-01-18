# Chapter 3: Setting Up Authentication

In this chapter, you'll configure Rodauth for user authentication.

## What is Rodauth?

Rodauth is a Ruby authentication framework that Plutonium uses for:
- User registration and login
- Password reset and email verification
- Multi-factor authentication
- Session management

Plutonium integrates Rodauth seamlessly with its portal system.

## Setting Up Authentication

If you used the Plutonium template, Rodauth is already installed. If not:

```bash
rails generate pu:rodauth:install
rails db:migrate
```

## Creating an Account Type

Plutonium supports multiple account types. For admin accounts that cannot self-register, use the `admin` generator:

```bash
rails generate pu:rodauth:admin admin
```

This creates:

### Account Model (`app/models/admin.rb`)

```ruby
class Admin < ResourceRecord
  include Rodauth::Rails.model(:admin)
end
```

### Rodauth Plugin (`app/rodauth/admin_rodauth_plugin.rb`)

```ruby
class AdminRodauthPlugin < RodauthPlugin
  configure do
    # Multi-phase login, 2FA, lockout, audit logging enabled
    enable :login, :remember, :logout, ...

    # No public signup - accounts created via rake task
    before_create_account_route do
      request.halt unless internal_request?
    end
  end
end
```

The generator also creates migrations for the account table and authentication features.

## Configuring the Portal

Authentication is configured in the portal's controller concern. Update it to use Rodauth:

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

This provides `current_user` and authentication helpers throughout the portal.

## Running Migrations

```bash
rails db:migrate
```

## Testing Authentication

Restart your server:

```bash
bin/dev
```

Visit `http://localhost:3000/admin/blogging/posts`. You'll be redirected to the login page.

### Creating an Admin Account

Admin accounts are created via rake task (web registration is disabled for security):

```bash
rails rodauth:admin
# Or with EMAIL environment variable:
EMAIL=admin@example.com rails rodauth:admin
```

The task will prompt for an email if not provided and send a verification email with password setup instructions.

Now log in with the account you created.

## Customizing the Login Page

The login page uses Plutonium's default theme. To customize it:

```ruby
# packages/admin_portal/app/views/admin_portal/auth/login.rb
module AdminPortal
  module Auth
    class Login < Plutonium::Auth::View::Login
      def page_title
        "Admin Login"
      end

      def welcome_message
        "Sign in to manage your blog"
      end
    end
  end
end
```

## Email Configuration

For password reset and email verification, configure Action Mailer:

```ruby
# config/environments/development.rb
config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
config.action_mailer.delivery_method = :letter_opener # Or :smtp for real emails
```

## Creating the User Account Type

Our blog needs users (authors) who can create posts. Let's create a User account type that allows self-registration:

```bash
rails generate pu:rodauth:account user
rails db:migrate
```

This creates a `User` model similar to `Admin`, but with public registration enabled.

### Linking Posts to Users

Now we can add the author relationship to our Post model. Generate a migration:

```bash
rails generate migration AddUserToBloggingPosts user:belongs_to
```

Update the migration to add the foreign key:

```ruby
class AddUserToBloggingPosts < ActiveRecord::Migration[8.0]
  def change
    add_reference :blogging_posts, :user, null: false, foreign_key: true
  end
end
```

Run the migration:

```bash
rails db:migrate
```

Update the Post model to include the association:

```ruby
# packages/blogging/app/models/blogging/post.rb
class Blogging::Post < Blogging::ResourceRecord
  belongs_to :user
  # ... existing code
end
```

Also update the Post policy to include user in permitted attributes:

```ruby
# packages/blogging/app/policies/blogging/post_policy.rb
class Blogging::PostPolicy < Blogging::ResourcePolicy
  def permitted_attributes_for_create
    [:title, :body, :published, :user_id]
  end

  def permitted_attributes_for_read
    [:title, :body, :published, :user, :created_at]
  end

  def permitted_associations
    %i[user]
  end
end
```

Now posts are linked to their authors, which we'll use for authorization in the next chapter.

## Multiple Account Types

You can have different account types for different portals:

```bash
# Create an author account type (if using a different name than "user")
rails generate pu:rodauth:account author
```

Then configure each portal's controller concern:

```ruby
# packages/admin_portal/app/controllers/admin_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:admin)

# packages/author_portal/app/controllers/author_portal/concerns/controller.rb
include Plutonium::Auth::Rodauth(:author)
```

## Session Configuration

Rodauth sessions can be configured in the Rodauth plugin:

```ruby
# app/rodauth/admin_rodauth_plugin.rb
class AdminRodauthPlugin < RodauthPlugin
  configure do
    # Session expires after 30 days
    session_expiration_seconds 30.days.to_i

    # Require re-authentication for sensitive actions
    password_grace_period 3600
  end
end
```

## What's Next

Users can now log in, but anyone can do anything. In the next chapter, we'll implement authorization policies to control access.

[Continue to Chapter 4: Implementing Authorization →](./04-authorization)
