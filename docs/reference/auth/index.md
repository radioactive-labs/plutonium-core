# Auth Reference

Plutonium uses [Rodauth](http://rodauth.jeremyevans.net/) via [rodauth-rails](https://github.com/janko/rodauth-rails). This area covers Rodauth installation, account types, and the user profile resource.

## Sub-pages

- [Accounts](./accounts) — Rodauth install, basic accounts, admin accounts, SaaS setup, account customization
- [Profile](./profile) — profile resource generator, the SecuritySection component

## 🚨 Critical

- **Use the generators.** `pu:rodauth:install`, `pu:rodauth:account`, `pu:rodauth:admin`, `pu:saas:setup`, `pu:profile:install`, `pu:profile:conn`. Never hand-write Rodauth plugin files, account models, or profile resources.
- **Role index 0 is the most privileged** (`owner`, `super_admin`). Invite interactions default new invitees to **index 1** — the order in `--roles=` matters.
- **`pu:saas:setup --roles=...` always prepends `owner` as index 0.** Don't include `owner` in the option.
- **`pu:saas:setup` is a meta-generator.** It also runs `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, and `pu:invites:install`. Don't re-run those manually.
- **Profile association is always `:profile`** regardless of the model class — `current_user.profile`, `build_profile`, `params.require(:profile)`.
- **Profile needs `pu:profile:conn` to be visible** — without it, the singular `/profile` route and `profile_url` helper don't exist.
- **Every user needs a profile row.** Add an `after_create` callback or `find_or_create_by` — otherwise `current_user.profile` is nil.

## Install Rodauth

```bash
rails generate pu:rodauth:install
```

Installs gems (`rodauth-rails`, `bcrypt`, `sequel-activerecord_connection`), the Roda app at `app/rodauth/rodauth_app.rb`, base plugin and controller, initializer, layout, and a PostgreSQL extension migration if applicable.

## Wire auth into controllers

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

For portal wiring (`AdminPortal::Concerns::Controller`), see [App › Portals](/reference/app/portals#controller-concern-auth).

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

## Related

- [Accounts](./accounts) — account types and feature flags
- [Profile](./profile) — profile resource + SecuritySection
- [Tenancy › Invites](/reference/tenancy/invites) — invitation system on top of Rodauth signup
- [App › Portals › Controller concern (auth)](/reference/app/portals#controller-concern-auth) — portal-side wiring
- [Guides › Authentication](/guides/authentication) — task-oriented walkthrough
- [Guides › User profile](/guides/user-profile)
