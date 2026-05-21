# Authentication

Add Rodauth-based authentication to your Plutonium app.

## Goal

Authenticated users can sign up, log in, change passwords, and reset forgotten passwords. Pages in protected portals are gated.

## Quick path — basic user auth

```bash
# 1. Install Rodauth
rails generate pu:rodauth:install

# 2. Create a user account type
rails generate pu:rodauth:account user

# 3. Run migrations
rails db:migrate

# 4. Wire auth into a portal
#    (when you run `pu:pkg:portal admin --auth=user`, this happens automatically)
```

If you generated the portal with `--auth=user`, the engine is already mounted with the `Rodauth::Rails.authenticate(:user)` constraint — open `packages/admin_portal/config/routes.rb` to see it. The wiring looks like:

```ruby
# packages/admin_portal/config/routes.rb (generated)
Rails.application.routes.draw do
  constraints Rodauth::Rails.authenticate(:user) do
    mount AdminPortal::Engine, at: "/admin"
  end
end
```

If you generated the portal as `--public` and need to switch it to authenticated later, re-run with `--auth=user --force` (or edit the constraint into the routes file by hand).

For accounts with more features, options, and admin patterns: see [Reference › Auth › Accounts](/reference/auth/accounts).

## Common variations

### Multi-factor auth (TOTP)

```bash
rails generate pu:rodauth:account user --otp --recovery_codes
```

Then enable in the user-facing security section (see [User profile](./user-profile)).

### Hardened admin account

For an admin role with 2FA, lockout, audit logging, and no public signup, use the dedicated `pu:rodauth:admin` generator (a preset of `pu:rodauth:account` with hardened defaults):

```bash
rails generate pu:rodauth:admin admin
```

Create the first admin with the rake task generated alongside the account:

```bash
EMAIL=admin@example.com rails rodauth:admin
# (run without EMAIL to prompt)
```

The task creates the account and triggers a verification email; the admin sets their own password through that flow. No password is passed on the command line.

### Multi-tenant SaaS — user + entity + membership in one shot

```bash
rails generate pu:saas:setup --user Customer --entity Organization
```

⚠️ This is a **meta-generator** — it also runs `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, and `pu:invites:install`. Don't re-run those manually. See [Reference › Auth › Accounts › SaaS setup](/reference/auth/accounts#saas-setup-pu-saas-setup).

### API-only (JWT)

```bash
rails generate pu:rodauth:account api_user --api_only --jwt --jwt_refresh
```

```
POST /api_users/login
{"login": "user@example.com", "password": "secret"}
# → {"access_token": "...", "refresh_token": "..."}
```

## Connecting a portal to an account type

If you create the portal with `--auth=`, it's wired automatically:

```bash
rails generate pu:pkg:portal customer --auth=user
```

Manually, edit the portal's controller concern:

```ruby
# packages/customer_portal/app/controllers/customer_portal/concerns/controller.rb
module CustomerPortal::Concerns::Controller
  extend ActiveSupport::Concern
  include Plutonium::Portal::Controller
  include Plutonium::Auth::Rodauth(:user)
end
```

Multiple account types — different portals use different Rodauth instances:

```ruby
# Admin portal
include Plutonium::Auth::Rodauth(:admin)

# Customer portal
include Plutonium::Auth::Rodauth(:user)
```

See [Reference › App › Portals](/reference/app/portals#controller-concern-auth).

## Customizing the auth flow

All inside `app/rodauth/<name>_rodauth_plugin.rb`, in the `configure do` block:

### Custom login redirect

```ruby
login_redirect do
  rails_account.admin? ? "/admin" : "/dashboard"
end
```

### After-create hook (e.g. create a profile)

```ruby
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

### Prevent public signup

```ruby
before_create_account_route do
  request.halt unless internal_request?
end
```

Full customization surface: [Reference › Auth › Accounts › Common customizations](/reference/auth/accounts#common-customizations).

## Email setup (production)

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

Override mailer templates in `app/views/rodauth/<account>_mailer/`.

## Accessing the current user

```ruby
# Controllers / views
current_user

# Policies
user
```

## Common issues

- **"You need to set up Rodauth"** — run `pu:rodauth:install` first.
- **Portal redirects to login even though you're authenticated** — the portal mount constraint references a different Rodauth account than the portal's controller concern uses. Match them up.
- **Email confirmation never arrives in development** — Plutonium sets ActionMailer to `:test` by default. Check `tmp/letter_opener/` or your mail interceptor. In production, configure SMTP (see above).

## Related

- [Reference › Auth](/reference/auth/) — full auth surface
- [Authorization](./authorization) — controlling who can do what AFTER login
- [Multi-tenancy](./multi-tenancy) — entity scoping for SaaS apps
- [User invites](./user-invites) — invitation-based onboarding
- [User profile](./user-profile) — account-settings page
