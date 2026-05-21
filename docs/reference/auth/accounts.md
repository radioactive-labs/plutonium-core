# Accounts

Rodauth account types. Pick one (or several — apps can have multiple side-by-side).

## Basic account — `pu:rodauth:account`

```bash
rails generate pu:rodauth:account user [options]
```

### Options

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
| `--verify_account_grace_period` | ✓ | Grace period before verification is required |
| `--reset_password`, `--reset_password_notify` | ✓ | Password reset via email + notification |
| `--change_password`, `--change_password_notify` | ✓ | Password change + notification |
| `--change_login`, `--verify_login_change` | ✓ | Email change with verification |
| `--case_insensitive_login` | ✓ | Case-insensitive email matching |
| `--internal_request` | ✓ | Internal request support |
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
| `--password_expiration` | | Force periodic password changes |
| `--disallow_password_reuse` | | Prevent reusing recent passwords |

### Examples

```bash
# Basic account
rails g pu:rodauth:account user

# With 2FA
rails g pu:rodauth:account user --otp --recovery_codes

# API only
rails g pu:rodauth:account api_user --api_only --jwt --jwt_refresh

# Kitchen sink
rails g pu:rodauth:account user --kitchen_sink
```

## Admin account — `pu:rodauth:admin`

Pre-configured secure admin with multi-phase login, **required** TOTP, recovery codes, lockout, active session tracking, audit logging, role-based access, invite interaction, and **no public signup**.

```bash
rails g pu:rodauth:admin admin
rails g pu:rodauth:admin admin --roles=super_admin,admin,viewer
rails g pu:rodauth:admin admin --extra-attributes=name:string,department:string
```

| Option | Default | Description |
|---|---|---|
| `--roles` | `super_admin,admin` | Comma-separated roles (positional enum) |
| `--extra_attributes` | | Additional model attributes (e.g. `name:string`) |

**Role-ordering convention:** index 0 is the most privileged. Generated invite interaction defaults new invitees to `roles[1]` — the order in `--roles=` matters.

```ruby
enum :role, super_admin: 0, admin: 1
```

Rake task for direct admin creation (generated alongside the account — namespace is `rodauth`, task name is the account name):

```bash
EMAIL=admin@example.com rails rodauth:admin
# (run without EMAIL to be prompted)
```

The task creates the account and triggers a verification email; the admin sets their own password via that flow. No password is passed on the command line.

## SaaS setup — `pu:saas:setup` (meta-generator)

Creates the User + Entity + Membership trio AND runs:

- `pu:saas:portal` → a full `{Entity}Portal` scoped to the entity
- `pu:profile:setup` → profile model + association (see [Profile](./profile))
- `pu:saas:welcome` → onboarding / select-entity flow
- `pu:invites:install` → the invites package (see [Tenancy › Invites](/reference/tenancy/invites))

::: warning Don't re-run pieces manually
After `pu:saas:setup` runs, don't separately run `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, or `pu:invites:install`. Pass `--force` to re-run the whole meta-generator.
:::

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
| `--api_client=NAME` | | Also generate an API client |
| `--api_client_roles` | `read_only,write,admin` | API client roles |

Individual SaaS generators (rarely needed): `pu:saas:user`, `pu:saas:entity`, `pu:saas:membership`, `pu:saas:portal`, `pu:saas:welcome`.

Generated user + membership models:

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

## API client — `pu:saas:api_client`

For machine-to-machine authentication. HTTP Basic Auth with auto-generated password.

```bash
rails g pu:saas:api_client ApiClient
rails g pu:saas:api_client ApiClient --entity=Organization
rails g pu:saas:api_client ApiClient --entity=Organization --roles=read_only,write,admin
```

| Option | Default | Description |
|---|---|---|
| `--entity=NAME` | | Entity to scope API clients to |
| `--roles` | `read_only,write,admin` | Available roles |
| `--extra_attributes` | | Additional model attributes |
| `--dest` | `main_app` | Destination package |

CLI creation:

```bash
rake api_clients:create LOGIN=my-service
rake api_clients:create LOGIN=my-service ORGANIZATION=acme ROLE=write
```

::: warning Credentials shown once
The auto-generated password (`SecureRandom.base64(32)`) is displayed once at creation and cannot be retrieved later.
:::

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

## Related

- [Profile](./profile) — profile resource + SecuritySection component
- [App › Portals › Controller concern (auth)](/reference/app/portals#controller-concern-auth) — wiring accounts into portal controllers
- [Tenancy › Invites](/reference/tenancy/invites) — invitation system on top of Rodauth signup
- [App › Generators › Authentication generators](/reference/app/generators#authentication-generators) — full generator catalog
