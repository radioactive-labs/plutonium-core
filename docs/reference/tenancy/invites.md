# Invites

Token-based email invitations for multi-tenant onboarding. Integrates with Rodauth signup, creates entity memberships on acceptance, and supports "invitable" hooks for app-specific behavior.

## 🚨 Critical

- **Invite email must match the accepting user's email.** Security feature — don't disable `enforce_email?` lightly.
- **Entity scoping applies to invites** — invites are automatically filtered to the current entity (their model has `belongs_to :entity`).
- **Invitables must implement `on_invite_accepted`.** Without it, the invitable never learns about the new user.
- **A single app can have multiple invite flows** — run `pu:invites:install` once per flow with different `--entity-model` / `--user-model` / `--invite-model`.

## Prerequisites

Before installing invites, you need:

1. A Rodauth user model
2. An entity model (Organization, Company, Team, …)
3. A membership model linking users to entities

The fastest path is `pu:saas:setup` — it creates all three plus the SaaS portal, profile, welcome flow, and invites in one shot:

```bash
rails g pu:saas:setup --user Customer --entity Organization
```

## Install (standalone)

```bash
rails generate pu:invites:install
```

### Options

| Option | Default | Description |
|---|---|---|
| `--entity-model=NAME` | `Entity` | Entity model name |
| `--user-model=NAME` | `User` | User model name |
| `--invite-model=NAME` | `<EntityModel><UserModel>Invite` | Invite class name (omit for single-flow apps) |
| `--membership-model=NAME` | `EntityUser` | Membership join model (must already exist) |
| `--rodauth=NAME` | `user` | Rodauth configuration for signup |
| `--enforce-domain` | `false` | Require invited email domain to match entity domain |

::: info Roles come from the membership model
The role list is read from the membership model's `enum :role` — there is no `--roles=` flag on `pu:invites:install`. Set roles when generating the membership model (`pu:saas:membership --roles=...`) or edit its enum directly. **Index 0 is the most privileged** (typically `owner`, which the invite UI excludes from selectable choices); new invitees default to the second role.
:::

Example with custom models:

```bash
rails g pu:invites:install \
  --entity-model=Organization \
  --user-model=Customer \
  --membership-model=OrganizationMember
```

After install:

```bash
rails db:prepare
```

## What gets created

```
packages/invites/
├── app/
│   ├── controllers/invites/
│   │   ├── user_invitations_controller.rb
│   │   └── welcome_controller.rb
│   ├── definitions/invites/user_invite_definition.rb
│   ├── interactions/invites/
│   │   ├── cancel_invite_interaction.rb
│   │   └── resend_invite_interaction.rb
│   ├── mailers/invites/user_invite_mailer.rb
│   ├── models/invites/user_invite.rb
│   ├── policies/invites/user_invite_policy.rb
│   └── views/invites/...

app/interactions/{entity,user}/invite_user_interaction.rb
db/migrate/TIMESTAMP_create_user_invites.rb
```

Routes added:

```ruby
get  "welcome",                       to: "invites/welcome#index"
get  "invitations/:token",            to: "invites/user_invitations#show"
post "invitations/:token/accept",     to: "invites/user_invitations#accept"
get  "invitations/:token/signup",     to: "invites/user_invitations#signup"
post "invitations/:token/signup",     to: "invites/user_invitations#signup"
```

## Connect to a portal

```ruby
# packages/customer_portal/lib/engine.rb
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    register_package Invites::Engine
  end
end
```

Invites are entity-scoped automatically: `Invites::UserInvite belongs_to :entity` → `associated_with` resolves directly → admins only see invites for their org.

## The flow

### 1. Admin sends the invite

```ruby
# From entity context
entity.invite_user(email: "user@example.com", role: :member)

# From invitable context
tenant.invite_user(email: "user@example.com")
```

### 2. Email goes out

Token-based URL:

```
Subject: You've been invited to join Acme Corp

Click here: https://app.example.com/invitations/abc123...
```

### 3. User accepts

**Existing user:**

1. Clicks the invite link.
2. Logs in (or is already logged in).
3. System validates email matches.
4. Membership created; invitable notified via `on_invite_accepted`.

**New user:**

1. Clicks the invite link.
2. Clicks "Create Account".
3. Signs up with the invited email.
4. System validates email matches.
5. Membership created; invitable notified.

### 4. Pending invite check

After login, users land on `/welcome` where pending invites are shown:

```ruby
include Plutonium::Invites::PendingInviteCheck
```

Rodauth wiring (required for the redirect):

```ruby
# app/rodauth/user_rodauth_plugin.rb
configure do
  login_return_to_requested_location? true
  login_redirect "/welcome"

  after_login do
    session[:after_welcome_redirect] = session.delete(:login_redirect)
  end
end
```

## Invitables — app models notified on accept

An "invitable" is an app model that triggers invitations and gets notified when one is accepted. Examples: `Tenant`, `TeamMember`, `ProjectCollaborator`.

```bash
rails g pu:invites:invitable Tenant
rails g pu:invites:invitable TeamMember --role=member
rails g pu:invites:invitable Tenant --dest=my_package
```

| Option | Default | Description |
|---|---|---|
| `--role=ROLE` | `member` | Role to assign on acceptance |
| `--user-model=NAME` | `User` | User model |
| `--membership-model=NAME` | `EntityUser` | Membership join model |
| `--dest=PACKAGE` | `main_app` | Destination package |
| `--[no-]email-templates` | `true` | Generate custom email templates |

Implement the callback on the invitable:

```ruby
class Tenant < ApplicationRecord
  include Plutonium::Invites::Concerns::Invitable

  belongs_to :entity
  belongs_to :user, optional: true

  def on_invite_accepted(user)
    update!(user: user, status: :active)
  end
end
```

::: warning Without `on_invite_accepted`
The invitable never learns about the new user — the invite is consumed but your app doesn't update its state.
:::

## Multiple invite flows

A single app can have several independent invite flows side-by-side (e.g. one for inviting customers to organizations, another for inviting funders to projects). Run `pu:invites:install` once per flow.

**Default name derivation:** when `--invite-model` is omitted, the class is `<EntityModel><UserModel>Invite`. So with the defaults (`--entity-model=Organization --user-model=User`) the generated class is `Invites::OrganizationUserInvite` — there is no literal `UserInvite` default. Single-flow apps don't need `--invite-model`.

```bash
rails g pu:invites:install \
  --entity-model=FunderOrganization \
  --user-model=SpenderAccount \
  --invite-model=FunderInvite

rails g pu:invites:install \
  --entity-model=Project \
  --user-model=Member \
  --invite-model=ProjectInvite
```

Each invocation creates an independent flow: model `Invites::FunderInvite` on `funder_invites`, controller `Invites::FunderInvitationsController` on `/funder_invitations/:token`, helper `funder_invitation_path`, etc.

The shared `Invites::WelcomeController` accumulates each new class into its `invite_classes` array, so `pending_invite` checks all flows in priority order (first-match wins).

### Model-level overrides for non-default associations

```ruby
def user_attribute         = :spender_account     # belongs_to :spender_account instead of :user
def invite_entity_attribute = :funder_organization # belongs_to :funder_organization instead of :entity
```

### Controller-level overrides (auto-generated)

```ruby
# packages/invites/app/controllers/invites/welcome_controller.rb
def invite_classes
  [::Invites::FunderInvite, ::Invites::ProjectInvite]
end

# packages/invites/app/controllers/invites/funder_invitations_controller.rb
def invitation_path_for(token)
  funder_invitation_path(token: token)
end
```

## The UserInvite model

Generated as `Invites::<InviteModelName>`:

```ruby
class Invites::UserInvite < Invites::ResourceRecord
  include Plutonium::Invites::Concerns::InviteToken

  belongs_to :entity
  belongs_to :invited_by, polymorphic: true
  belongs_to :user, optional: true
  belongs_to :invitable, polymorphic: true, optional: true

  enum :state, pending: 0, accepted: 1, expired: 2, cancelled: 3
  enum :role, member: 0, admin: 1
end
```

Key methods:

```ruby
invite = Invites::UserInvite.find_for_acceptance(token)
invite.accept_for_user!(current_user)
invite.resend!
invite.cancel!
```

## Customization

### Custom email templates

Override views in your package:

```erb
<%# packages/invites/app/views/invites/user_invite_mailer/invitation.html.erb %>
<h1>Welcome to <%= @invite.entity.name %>!</h1>
<p><%= @invite.invited_by.email %> has invited you.</p>
<p><%= link_to "Accept", @invitation_url %></p>
```

### Per-invitable templates

When you generate an invitable with `--email-templates`, you get per-invitable mailer views — useful for differentiating "Join as a team member" from "Join as a project collaborator".

### Custom validation

Extend the invite model:

```ruby
class Invites::UserInvite < Invites::ResourceRecord
  validate :email_not_already_member

  private

  def email_not_already_member
    existing = membership_model.joins(:user)
      .where(entity: entity, users: {email: email})
      .exists?
    errors.add(:email, "is already a member") if existing
  end
end
```

### Domain enforcement

```bash
rails g pu:invites:install --enforce-domain
```

Requires the invited email's domain to match the entity's domain.

### Custom roles

Roles are defined on the membership model, not on the invites generator. Set them at membership generation time (ordering matters — **index 0 is the most privileged**, typically `owner`):

```bash
rails g pu:saas:membership --user Customer --entity Organization --roles=admin,editor,viewer
# → enum :role, { owner: 0, admin: 1, editor: 2, viewer: 3 }  (owner is auto-prepended)
```

Or edit `enum :role` on the existing membership model directly. Then run `pu:invites:install`.

### Custom expiration

Override on the model:

```ruby
class Invites::UserInvite < Invites::ResourceRecord
  TOKEN_EXPIRATION = 30.days   # default is 1 week

  def expired?
    created_at < TOKEN_EXPIRATION.ago
  end
end
```

## Managing invitations

### Resend

```ruby
invite.resend!   # generates new token + sends email
```

### Cancel

```ruby
invite.cancel!   # transitions to :cancelled state
```

### View pending

```ruby
entity.user_invites.pending
```

## Security

### Token security

Tokens use `SecureRandom.urlsafe_base64(32)` — 256 bits, URL-safe. Stored hashed in the DB; raw token shown only at creation (in the email).

### Email validation

`enforce_email?` is `true` by default. The accepting user's email must match the invited email — prevents account hijacking via invite forwarding.

To allow any email (NOT recommended):

```ruby
def enforce_email? = false
```

### Rate limiting

Use Rack::Attack or similar to throttle:

- Invite creation per admin
- Invitation acceptance attempts per IP

## Common issues

- **"Invitation not found or expired"** — token expired (default 1 week), invite cancelled, or no longer in `pending` state.
- **Email mismatch error** — the accepting user's email doesn't match the invited email. `enforce_email?` is enforcing the match (this is intentional security).
- **Rodauth redirect after login doesn't go to `/welcome`** — check the `login_redirect "/welcome"` line in the rodauth plugin's `configure` block.
- **`on_invite_accepted` not called** — ensure the invitable model `include Plutonium::Invites::Concerns::Invitable` and defines `on_invite_accepted`.

## Related

- [Entity scoping](./entity-scoping) — how invites are filtered to the current entity
- [Auth](/reference/auth/) — Rodauth account configuration
- [Behavior › Interactions](/reference/behavior/interactions) — `cancel_invite_interaction`, `resend_invite_interaction`
- [Guides › User invites](/guides/user-invites) — task-oriented walkthrough
