---
name: plutonium-profile
description: Use when adding a user profile or account settings page with Rodauth security features
---

# Plutonium User Profile

Plutonium provides a Profile resource generator for managing Rodauth account settings. The profile resource allows users to:
- View and edit their profile information
- Access Rodauth security features (change password, 2FA, etc.)
- Manage their account settings in one place

## Quick Setup

Use the setup generator to create and connect the profile in one command:

```bash
rails g pu:profile:setup date_of_birth:date bio:text \
    --dest=competition \
    --portal=competition_portal
```

## Step-by-Step Installation

### Install the Profile Resource

```bash
rails generate pu:profile:install --dest=main_app
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--dest=DESTINATION` | (prompts) | Target package or main_app |
| `--user-model=NAME` | User | Rodauth user model name |

**With custom fields:**

```bash
rails g pu:profile:install \
    bio:text \
    avatar:attachment \
    'timezone:string?' \
    --dest=customer
```

**With custom name:**

```bash
rails g pu:profile:install AccountSettings \
    bio:text \
    --dest=main_app
```

## What Gets Created

The generator creates a standard Plutonium resource:

```
app/models/[package/]profile.rb              # Profile model
db/migrate/xxx_create_profiles.rb            # Migration
app/controllers/[package/]profiles_controller.rb
app/policies/[package/]profile_policy.rb
app/definitions/[package/]profile_definition.rb
```

And modifies:
- **User model**: Adds `has_one :profile, dependent: :destroy`
- **Definition**: Injects custom ShowPage with SecuritySection

## The SecuritySection Component

The generator injects a custom `ShowPage` that renders `Plutonium::Profile::SecuritySection`:

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

The `SecuritySection` component dynamically checks which Rodauth features are enabled and displays links for:

| Feature | Label | Description |
|---------|-------|-------------|
| `change_password` | Change Password | Update account password |
| `change_login` | Change Email | Update email address |
| `otp` | Two-Factor Authentication | Set up TOTP |
| `recovery_codes` | Recovery Codes | View/regenerate backup codes |
| `webauthn` | Security Keys | Manage passkeys |
| `active_sessions` | Active Sessions | View/manage sessions |
| `close_account` | Close Account | Delete account |

Only enabled Rodauth features are displayed.

## After Generation

### 1. Run Migrations

```bash
rails db:migrate
```

### 2. Connect to Portal

Use the profile connect generator to register as a singular resource and configure the `profile_url` helper:

```bash
rails g pu:profile:conn --dest=customer_portal
```

This:
- Registers the Profile as a singular resource (`/profile` instead of `/profiles/:id`)
- Adds `profile_url` helper to enable the "Profile" link in the user menu

### 3. Create Profile Automatically

Users need a profile created. Add a callback or use `find_or_create`:

```ruby
# Option A: Callback on User
class User < ApplicationRecord
  after_create :create_profile!

  private

  def create_profile!
    create_profile
  end
end

# Option B: In controller or before_action
def current_profile
  @current_profile ||= current_user.profile || current_user.create_profile
end
```

## Customization

### Adding Profile Fields

Add fields during generation:

```bash
rails g pu:profile:install \
    bio:text \
    avatar:attachment \
    website:string \
    'company:string?' \
    --dest=main_app
```

Or add to the migration manually before running.

### Customizing the Definition

Edit the generated definition:

```ruby
# app/definitions/profile_definition.rb
class ProfileDefinition < Plutonium::Resource::Definition
  # Form configuration
  form do |f|
    f.field :bio
    f.field :avatar
    f.field :website
  end

  # Display configuration
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

### Custom Security Section

Override the SecuritySection or create your own:

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

### Adding Custom Actions

Add profile-specific actions:

```ruby
class ProfileDefinition < Plutonium::Resource::Definition
  action :export_data,
    interaction: Profile::ExportDataInteraction

  action :verify_email,
    interaction: Profile::VerifyEmailInteraction,
    category: :secondary
end
```

## Profile Link in Header

To add a profile link to the resource header, the `profile_url` helper is available via `Plutonium::Auth::Rodauth`:

```ruby
# In your controller or view
if respond_to?(:profile_url)
  link_to "Profile", profile_url
end
```

This helper is automatically available when Profile is connected to a portal.

## Troubleshooting

### "User model not found"

Ensure the User model exists at `app/models/user.rb` with the marker comment:

```ruby
class User < ApplicationRecord
  # add has_one associations above.
end
```

### "Definition path not found"

If using a package destination, ensure the package exists:

```bash
# Check available packages
ls packages/
```

### Profile Not Loading

Ensure the Profile is connected to your portal:

```bash
rails g pu:res:conn Profile --dest=my_portal --singular
```

And the user has a profile:

```ruby
current_user.profile || current_user.create_profile
```

## Related Skills

- `plutonium-rodauth` - Authentication configuration
- `plutonium-definition` - Customizing the profile definition
- `plutonium-views` - Custom pages and components
- `plutonium-portal` - Connecting resources to portals
