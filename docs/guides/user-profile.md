# User Profile

Add a profile / account-settings page where users edit personal fields and access Rodauth security features (change password, 2FA, etc.) in one place.

## Goal

A `/profile` URL that shows the user's personal fields plus a "Security" section linking to Rodauth-managed features.

## 🚨 Critical

- **Profile association is always `:profile`** regardless of the model class — `current_user.profile`, `build_profile`, `params.require(:profile)` always work.
- **Profile needs `pu:profile:conn` to be visible** — without it, no `/profile` route, no `profile_url` helper.
- **Every user needs a profile row.** Add an `after_create :create_profile!` callback to the user model. Without it, `current_user.profile` is nil.

## Quick path

```bash
rails g pu:profile:setup date_of_birth:date bio:text \
  --dest=competition \
  --portal=competition_portal
```

`pu:profile:setup` is a meta-generator — runs `pu:profile:install` + `pu:profile:conn` in one shot.

## Step-by-step

### 1. Install

```bash
rails generate pu:profile:install bio:text avatar:attachment 'timezone:string?' \
  --dest=customer
```

| Option | Default | Description |
|---|---|---|
| `--dest=DEST` | (prompts) | Target package or `main_app` |
| `--user-model=NAME` | `User` | Rodauth user model |

Custom resource name (first positional argument):

```bash
rails g pu:profile:install AccountSettings bio:text --dest=main_app
```

By default the model is `{UserModel}Profile` (`UserProfile`, `StaffUserProfile`, etc.).

### 2. Migrate

```bash
rails db:migrate
```

### 3. Connect to a portal

```bash
rails g pu:profile:conn --dest=customer_portal
```

This registers the profile as a **singular** resource — exposes `/profile` (no `:id`) and the `profile_url` helper.

### 4. Add the auto-create callback

```ruby
# app/models/user.rb (modified by pu:profile:install)
class User < ApplicationRecord
  has_one :profile, class_name: "UserProfile", dependent: :destroy

  after_create :create_profile!

  private
  def create_profile! = create_profile
end
```

For existing users at migration time:

```bash
rails runner "User.find_each(&:create_profile)"
```

## What you get

The generated definition injects a custom `ShowPage` that renders `SecuritySection` — dynamically lists Rodauth security links based on which features are enabled:

| Feature enabled | Link rendered |
|---|---|
| `change_password` | Change Password |
| `change_login` | Change Email |
| `otp` | Two-Factor Authentication |
| `recovery_codes` | Recovery Codes |
| `webauthn` | Security Keys |
| `active_sessions` | Active Sessions |
| `close_account` | Close Account |

If a feature isn't enabled, its link doesn't render — no configuration needed.

## Linking to the profile

```ruby
link_to("Profile", profile_url) if respond_to?(:profile_url)
```

The `respond_to?` guard is defensive — only portals that ran `pu:profile:conn` have the helper.

## Customizing the definition

The generated profile is a normal Plutonium definition. Customize like any other:

```ruby
class UserProfileDefinition < Plutonium::Resource::Definition
  field :bio, as: :markdown
  input :avatar, as: :uppy
  field :timezone, as: :select, choices: ActiveSupport::TimeZone.all.map(&:name)

  metadata :created_at, :updated_at

  class ShowPage < ShowPage
    private

    def render_after_content
      render Plutonium::Profile::SecuritySection.new
    end
  end
end
```

See [Reference › Resource › Definition](/reference/resource/definition) for the full definition surface.

## Multiple account types

If your app has both `User` and `StaffUser` accounts, run `pu:profile:install` once per:

```bash
rails g pu:profile:install --user-model=User --dest=main_app
rails g pu:profile:install --user-model=StaffUser --dest=main_app
```

Each gets its own `*Profile` model with `:profile` association on the respective user. Connect each to the appropriate portal:

```bash
rails g pu:profile:conn UserProfile      --dest=customer_portal
rails g pu:profile:conn StaffUserProfile --dest=admin_portal
```

## Common issues

- **`current_user.profile` is nil** — every user needs a profile row. Add `after_create :create_profile!` to the user model.
- **`profile_url` is undefined** — the profile isn't connected to this portal. Run `pu:profile:conn --dest=<portal>`.
- **`SecuritySection` shows nothing** — none of the relevant Rodauth features are enabled. Enable `change_password`, `otp`, etc. on the Rodauth plugin.

## Related

- [Reference › Auth › Profile](/reference/auth/profile) — full surface
- [Reference › Auth › Accounts](/reference/auth/accounts) — Rodauth feature flags that gate SecuritySection
- [Authentication](./authentication) — the underlying auth setup
