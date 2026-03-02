# User Profile

Plutonium provides a Profile resource generator for user account settings. The Profile page allows users to manage their personal information and access Rodauth security features like password changes, two-factor authentication, and session management.

## Overview

The profile system provides:
- **Profile Resource**: A standard Plutonium resource linked to the User model
- **Security Section**: Automatic display of enabled Rodauth security features
- **Customizable Fields**: Add any fields you need (bio, avatar, preferences, etc.)

## Prerequisites

Before installing the profile, ensure you have:

1. **User Authentication**: A Rodauth user account set up
2. **Model Markers**: The User model with marker comments

The easiest way to set this up is with the SaaS generator:

```bash
rails g pu:saas:user User
```

## Installation

### Step 1: Install the Profile Resource

```bash
rails generate pu:profile:install --dest=main_app
```

With custom fields:

```bash
rails g pu:profile:install \
    bio:text \
    avatar:attachment \
    'timezone:string?' \
    notifications_enabled:boolean \
    --dest=main_app
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--dest` | (prompts) | Target destination package or main_app |
| `--user-model` | User | Rodauth user model name |

### Step 2: Run Migrations

```bash
rails db:migrate
```

### Step 3: Connect to Portal

Connect the Profile to your portal using the profile connect generator:

```bash
rails g pu:profile:conn --dest=customer_portal
```

This:
- Registers the Profile as a singular resource (`/profile` instead of `/profiles/:id`)
- Configures the `profile_url` helper to enable the "Profile" link in the user menu

## Generated Files

The generator creates a standard Plutonium resource:

```
app/models/profile.rb
db/migrate/xxx_create_profiles.rb
app/controllers/profiles_controller.rb
app/policies/profile_policy.rb
app/definitions/profile_definition.rb
```

And modifies:
- **User model**: Adds `has_one :profile, dependent: :destroy`
- **Definition**: Injects custom ShowPage with security links

## Security Section

The ShowPage automatically displays links to enabled Rodauth security features.

Available features (only shown if enabled in Rodauth):

| Feature | Link Label | Description |
|---------|------------|-------------|
| `change_password` | Change Password | Update account password |
| `change_login` | Change Email | Update email address |
| `otp` | Two-Factor Authentication | Set up TOTP authenticator |
| `recovery_codes` | Recovery Codes | View or regenerate backup codes |
| `webauthn` | Security Keys | Manage passkeys and hardware keys |
| `active_sessions` | Active Sessions | View and revoke sessions |
| `close_account` | Close Account | Permanently delete account |

## Creating Profiles for Users

Users need a profile created before they can access it. Choose one approach:

### Option A: Automatic Creation on User Signup

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_one :profile, dependent: :destroy

  after_create :create_profile!

  private

  def create_profile!
    create_profile
  end

  # add has_one associations above.
end
```

### Option B: Create on First Access

In your portal's application controller:

```ruby
class ApplicationController < PlutoniumController
  before_action :ensure_profile

  private

  def ensure_profile
    return unless current_user
    current_user.profile || current_user.create_profile
  end
end
```

### Option C: Find or Create in Profile Controller

```ruby
# app/controllers/profiles_controller.rb
class ProfilesController < ResourceController
  private

  def current_resource
    @current_resource ||= current_user.profile || current_user.create_profile
  end
end
```

## Customization

### Adding Custom Fields

Edit the generated definition to configure how fields appear:

```ruby
# app/definitions/profile_definition.rb
class ProfileDefinition < Plutonium::Resource::Definition
  form do |f|
    f.field :bio, as: :text
    f.field :avatar, as: :attachment
    f.field :timezone, collection: ActiveSupport::TimeZone.all.map(&:name)
    f.field :notifications_enabled
  end

  display do |d|
    d.field :bio
    d.field :avatar
    d.field :timezone
    d.field :notifications_enabled
  end

  class ShowPage < ShowPage
    private

    def render_after_content
      render Plutonium::Profile::SecuritySection.new
    end
  end
end
```

### Custom Security Section

Create your own security section component:

```ruby
# app/components/custom_security_section.rb
class CustomSecuritySection < Plutonium::UI::Component::Base
  def view_template
    div(class: "mt-8") do
      h2(class: "text-lg font-semibold") { "Account Security" }

      if rodauth.features.include?(:change_password)
        a(href: rodauth.change_password_path) { "Change Password" }
      end

      # Add your custom links
      a(href: "/settings/notifications") { "Notification Preferences" }
    end
  end
end
```

Use it in your definition:

```ruby
class ProfileDefinition < Plutonium::Resource::Definition
  class ShowPage < ShowPage
    private

    def render_after_content
      render CustomSecuritySection.new
    end
  end
end
```

### Adding Profile Actions

Add custom actions to the profile:

```ruby
class ProfileDefinition < Plutonium::Resource::Definition
  action :export_data,
    interaction: Profile::ExportDataInteraction,
    icon: Phlex::TablerIcons::Download

  action :verify_email,
    interaction: Profile::VerifyEmailInteraction,
    category: :secondary
end
```

### Profile Link in Navigation

Add a profile link to your application layout or header:

```ruby
# In your header component
if current_user && respond_to?(:profile_path)
  a(href: profile_path) { "My Profile" }
end
```

## Policy Configuration

The generated policy controls access:

```ruby
# app/policies/profile_policy.rb
class ProfilePolicy < Plutonium::Resource::Policy
  # Users can only access their own profile
  def read?
    resource.user == user
  end

  def update?
    resource.user == user
  end

  def destroy?
    false # Disable deletion through the UI
  end

  # Only allow editing these attributes
  def permitted_attributes_for_update
    [:bio, :avatar, :timezone, :notifications_enabled]
  end
end
```

## Troubleshooting

### "Profile not found" Error

Ensure the user has a profile created. Use one of the creation strategies above.

### Security Links Not Showing

Security links only appear for features enabled in your Rodauth configuration:

```ruby
# app/rodauth/user_rodauth_plugin.rb
class UserRodauthPlugin < Plutonium::Auth::RodauthPlugin
  configure do
    enable :change_password, :change_login, :otp, :active_sessions
    # Only these features will show in the security section
  end
end
```

### Profile Routes Conflicting

Ensure you use `--singular` when connecting:

```bash
rails g pu:res:conn Profile --dest=my_portal --singular
```

This creates `/profile` (singular) instead of `/profiles/:id`.

### Changes Not Saving

Check your policy's `permitted_attributes_for_update`:

```ruby
def permitted_attributes_for_update
  [:bio, :avatar, :timezone, :notifications_enabled]
end
```

## Next Steps

- [Authentication](/guides/authentication) - Set up Rodauth features
- [Custom Actions](/guides/custom-actions) - Add profile actions
- [Views](/guides/views) - Customize the profile page
- [Authorization](/guides/authorization) - Configure profile policies
