# Profile

Manages Rodauth account settings as a Plutonium resource — users view/edit personal fields and access Rodauth security features (change password, 2FA, etc.) on one page.

## 🚨 Critical

- **Profile association is always `:profile`** regardless of the model class — `current_user.profile`, `build_profile`, `params.require(:profile)` always work.
- **Profile needs `pu:profile:conn`** — without it, no route, no `profile_url` helper, no user-menu link.
- **Every user needs a profile row** — add an `after_create` callback (or `find_or_create_by`). Without it, `current_user.profile` is nil and the profile route errors.

## Quick setup

```bash
rails g pu:profile:setup date_of_birth:date bio:text \
  --dest=competition \
  --portal=competition_portal
```

Meta-generator: runs `pu:profile:install` + `pu:profile:conn` in one shot.

## Step-by-step

```bash
rails generate pu:profile:install bio:text avatar:attachment 'timezone:string?' \
  --dest=customer

rails db:migrate

rails generate pu:profile:conn --dest=customer_portal
```

| Option | Default | Description |
|---|---|---|
| `--dest=DEST` | (prompts) | Target package or `main_app` |
| `--user-model=NAME` | `User` | Rodauth user model |

Custom resource name (first positional argument):

```bash
rails g pu:profile:install AccountSettings bio:text --dest=main_app
```

## What gets created

By default the model is `{UserModel}Profile` — `UserProfile`, `StaffUserProfile`, etc. — derived from `--user-model`.

```
app/models/[package/]user_profile.rb
db/migrate/xxx_create_user_profiles.rb
app/controllers/[package/]user_profiles_controller.rb
app/policies/[package/]user_profile_policy.rb
app/definitions/[package/]user_profile_definition.rb
```

The generator modifies the user model:

```ruby
has_one :profile, class_name: "UserProfile", dependent: :destroy
```

::: warning Association name is fixed
Even when the class is `StaffUserProfile`, the association is `:profile`. Don't rename it — `current_user.profile`, `build_profile`, `params.require(:profile)` all assume this.
:::

The generated definition injects a custom `ShowPage` that renders the `SecuritySection` component.

## The `SecuritySection` component

Dynamically lists Rodauth security links based on which features are enabled on the account.

| Feature enabled | Link rendered |
|---|---|
| `change_password` | Change Password |
| `change_login` | Change Email |
| `otp` | Two-Factor Authentication |
| `recovery_codes` | Recovery Codes |
| `webauthn` | Security Keys |
| `active_sessions` | Active Sessions |
| `close_account` | Close Account |

If a feature isn't enabled on the account, its link doesn't render — no configuration needed.

To customize (e.g. add chrome, reorder), override `ShowPage#render_after_content`:

```ruby
class UserProfileDefinition < Plutonium::Resource::Definition
  class ShowPage < ShowPage
    private

    def render_after_content
      render Plutonium::Profile::SecuritySection.new
    end
  end
end
```

See [UI › Pages](/reference/ui/pages) for page-class customization.

## Required: every user gets a profile

```ruby
class User < ApplicationRecord
  after_create :create_profile!

  private
  def create_profile! = create_profile
end
```

Without this, `current_user.profile` returns nil and the profile route errors. For existing users at migration time, run a one-off backfill:

```bash
rails runner "User.find_each(&:create_profile)"
```

## Connecting to a portal

`pu:profile:conn` registers the profile as a **singular** resource — `/profile` (no `:id`), and exposes the `profile_url` helper:

```bash
rails g pu:profile:conn --dest=customer_portal
```

This is what makes the profile visible. Without it, the model exists but has no route in any portal.

## Linking to the profile

```ruby
link_to("Profile", profile_url) if respond_to?(:profile_url)
```

The `respond_to?` guard is defensive — only portals that ran `pu:profile:conn` have the helper.

## Customizing the definition

The generated definition is a normal Plutonium resource definition. Customize like any other:

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

See [Resource › Definition](/reference/resource/definition) for the full definition surface.

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

## Gotchas

- **`current_user.profile` is nil** — every user needs a profile row. Add `after_create :create_profile!` to the user model.
- **`profile_url` is undefined** — the profile isn't connected to this portal. Run `pu:profile:conn --dest=<portal>`.
- **Custom resource name** — pass it as the first positional argument to `pu:profile:install`. The association is still `:profile`.
- **SecuritySection shows nothing** — none of the relevant Rodauth features are enabled on the account. Enable `change_password`, `otp`, etc. on the Rodauth plugin.

## Related

- [Accounts](./accounts) — Rodauth feature flags that gate SecuritySection links
- [Resource › Definition](/reference/resource/definition) — customizing the profile definition
- [App › Generators › Profile generators](/reference/app/generators#profile-generators)
