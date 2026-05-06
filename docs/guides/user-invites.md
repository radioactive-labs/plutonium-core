# User Invites

Plutonium provides a complete user invitation system for multi-tenant applications. This guide covers setting up invitations, customizing the flow, and integrating with your portals.

## Overview

The invitation system handles:
- **Email Invitations**: Send secure invitation links to new or existing users
- **Token Validation**: Time-limited tokens with automatic expiration
- **Rodauth Integration**: Seamless signup and login flows
- **Entity Memberships**: Automatic membership creation on acceptance
- **Invitable Models**: Notify models when their invitations are accepted

## Prerequisites

Before installing invites, ensure you have:

1. **User Authentication**: A Rodauth user account
2. **Entity Model**: An organization/company/team model
3. **Membership Model**: A join model linking users to entities

The easiest way to set this up is with the SaaS generator:
```bash
rails g pu:saas:setup --user User --entity Organization
```

## Installation

### Step 1: Install the Invites Package

```bash
rails generate pu:invites:install
```

With custom models:

```bash
rails g pu:invites:install \
  --entity-model=Organization \
  --user-model=User \
  --membership-model=OrganizationUser \
  --roles=member,manager,admin
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--entity-model` | Entity | Entity model for scoping invites |
| `--user-model` | User | User account model |
| `--invite-model` | `<EntityModel><UserModel>Invite` | Invite class name. Omit for single-flow apps; set per-invocation to run the generator more than once for distinct flows. |
| `--membership-model` | EntityUser | Join model for memberships |
| `--roles` | member,admin | Available invitation roles |
| `--rodauth` | user | Rodauth configuration name |
| `--enforce-domain` | false | Require email domain matching |

### Step 2: Run Migrations

```bash
rails db:migrate
```

### Step 3: Configure Your Portal

Register the invites package in your portal:

```ruby
# packages/customer_portal/lib/engine.rb
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    register_package Invites::Engine
  end
end
```

## Generated Files

The generator creates a complete `packages/invites/` package:

```
packages/invites/
├── app/
│   ├── controllers/invites/
│   │   ├── user_invitations_controller.rb  # Invitation acceptance
│   │   └── welcome_controller.rb           # Post-login landing
│   ├── definitions/invites/
│   │   └── user_invite_definition.rb       # UI configuration
│   ├── interactions/invites/
│   │   ├── cancel_invite_interaction.rb    # Cancel action
│   │   └── resend_invite_interaction.rb    # Resend action
│   ├── mailers/invites/
│   │   └── user_invite_mailer.rb           # Invitation emails
│   ├── models/invites/
│   │   └── user_invite.rb                  # Invite model
│   ├── policies/invites/
│   │   └── user_invite_policy.rb           # Authorization
│   └── views/invites/
│       ├── user_invitations/               # Acceptance views
│       ├── user_invite_mailer/             # Email templates
│       └── welcome/                        # Welcome page
└── lib/
    └── engine.rb                           # Package engine
```

## Invitation Flow

### Sending Invitations

Admins can invite users from the entity detail page or user management:

```ruby
# The generated action in your entity definition
action :invite_user,
  interaction: Organization::InviteUserInteraction,
  category: :secondary
```

The interaction creates an `Invites::UserInvite` record and sends an email:

```ruby
# Generated interaction
class Organization::InviteUserInteraction < Plutonium::Interaction::Base
  attribute :email, :string
  attribute :role, :string, default: "member"

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  def execute
    invite = Invites::UserInvite.create!(
      entity: resource,
      email: email,
      role: role,
      invited_by: current_user
    )

    succeed(invite)
      .with_message("Invitation sent to #{email}")
  end
end
```

### Accepting Invitations

#### Existing Users

1. User receives email with invitation link
2. Clicks link, sees invitation details
3. If logged in with matching email, accepts directly
4. If not logged in, redirected to login
5. After login, redirected back to accept

#### New Users

1. User receives email with invitation link
2. Clicks link, sees invitation details
3. Clicks "Create Account"
4. Signs up with the invited email address
5. After signup, automatically accepts invitation

### Post-Login Welcome

After login, users land on `/welcome` where pending invitations are displayed:

```ruby
# The WelcomeController checks for pending invites
class Invites::WelcomeController < ApplicationController
  def index
    @pending_invites = Invites::UserInvite
      .pending
      .where(email: current_user.email)

    if @pending_invites.any?
      render :pending_invitation
    else
      redirect_to session.delete(:after_welcome_redirect) || root_path
    end
  end
end
```

## Invitables

Invitables are models that trigger invitations and receive callbacks when accepted. Use this when you need to:
- Create a record that requires a user to be assigned
- Notify specific models when their invitation is accepted
- Customize invitation behavior per model type

### Creating an Invitable

```bash
rails g pu:invites:invitable Tenant
rails g pu:invites:invitable TeamMember --role=member
```

### Implementing the Callback

```ruby
# app/models/tenant.rb
class Tenant < ApplicationRecord
  include Plutonium::Invites::Concerns::Invitable

  belongs_to :organization
  belongs_to :user, optional: true

  # Called when the invitation is accepted
  def on_invite_accepted(user)
    update!(
      user: user,
      status: :active,
      activated_at: Time.current
    )
  end
end
```

### How Invitables Work

When creating an invite from an invitable:

```ruby
# The invitable triggers the invitation
tenant.invite_user(email: "user@example.com")

# Creates UserInvite with:
# - invitable_type: "Tenant"
# - invitable_id: tenant.id
```

When the invite is accepted:

```ruby
# System calls:
invite.accept_for_user!(user)

# Which internally:
# 1. Creates entity membership
# 2. Calls tenant.on_invite_accepted(user)
```

## Customization

### Custom Email Templates

Override the default templates:

```erb
<%# packages/invites/app/views/invites/user_invite_mailer/invitation.html.erb %>
<!DOCTYPE html>
<html>
<body>
  <h1>Welcome to <%= @invite.entity.name %>!</h1>

  <p>
    <%= @invite.invited_by.email %> has invited you to join
    as a <%= @invite.role %>.
  </p>

  <p>
    <%= link_to "Accept Invitation", @invitation_url,
        style: "background: #4F46E5; color: white; padding: 12px 24px;" %>
  </p>

  <p>This invitation expires in 7 days.</p>
</body>
</html>
```

### Per-Invitable Templates

Create model-specific email templates:

```erb
<%# packages/invites/app/views/invites/user_invite_mailer/invitation_tenant.html.erb %>
<h1>You've been assigned as a tenant!</h1>
<p>Accept to access your tenant dashboard.</p>
```

### Custom Validation

Add validation to the invite model:

```ruby
# packages/invites/app/models/invites/user_invite.rb
class Invites::UserInvite < Invites::ResourceRecord
  validate :email_not_already_member
  validate :within_invite_limit

  private

  def email_not_already_member
    if entity.users.exists?(email: email)
      errors.add(:email, "is already a member of this organization")
    end
  end

  def within_invite_limit
    pending_count = entity.user_invites.pending.count
    if pending_count >= 100
      errors.add(:base, "Maximum pending invitations reached")
    end
  end
end
```

### Domain Enforcement

Require invited emails to match the entity's domain:

```bash
rails g pu:invites:install --enforce-domain
```

Or implement custom domain logic:

```ruby
# packages/invites/app/models/invites/user_invite.rb
def enforce_domain
  entity.domain  # e.g., "acme.com"
end
```

### Custom Expiration

Change the default expiration time:

```ruby
# packages/invites/app/models/invites/user_invite.rb
private

def set_token_defaults
  self.token ||= SecureRandom.urlsafe_base64(32)
  self.expires_at ||= 3.days.from_now  # Override default 1 week
end
```

## Managing Invitations

### Resend Invitation

The generated `ResendInviteInteraction` allows resending:

```ruby
# Resets expiration and sends new email
invite.resend!
```

### Cancel Invitation

```ruby
invite.cancel!
# Sets state to :cancelled
```

### View Pending Invitations

In your admin portal:

```ruby
# Invites are scoped to the current entity
# Admins see all pending invites for their organization
Invites::UserInvite.pending.where(entity: current_scoped_entity)
```

## Security Considerations

### Token Security

- Tokens are 32-byte URL-safe base64 strings
- Tokens expire after 1 week by default
- Each invite has a unique token

### Email Validation

By default, the accepting user's email must match the invited email:

```ruby
def enforce_email?
  true  # Default: require exact match
end
```

### Rate Limiting

Consider adding rate limiting to prevent abuse:

```ruby
# In your interaction
validate :rate_limit_invites

def rate_limit_invites
  recent = Invites::UserInvite
    .where(invited_by: current_user)
    .where("created_at > ?", 1.hour.ago)
    .count

  if recent >= 50
    errors.add(:base, "Too many invitations sent. Please wait.")
  end
end
```

## Troubleshooting

### "Invitation not found or expired"

- Check that the token hasn't expired (default: 1 week)
- Verify the invite is still `pending` (not cancelled or accepted)
- Ensure the URL is complete and not truncated

### "Email mismatch" Error

The system requires the accepting user's email to match:

```
This invitation is for user@example.com.
You must use an account with that email address.
```

If you need to allow any email:

```ruby
def enforce_email?
  false  # Not recommended for security
end
```

### Rodauth Not Redirecting Properly

Ensure your Rodauth plugin is configured:

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

### Invitable Callback Not Called

Ensure your model includes the concern and implements the callback:

```ruby
class Tenant < ApplicationRecord
  include Plutonium::Invites::Concerns::Invitable

  def on_invite_accepted(user)
    # This MUST be implemented
    update!(user: user)
  end
end
```

## API Reference

### UserInvite States

| State | Description |
|-------|-------------|
| `pending` | Awaiting acceptance |
| `accepted` | Successfully accepted |
| `expired` | Past expiration date |
| `cancelled` | Manually cancelled |

### Key Methods

```ruby
# Find valid invite
invite = Invites::UserInvite.find_for_acceptance(token)

# Accept invitation
invite.accept_for_user!(user)

# Resend email
invite.resend!

# Cancel
invite.cancel!

# Check state
invite.pending?
invite.accepted?
invite.expired?
invite.cancelled?
```

## Multiple invite flows in one app

Some apps invite users to several distinct kinds of entity — for example, customers joining organizations and funders joining projects. Run `pu:invites:install` once per flow; each invocation produces independent migrations, models, policies, definitions, mailers, controllers, view templates, and route helpers.

### Default-derivation rule

When you omit `--invite-model`, the generator derives the class name as `<EntityModel><UserModel>Invite`. With the defaults (`--entity-model=Organization --user-model=User`) the generated class is `Invites::OrganizationUserInvite` — there is no literal `UserInvite` default. Single-flow apps never need to pass `--invite-model`.

Multi-flow apps either:

- Run the generator more than once with the **same** entity/user but different `--invite-model` values (rare), or
- Run with **different** `--entity-model` / `--user-model` pairs (common). Different derivations make `--invite-model` unnecessary; pass it only when you want a custom class name.

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

After the second invocation you'll have, for example, `Invites::FunderInvite` on table `funder_invites` with controller `Invites::FunderInvitationsController` mounted at `/funder_invitations/:token`, alongside `Invites::ProjectInvite` on `project_invites` mounted at `/project_invitations/:token`. Route helpers are prefixed (`funder_invitation_path`, `project_invitation_path`).

### How the welcome flow finds pending invites

The shared `Invites::WelcomeController` keeps a running list of invite classes. Each install run injects its class into the array, preserving order:

```ruby
# packages/invites/app/controllers/invites/welcome_controller.rb
def invite_classes
  [::Invites::FunderInvite, ::Invites::ProjectInvite]
end
```

After login, `Plutonium::Invites::PendingInviteCheck#pending_invite` iterates `invite_classes` and returns the first valid pending invite for the cookie-stored token (first-match wins). Plug a third-party invite class in by overriding `invite_classes` directly:

```ruby
class WelcomeController < ApplicationController
  include Plutonium::Invites::PendingInviteCheck

  def invite_classes
    [::Invites::FunderInvite, ::Invites::ProjectInvite, ::Foreign::ApiInvite]
  end
end
```

### Per-flow controller overrides

The install generator emits an `invitation_path_for` override on each invitations controller so post-login redirects target the correct prefixed route:

```ruby
# packages/invites/app/controllers/invites/funder_invitations_controller.rb
def invitation_path_for(token)
  funder_invitation_path(token: token)
end
```

You won't normally edit this — but it's worth knowing the hook exists, because that's how multi-flow controllers stay independent from the shared `Plutonium::Invites::Controller` concern.

## Next Steps

- [Authentication](/guides/authentication) - Set up Rodauth
- [Authorization](/guides/authorization) - Configure policies
- [Custom Actions](/guides/custom-actions) - Add more invite actions
- [Multi-tenancy](/guides/multi-tenancy) - Entity scoping
