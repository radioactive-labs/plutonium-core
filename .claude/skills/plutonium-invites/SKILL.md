---
name: plutonium-invites
description: Plutonium user invites - invitation system for multi-tenant apps with entity memberships
---

# Plutonium User Invites

Plutonium provides a complete user invitation system for multi-tenant applications. The system handles:
- Sending email invitations to new users
- Token-based invite acceptance flow
- Integration with Rodauth authentication
- Entity membership creation on acceptance
- Support for invitable models that get notified when invites are accepted

## Installation

### Prerequisites

Before installing invites, ensure you have:
1. A user model with Rodauth authentication
2. An entity model (Organization, Company, Team, etc.)
3. A membership model linking users to entities

Use `pu:saas:setup` to generate all three:

```bash
rails g pu:saas:setup --user Customer --entity Organization
```

### Install the Invites Package

```bash
rails generate pu:invites:install
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--entity-model=NAME` | Entity | Entity model name for scoping |
| `--user-model=NAME` | User | User model name |
| `--membership-model=NAME` | EntityUser | Membership join model |
| `--roles=ROLES` | member,admin | Comma-separated roles |
| `--rodauth=NAME` | user | Rodauth configuration for signup |
| `--enforce-domain` | false | Require email domain to match entity |

**Example with custom models:**

```bash
rails g pu:invites:install \
  --entity-model=Organization \
  --user-model=Customer \
  --membership-model=OrganizationMember \
  --roles=member,manager,admin
```

### What Gets Created

```
packages/invites/
├── app/
│   ├── controllers/invites/
│   │   ├── user_invitations_controller.rb
│   │   └── welcome_controller.rb
│   ├── definitions/invites/
│   │   └── user_invite_definition.rb
│   ├── interactions/invites/
│   │   ├── cancel_invite_interaction.rb
│   │   └── resend_invite_interaction.rb
│   ├── mailers/invites/
│   │   └── user_invite_mailer.rb
│   ├── models/invites/
│   │   └── user_invite.rb
│   ├── policies/invites/
│   │   └── user_invite_policy.rb
│   └── views/invites/
│       ├── user_invitations/
│       │   ├── error.html.erb
│       │   ├── landing.html.erb
│       │   ├── show.html.erb
│       │   └── signup.html.erb
│       ├── user_invite_mailer/
│       │   ├── invitation.html.erb
│       │   └── invitation.text.erb
│       └── welcome/
│           └── pending_invitation.html.erb

app/interactions/
├── entity/
│   └── invite_user_interaction.rb
└── user/
    └── invite_user_interaction.rb

db/migrate/
└── TIMESTAMP_create_user_invites.rb
```

### Routes Added

```ruby
# Public invitation routes (unauthenticated)
get "welcome", to: "invites/welcome#index"
get "invitations/:token", to: "invites/user_invitations#show"
post "invitations/:token/accept", to: "invites/user_invitations#accept"
get "invitations/:token/signup", to: "invites/user_invitations#signup"
post "invitations/:token/signup", to: "invites/user_invitations#signup"
```

## Connecting Invitables

Invitables are models that trigger invitations and get notified when they're accepted. Common examples:
- `Tenant` - A tenant record that needs a user assigned
- `TeamMember` - A membership record created by admin, waiting for user signup
- `ProjectCollaborator` - A project role waiting for user acceptance

### Generate an Invitable

```bash
rails generate pu:invites:invitable Tenant
rails generate pu:invites:invitable TeamMember --role=member
rails generate pu:invites:invitable Tenant --dest=my_package
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--role=ROLE` | member | Role to assign to invited users |
| `--user-model=NAME` | User | User model name |
| `--membership-model=NAME` | EntityUser | Membership model |
| `--dest=PACKAGE` | main_app | Destination package |
| `--[no-]email-templates` | true | Generate custom email templates |

### Implement the Callback

After generation, implement `on_invite_accepted` in your invitable model:

```ruby
# app/models/tenant.rb
class Tenant < ApplicationRecord
  include Plutonium::Invites::Concerns::Invitable

  belongs_to :entity
  belongs_to :user, optional: true

  def on_invite_accepted(user)
    update!(user: user, status: :active)
  end
end
```

## How the Flow Works

### 1. Admin Sends Invite

An admin uses the "Invite User" action on an entity or invitable:

```ruby
# From entity context
entity.invite_user(email: "user@example.com", role: :member)

# From invitable context (e.g., Tenant)
tenant.invite_user(email: "user@example.com")
```

### 2. Email Sent

The system sends an email with a secure invitation link:

```
Subject: You've been invited to join Acme Corp

Click here to accept: https://app.example.com/invitations/abc123...
```

### 3. User Accepts Invite

**Existing User Flow:**
1. User clicks invite link
2. User logs in (or is already logged in)
3. System validates email matches
4. Membership created, invitable notified

**New User Flow:**
1. User clicks invite link
2. User clicks "Create Account"
3. User signs up with the invited email
4. System validates email matches
5. Membership created, invitable notified

### 4. Pending Invite Check

After login, users are redirected to `/welcome` where pending invites are shown:

```ruby
# In your controller
include Plutonium::Invites::PendingInviteCheck

# Automatically shows pending invites after login
```

## UserInvite Model

The generated `Invites::UserInvite` model includes:

```ruby
class Invites::UserInvite < Invites::ResourceRecord
  include Plutonium::Invites::Concerns::InviteToken

  # Associations
  belongs_to :entity
  belongs_to :invited_by, polymorphic: true
  belongs_to :user, optional: true
  belongs_to :invitable, polymorphic: true, optional: true

  # States: pending, accepted, expired, cancelled
  enum :state, pending: 0, accepted: 1, expired: 2, cancelled: 3

  # Roles
  enum :role, member: 0, admin: 1
end
```

### Key Methods

```ruby
# Find valid invite for acceptance
invite = Invites::UserInvite.find_for_acceptance(token)

# Accept for a user
invite.accept_for_user!(current_user)

# Resend invitation email
invite.resend!

# Cancel invitation
invite.cancel!
```

## Customization

### Custom Email Templates

Override templates in your package:

```erb
<%# packages/invites/app/views/invites/user_invite_mailer/invitation.html.erb %>
<h1>Welcome to <%= @invite.entity.name %>!</h1>
<p><%= @invite.invited_by.email %> has invited you to join.</p>
<p><%= link_to "Accept Invitation", @invitation_url %></p>
```

### Custom Validation

Extend the invite model:

```ruby
# packages/invites/app/models/invites/user_invite.rb
class Invites::UserInvite < Invites::ResourceRecord
  validate :email_not_already_member

  private

  def email_not_already_member
    existing = membership_model.joins(:user)
      .where(entity: entity, users: { email: email })
      .exists?

    errors.add(:email, "is already a member") if existing
  end
end
```

### Domain Enforcement

Enable domain matching in the install:

```bash
rails g pu:invites:install --enforce-domain
```

This requires the invited email domain to match the entity's domain.

### Custom Roles

Specify roles during install:

```bash
rails g pu:invites:install --roles=viewer,editor,admin,owner
```

## Integration with Portals

### Connect Invites to Your Portal

```ruby
# packages/customer_portal/lib/engine.rb
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    # Register the invites package for this portal
    register_package Invites::Engine
  end
end
```

### Entity-Scoped Invite Management

The `Invites::UserInvite` definition automatically scopes to the current entity:

```ruby
# In your portal, invites are automatically filtered by entity_scope
# Admins only see invites for their organization
```

## Troubleshooting

### Invite Not Found

- Check the token hasn't expired (default: 1 week)
- Verify the invite hasn't been cancelled
- Ensure the invite is still in `pending` state

### Email Mismatch Error

The system requires the accepting user's email to match the invited email:

```
"This invitation is for user@example.com. You must use an account with that email address."
```

To allow any email (not recommended for security):

```ruby
# In your UserInvite model
def enforce_email?
  false
end
```

### Rodauth Integration Issues

Ensure the Rodauth plugin is configured:

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

## Related Skills

- `plutonium-rodauth` - Authentication setup
- `plutonium-interaction` - Custom business logic
- `plutonium-portal` - Portal configuration
- `plutonium-policy` - Authorization for invite actions
