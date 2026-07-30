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
rails db:prepare

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

⚠️ This is a **meta-generator** — it also runs `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, and `pu:invites:install`. Don't re-run those manually. See [Reference › Auth › Accounts › SaaS setup](/reference/auth/accounts#saas-setup).

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

## Multiple portals in one browser

A person can hold a session in several portals at once — signed into the admin portal and the customer portal in the same browser, with neither evicting the other. Two settings make that work, and the generators emit both:

```ruby
# app/rodauth/rodauth_plugin.rb — the shared base
configure do
  enable :session_isolation
end
```

```ruby
# app/rodauth/admin_rodauth_plugin.rb — once per account type
configure do
  session_key_prefix "admin_"
  remember_cookie_key "_admin_remember"
end
```

Both are required. `session_key_prefix` namespaces *every* session key a configuration touches — the account id plus `authenticated_by`, `login_redirect`, `two_factor_auth_setup` and the rest. `session_isolation` uses that prefix to decide which entries belong to whom, and stops one configuration's login from clearing another's.

::: danger Do not also set `session_key`
An explicit `session_key` is **not** prefixed (`convert_session_key`, `rodauth/features/base.rb:686` — only the default value passes through it). Setting both leaves the account id on a different name from every other key, so they stop rotating together. A session that holds an account id but no `authenticated_by` makes Rodauth raise on *every request* — `logged_in_via_remember_key?` calls `nil.include?` (`remember.rb:175`).

A config without a prefix at all is also not isolated: its keys are Rodauth's unprefixed defaults, indistinguishable from any other unprefixed config's, so `session_isolation` carries nothing for it.
:::

::: details Why this is needed
Rodauth resets the session on every login — including the `remember` feature's `load_memory` autologin — to defend against session fixation, and rodauth-rails implements that reset as a full `reset_session`.

Without `session_isolation`, signing into one portal wipes every other portal's session. And because `RodauthApp#route` calls `load_memory` for *every* configuration on *every* request, the evicted configuration immediately autologins from its remember cookie and evicts the new one right back. The last `load_memory` call in the route block wins permanently, so the other portal can never hold a session at all.

`session_isolation` carries only the *other configurations'* session entries across the reset. The session id is still rotated and application session data is still cleared, so session fixation is still defeated.
:::

Reading a raw Rodauth session key? Go through its accessor, never the literal — with a prefix set, the literal is the wrong key:

```ruby
after_login do
  session[:after_welcome_redirect] = session.delete(login_redirect_session_key) # ✅
  session[:after_welcome_redirect] = session.delete(:login_redirect)            # ❌ wrong key
end
```

**Upgrading an app generated before this existed:** add `enable :session_isolation` once in the base plugin and `session_key_prefix` in each account plugin — and **delete the existing `session_key "_x_session"` line** while you're there, for the reason above.

Every key name changes together, so old session cookies stop matching and are ignored — the safe outcome. Keeping the old `session_key` to "preserve" logins is what produces the half-migrated session that crashes.

In practice only *unremembered* sessions drop: `remember_cookie_key` is a cookie name and isn't touched by the prefix, so anyone holding a valid `_x_remember` cookie is restored by `load_memory` on their next request, which writes the new prefixed keys. Expect logouts for users who never ticked "Remember Me", not a full sign-out.

## "Remember me" is opt-in

The login form renders a "Remember Me" checkbox whenever the config enables the `remember` feature, and the config only issues the 14-day cookie when it's ticked:

```ruby
after_login { remember_login if param_or_nil(remember_param) == remember_remember_param_value }
```

To go back to remembering everyone whether they asked or not, swap in the unconditional form:

```ruby
after_login { remember_login }
```

::: warning Compare the value, don't just check presence
`param_or_nil(remember_param)` on its own is a truthiness check, and `remember_param` is shared with Rodauth's `/remember` settings page — which submits `forget` and `disable` as well as `remember`. A bare presence check means `remember=disable` would remember you. Compare against `remember_remember_param_value`, as above.

Plutonium's login form also passes `include_hidden: false` to `check_box`, so an unticked box sends nothing at all rather than Rails' default `"0"`. With the value comparison that's belt-and-braces rather than load-bearing (`"0" == "remember"` is already false) — but it keeps a junk param off the wire and keeps the form correct for anyone who reverts the hook to a bare truthiness check.
:::

Logged-in users can change the setting later on Rodauth's `/remember` page (Remember / Forget / Disable).

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
- **Signing into one portal signs you out of another** — or one portal can never stay signed in at all. Missing `enable :session_isolation` and/or `session_key_prefix`; see [Multiple portals in one browser](#multiple-portals-in-one-browser).

## Related

- [Reference › Auth](/reference/auth/) — full auth surface
- [Authorization](./authorization) — controlling who can do what AFTER login
- [Multi-tenancy](./multi-tenancy) — entity scoping for SaaS apps
- [User invites](./user-invites) — invitation-based onboarding
- [User profile](./user-profile) — account-settings page
