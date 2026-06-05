---
name: plutonium-auth
description: Use BEFORE installing Rodauth, configuring account types, building login/password flows, or wiring a profile / account-settings page. Covers the full auth surface — Rodauth installation, accounts, admin accounts, SaaS setup, profile resource, security section.
---

# Plutonium Auth — Rodauth + Profile

Plutonium integrates [Rodauth](http://rodauth.jeremyevans.net/) via [rodauth-rails](https://github.com/janko/rodauth-rails). This skill covers installing Rodauth, generating account types (basic / admin / SaaS), wiring auth into controllers and portals, and the profile / account-settings resource.

For multi-tenant invitations and membership, see [[plutonium-tenancy]] › Invites. For portal-side wiring, see [[plutonium-app]] › Portal Engines.

## 🚨 Critical (read first)

- **Use the generators.** `pu:rodauth:install`, `pu:rodauth:account`, `pu:rodauth:admin`, `pu:saas:setup`, `pu:profile:install`, `pu:profile:conn`. Never hand-write Rodauth plugin files, account models, or profile resources.
- **Role index 0 is the most privileged** (`owner`, `super_admin`). Invite interactions default new invitees to **index 1**.
- **`pu:saas:setup --roles=...` always prepends `owner` as index 0.** Don't include `owner` in the option.
- **`pu:saas:setup` is a meta-generator.** It also runs `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, and `pu:invites:install`. Don't re-run those manually.
- **Profile association is always `:profile`** regardless of the model class — `current_user.profile`, `build_profile`, `params.require(:profile)`.
- **Profile needs `pu:profile:conn` to be visible** — without it, the singular `/profile` route and `profile_url` helper don't exist.
- **Every user needs a profile row.** Add an `after_create` callback or `find_or_create_by` — otherwise `current_user.profile` is nil.

---

## Install

```bash
rails generate pu:rodauth:install
```

Installs gems (`rodauth-rails`, `bcrypt`, `sequel-activerecord_connection`), the Roda app at `app/rodauth/rodauth_app.rb`, base plugin and controller, initializer, layout, and a PostgreSQL extension migration if applicable.

---

## Account types

Pick one (or several — apps can have multiple account types side-by-side).

### Basic account — `pu:rodauth:account`

```bash
rails generate pu:rodauth:account user [options]
```

| Option | Description |
|---|---|
| `--defaults` | Enables login, logout, remember, password reset |
| `--kitchen_sink` | Enables ALL features |
| `--no-mails` | Skip mailer setup |
| `--argon2` | Use Argon2 instead of bcrypt |
| `--api_only` | JSON API only (no sessions) |

### Feature flags

| Flag | Default | Purpose |
|---|---|---|
| `--login`, `--logout`, `--remember` | ✓ | Basic auth |
| `--create_account`, `--verify_account` | ✓ | Registration + email verification |
| `--reset_password`, `--change_password` | ✓ | Password lifecycle |
| `--change_login`, `--verify_login_change` | ✓ | Email change |
| `--otp` | | TOTP 2FA |
| `--webauthn` | | WebAuthn / passkeys |
| `--recovery_codes` | | 2FA backup codes |
| `--lockout` | | Lock after failed attempts |
| `--active_sessions` | | Track active sessions |
| `--audit_logging` | | Log auth events |
| `--close_account` | | Allow account deletion |
| `--email_auth` | | Passwordless email login |
| `--sms_codes` | | SMS 2FA |
| `--jwt`, `--jwt_refresh` | | JWT for API auth |

### Admin account — `pu:rodauth:admin`

Pre-configured secure admin with multi-phase login, required TOTP, recovery codes, lockout, active session tracking, audit logging, role-based access, invite interaction, and **no public signup**.

```bash
rails generate pu:rodauth:admin admin
rails generate pu:rodauth:admin admin --roles=super_admin,admin,viewer
rails generate pu:rodauth:admin admin --extra-attributes=name:string,department:string
```

| Option | Default | Description |
|---|---|---|
| `--roles` | `super_admin,admin` | Comma-separated roles (positional enum) |
| `--extra_attributes` | | Additional model attributes (e.g. `name:string`) |

**Role-ordering convention:** index 0 is the most privileged. Generated invite interaction defaults new invitees to `roles[1]` — the order in `--roles=` matters.

```ruby
enum :role, super_admin: 0, admin: 1
```

Rake task for direct admin creation (namespace is `rodauth`, task name is the account name):

```bash
EMAIL=admin@example.com rails rodauth:admin
# (run without EMAIL to be prompted)
```

Creates the account and sends a verification email; the admin sets their own password through the flow. No password is passed on the command line.

### SaaS setup — `pu:saas:setup` (meta-generator)

Creates the User + Entity + Membership trio AND runs:

- `pu:saas:portal` → a full `{Entity}Portal` scoped to the entity
- `pu:profile:setup` → profile model + association
- `pu:saas:welcome` → onboarding / select-entity flow
- `pu:invites:install` → the invites package (see [[plutonium-tenancy]])

Don't generate another entity portal after this. Pass `--force` to re-run.

```bash
rails g pu:saas:setup --user Customer --entity Organization
rails g pu:saas:setup --user Customer --entity Organization --roles=admin,member
rails g pu:saas:setup --user Customer --entity Organization --no-allow-signup
rails g pu:saas:setup --user Customer --entity Organization \
  --user-attributes=name:string --entity-attributes=slug:string
```

| Option | Default | Description |
|---|---|---|
| `--user=NAME` | (required) | User account model name |
| `--entity=NAME` | (required) | Entity model name |
| `--allow-signup` | `true` | Allow public registration |
| `--roles` | `admin,member` | Additional roles. **`owner` always prepended as index 0** |
| `--skip-entity` | | Skip entity model generation |
| `--skip-membership` | | Skip membership model generation |
| `--user-attributes`, `--entity-attributes`, `--membership-attributes` | | Extra model fields |

Individual generators (rarely needed): `pu:saas:user`, `pu:saas:entity`, `pu:saas:membership`.

Generated user + membership:

```ruby
class Customer < ApplicationRecord
  include Rodauth::Rails.model(:customer)
  has_many :organization_customers, dependent: :destroy
  has_many :organizations, through: :organization_customers
end

class OrganizationCustomer < ApplicationRecord
  belongs_to :organization
  belongs_to :customer
  enum :role, owner: 0, admin: 1, member: 2

  validates :customer, uniqueness: {
    scope: :organization_id,
    message: "is already a member of this organization"
  }
end
```

---

## Wiring auth into controllers

```ruby
class ResourceController < PlutoniumController
  include Plutonium::Resource::Controller
  include Plutonium::Auth::Rodauth(:user)
end
```

Multiple account types — include the matching `:name`:

```ruby
class AdminController < PlutoniumController
  include Plutonium::Resource::Controller
  include Plutonium::Auth::Rodauth(:admin)
end
```

`Plutonium::Auth::Rodauth(:name)` exposes `current_user`, `logout_url`, and `rodauth` in the controller.

For portal wiring (`AdminPortal::Concerns::Controller`), see [[plutonium-app]] › Portal controller concern.

---

## Common customizations

All inside the Rodauth `configure do ... end` block in `app/rodauth/<name>_rodauth_plugin.rb`.

### Custom login redirect

```ruby
login_redirect do
  rails_account.admin? ? "/admin" : "/dashboard"
end
```

### Custom create-account validation + hook

```ruby
before_create_account do
  throw_error_status(422, "name", "must be present") if param("name").empty?
end

after_create_account do
  Profile.create!(account_id: account_id, name: param("name"))
end
```

### Password requirements

```ruby
password_minimum_length 12

password_meets_requirements? do |password|
  super(password) && password.match?(/\d/) && password.match?(/[^a-zA-Z\d]/)
end
```

### Multi-phase login (password on a separate page)

```ruby
use_multi_phase_login? true
```

### Prevent public signup (admin pattern)

```ruby
before_create_account_route do
  request.halt unless internal_request?
end
```

---

## Email configuration

Standard ActionMailer in `config/environments/production.rb`:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: "smtp.example.com",
  port: 587,
  user_name: ENV["SMTP_USER"],
  password: ENV["SMTP_PASSWORD"]
}
```

Override templates in `app/views/rodauth/<account>_mailer/`.

---

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

---

## Profile resource

Manages Rodauth account settings: view/edit personal fields plus links to Rodauth security features (change password, 2FA, etc.).

### Quick setup (with extra fields)

```bash
rails g pu:profile:setup date_of_birth:date bio:text \
  --dest=competition \
  --portal=competition_portal
```

### Step-by-step

```bash
rails generate pu:profile:install bio:text avatar:attachment 'timezone:string?' \
  --dest=customer

rails db:prepare

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

### What gets created

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

🚨 The association is **always `:profile`**, regardless of class — `current_user.profile`, `build_profile`, `params.require(:profile)` always work.

The generated definition injects a custom `ShowPage` that renders the `SecuritySection` component.

### The `SecuritySection` component

Dynamically lists Rodauth security links based on which features are enabled:

| Feature | Label |
|---|---|
| `change_password` | Change Password |
| `change_login` | Change Email |
| `otp` | Two-Factor Authentication |
| `recovery_codes` | Recovery Codes |
| `webauthn` | Security Keys |
| `active_sessions` | Active Sessions |
| `close_account` | Close Account |

To customize the show page (e.g. wrap, reorder), override `ShowPage#render_after_content` (see [[plutonium-ui]] › Page hooks).

### Required: every user gets a profile

```ruby
class User < ApplicationRecord
  after_create :create_profile!

  private
  def create_profile! = create_profile
end
```

Without this, `current_user.profile` is `nil` and the profile route errors. For existing users at migration time, run a one-off `User.find_each(&:create_profile)`.

### Linking to the profile

```ruby
link_to("Profile", profile_url) if respond_to?(:profile_url)
```

`profile_url` only exists when the profile resource is connected via `pu:profile:conn` (which registers it as a singular resource — see [[plutonium-app]] › Routes).

---

## Gotchas

- **Role index 0 is the most privileged.** For admin/SaaS roles, index 0 is `owner`/`super_admin`. Generated invite interactions default invitees to index 1.
- **`owner` is always prepended** by `pu:saas:setup --roles`. Don't include it manually.
- **Profile association is always `:profile`** — even when the class is `StaffUserProfile`.
- **`pu:saas:setup` runs four other generators** — don't re-run portal, profile, welcome, or invites separately.
- **Profile requires `pu:profile:conn`** — without it, no route, no `profile_url`, no menu link.
- **Users need a profile row.** Add an `after_create` callback (or `find_or_create_by`) — `current_user.profile` is otherwise nil.

---

## Related skills

- [[plutonium-app]] — initial install, portal wiring, mounting auth-constrained routes
- [[plutonium-tenancy]] — invites + memberships for multi-tenant onboarding
- [[plutonium-behavior]] — policies (auth runs first, policy checks the authenticated user)
- [[plutonium-resource]] — customizing the profile definition (fields, inputs, displays)
- [[plutonium-ui]] — overriding the profile's `ShowPage`, theming the security section
