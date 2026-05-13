---
name: plutonium-tenancy
description: Use BEFORE any multi-tenant work — scoping a model to a tenant, writing relation_scope, configuring portal entity strategies, setting up parent/child nested resources, or wiring user invitations. The single source for entity scoping, nested resources, and invites.
---

# Plutonium Tenancy — Entity Scoping, Nested Resources, Invites

Three closely-coupled concerns:

1. **Entity scoping** — every record belongs to a tenant; queries are filtered automatically.
2. **Nested resources** — parent/child URLs; parent scoping takes precedence over entity scoping.
3. **Invites** — onboarding users into a tenant's membership.

Cross-references back to [[plutonium-resource]] (models, definitions) and [[plutonium-behavior]] (policies, controllers).

## 🚨 Critical (read first)

- **Never bypass `default_relation_scope`.** Overriding `relation_scope` with `where(organization: ...)` or manual joins to the entity triggers `verify_default_relation_scope_applied!`. Always call `default_relation_scope(relation)` explicitly — not `super`.
- **Always declare an association path from model to entity.** Direct `belongs_to`, `has_one :through`, or a custom `associated_with_<entity>` scope. If `associated_with` can't resolve, Plutonium raises. Fix the **model**, not the policy.
- **Parent scoping beats entity scoping.** When a parent is present (nested resource), `default_relation_scope` scopes via the parent, NOT via `entity_scope`. Don't double-scope.
- **One level of nesting only.** Grandparent → parent → child nested routes are NOT supported. Use top-level routes for deeper relationships.
- **Compound uniqueness scoped to the tenant FK.** `validates :code, uniqueness: {scope: :organization_id}` — without this, uniqueness leaks across tenants.
- **Invite email must match the accepting user's email.** Security feature. Don't disable `enforce_email?` lightly.
- **Use generators.** `pu:saas:setup`, `pu:pkg:portal --scope=Entity`, `pu:res:scaffold`, `pu:invites:install`, `pu:invites:invitable`. Hand-wiring is how leaks happen.

---

# Part 1 — Entity Scoping

Built on three cooperating pieces:

| Piece | Role |
|---|---|
| **Portal** | Declares the entity class and how to resolve it (`scope_to_entity Organization, strategy: :path`). |
| **Policy** | `default_relation_scope(relation)` calls `relation.associated_with(entity_scope)` on every collection query. Enforced via `verify_default_relation_scope_applied!`. |
| **Model** | `associated_with(entity)` resolves via custom scope, direct association, or `has_one :through`. |

## `associated_with` resolution order

`Model.associated_with(entity)` tries, in order:

1. **Custom scope** `associated_with_<entity_name>` — highest priority, full SQL control.
2. **Direct `belongs_to` to entity class** — `WHERE <entity>_id = ?`, most efficient.
3. **`has_one` / `has_one :through` to entity class** — JOIN + WHERE, auto-detected via `reflect_on_all_associations`.
4. **Reverse `has_many` from entity** — JOIN required, logs a warning (less efficient).

If none apply: `Could not resolve the association between 'Model' and 'Entity'`. Fix on the **model** — either declare an association path (`belongs_to`, `has_one :through`) OR define a custom `associated_with_<entity>` scope. Never work around this by overriding `relation_scope` in the policy.

## Three model shapes

Pick the lightest that fits.

### Shape 1: Direct child (`belongs_to` the entity)

```ruby
class Organization < ResourceRecord
  has_many :projects
end

class Project < ResourceRecord
  belongs_to :organization
end

Project.associated_with(org)
# => Project.where(organization: org)
```

Auto-detected. No extra work.

### Shape 2: Join table (membership)

```ruby
class User < ResourceRecord
  has_many :memberships
  has_many :organizations, through: :memberships
end

class Membership < ResourceRecord
  belongs_to :user
  belongs_to :organization     # auto-detected
end

Membership.associated_with(org)
# => Membership.where(organization: org)
```

If `Membership` is itself a parent and the scoped target is two hops away, add `has_one :through`:

```ruby
class ProjectMember < ResourceRecord
  belongs_to :project
  belongs_to :user
  has_one :organization, through: :project   # enables auto-scoping
end
```

### Shape 3: Grandchild (multi-hop via `has_one :through`)

```ruby
class Project < ResourceRecord
  belongs_to :organization
  has_many :tasks
end

class Task < ResourceRecord
  belongs_to :project
  has_one :organization, through: :project   # critical
end

class Comment < ResourceRecord
  belongs_to :task
  has_one :project, through: :task
  has_one :organization, through: :project   # multi-hop chain
end
```

`Task.associated_with(org)` and `Comment.associated_with(org)` both auto-resolve.

### When to fall back to a custom scope

```ruby
class Comment < ResourceRecord
  scope :associated_with_organization, ->(org) do
    joins(task: :project).where(projects: {organization_id: org.id})
  end
end
```

Use when:
- The path is polymorphic.
- Conditional logic is needed.
- You want explicit SQL for performance.

Picked up BEFORE association detection.

## `relation_scope` — safe overrides

`default_relation_scope(relation)` does two things:

1. If a **parent** is present (nested resource), scopes via the parent association.
2. Otherwise, applies `relation.associated_with(entity_scope)`.

### Correct

```ruby
# ✅ Best: don't override — the inherited scope already does it.

# ✅ Extra filters on top
relation_scope do |relation|
  default_relation_scope(relation).where(archived: false)
end

# ✅ Role-based
relation_scope do |relation|
  relation = default_relation_scope(relation)
  user.admin? ? relation : relation.where(author: user)
end
```

### Wrong

```ruby
# ❌ Manually filtering by entity — bypasses default_relation_scope
relation_scope { |r| r.where(organization: current_scoped_entity) }

# ❌ Manual joins — same problem
relation_scope { |r| r.joins(:project).where(projects: {organization_id: current_scoped_entity.id}) }

# ❌ Missing default_relation_scope entirely — raises at runtime
relation_scope { |r| r.where(published: true) }
```

**Do not use `super`** from inside `relation_scope`. Call `default_relation_scope(relation)` explicitly — `super` semantics depend on how ActionPolicy's DSL registered the scope.

### Intentionally skipping

Rare. Before reaching for this, consider a separate, unscoped portal.

```ruby
relation_scope do |relation|
  skip_default_relation_scope!
  relation
end
```

## Portal entity strategies

### Path strategy (most common)

```ruby
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

Routes become `/organizations/:organization_id/posts`. Portal extracts `params[:organization_id]` and loads the entity automatically.

### Custom strategy (subdomain, session, etc.)

```ruby
scope_to_entity Organization, strategy: :current_organization

module AdminPortal::Concerns::Controller
  extend ActiveSupport::Concern
  include Plutonium::Portal::Controller

  private

  def current_organization
    @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
  end
end
```

The strategy symbol must match a method name on the controller.

### Accessing the scoped entity

```ruby
# Controller
current_scoped_entity
scoped_to_entity?

# Policy
entity_scope
```

## Gotchas

- **Multiple associations to the same entity class.** E.g. `Match belongs_to :home_team, :away_team` both pointing at `Team`. Plutonium raises — override `scoped_entity_association` on the controller to pick one (`def scoped_entity_association = :home_team`).
- **`param_key` differs from association name.** Fine — Plutonium matches by **class**, not param key. `scope_to_entity Competition::Team, param_key: :team` works with `belongs_to :competition_team`.
- **Forgetting compound uniqueness.** `validates :code, uniqueness: true` leaks across tenants. Use `uniqueness: {scope: :organization_id}`.
- **"Temporary" `where` bypass for debugging.** Use `skip_default_relation_scope!` explicitly. Never leave a `where` bypass in code.

---

# Part 2 — Nested Resources

Plutonium auto-generates nested routes from `has_many` / `has_one` associations on a registered parent. **One level only** — no grandparent → parent → child chains.

## Setup

```bash
rails g pu:res:scaffold Company name:string --dest=main_app
rails g pu:res:scaffold Property company:belongs_to name:string --dest=main_app
rails g pu:res:conn Company Property --dest=admin_portal
```

Then register both in the portal routes:

```ruby
register_resource ::Company
register_resource ::Property          # has belongs_to :company
register_resource ::CompanyProfile    # has_one :company_profile on Company
```

## Generated routes

Plutonium prefixes nested routes with `nested_` to avoid conflicts with the top-level routes:

| Route | Purpose |
|---|---|
| `/companies/:company_id/nested_properties` | has_many index |
| `/companies/:company_id/nested_properties/new` | new |
| `/companies/:company_id/nested_properties/:id` | show |
| `/companies/:company_id/nested_company_profile` | has_one show (no `:id`) |
| `/companies/:company_id/nested_company_profile/new` | has_one new |

For `has_one`: index redirects to show (or new if no record exists); only one record per parent.

## Automatic behavior in nested routes

When the controller is hit through a nested route:

1. **Resolves the parent** via `current_parent`, authorized for `:read?`.
2. **Scopes queries** via parent association (e.g. `parent.properties` for `has_many`, `where(foreign_key => parent.id)` for `has_one`).
3. **Assigns parent** on create (injected into `resource_params`).
4. **Hides parent field** in forms (already determined by URL).

You don't need to add hidden parent fields in forms or filter queries manually.

## Controller methods

```ruby
current_parent              # Parent record
current_nested_association  # :properties
parent_route_param          # :company_id
parent_input_param          # :company
```

## Parent vs entity scoping

When a parent is present, **parent scoping wins**: `default_relation_scope` scopes via the parent association, not `entity_scope`. The parent was already authorized and entity-scoped during its own authorization — double-scoping isn't needed.

```ruby
# In the child policy — just call default_relation_scope, it handles both cases
relation_scope do |relation|
  default_relation_scope(relation)      # uses parent when present, entity_scope otherwise
end
```

## URL generation

```ruby
# Collection
resource_url_for(Property, parent: company)
# => /companies/123/nested_properties

# Record
resource_url_for(property, parent: company)
# => /companies/123/nested_properties/456

# Form
resource_url_for(Property, action: :new, parent: company)
resource_url_for(property, action: :edit, parent: company)

# has_one
resource_url_for(CompanyProfile, action: :new, parent: company)
# => /companies/123/nested_company_profile/new

# Interactions
resource_url_for(property, parent: company, interaction: :archive)
resource_url_for(Property, parent: company, interaction: :import)
resource_url_for(Property, parent: company, interaction: :bulk_delete, ids: [1, 2])

# Cross-package
resource_url_for(property, parent: company, package: CustomerPortal)
```

## Authorization context

The child policy receives the parent:

```ruby
class PropertyPolicy < ResourcePolicy
  # parent              => the Company instance
  # parent_association  => :properties

  def create?
    parent.present? && user.member_of?(parent)
  end
end
```

## Presentation hooks

```ruby
class PropertiesController < ResourceController
  private

  def present_parent?  = true          # show parent in displays (default: false)
  def submit_parent?   = false         # allow changing in forms (defaults to present_parent?)
end
```

Conditional pattern — show parent only when accessed standalone:

```ruby
def present_parent?
  current_parent.nil?
end
```

## Custom parent resolution

```ruby
def current_parent
  @current_parent ||= Company.friendly.find(params[:company_id])
end
```

## Custom nested routes

```ruby
register_resource ::Property do
  member do
    get :analytics, as: :analytics    # `as:` is REQUIRED for resource_url_for to work
    post :archive,  as: :archive
  end
end
```

Generates `/companies/:company_id/nested_properties/:id/analytics` etc.

## Breadcrumbs

Auto-include parent: `Companies > Acme Corp > Properties > Property #123`.

---

# Part 3 — Invites

A complete user-invitation system: token-based emails, secure acceptance, Rodauth integration, entity membership creation, and "invitable" hooks for app-specific behavior.

## Prerequisites

User model + entity model + membership model. The fastest path:

```bash
rails g pu:saas:setup --user Customer --entity Organization
```

This creates all three plus the join table.

## Install

```bash
rails generate pu:invites:install
```

### Options

| Option | Default | Description |
|---|---|---|
| `--entity-model=NAME` | `Entity` | Entity model name |
| `--user-model=NAME` | `User` | User model name |
| `--invite-model=NAME` | `<EntityModel><UserModel>Invite` | Invite class name (omit for single-flow apps) |
| `--membership-model=NAME` | `EntityUser` | Membership join model |
| `--roles=ROLES` | `member,admin` | Comma-separated |
| `--rodauth=NAME` | `user` | Rodauth configuration for signup |
| `--enforce-domain` | `false` | Require invited email domain to match entity |

### What gets created

```
packages/invites/
├── app/controllers/invites/
│   ├── user_invitations_controller.rb
│   └── welcome_controller.rb
├── app/definitions/invites/user_invite_definition.rb
├── app/interactions/invites/
│   ├── cancel_invite_interaction.rb
│   └── resend_invite_interaction.rb
├── app/mailers/invites/user_invite_mailer.rb
├── app/models/invites/user_invite.rb
├── app/policies/invites/user_invite_policy.rb
└── app/views/invites/...

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

## Multiple invite flows in one app

Run `pu:invites:install` once per flow. Default class name derives as `<EntityModel><UserModel>Invite` — no literal `UserInvite` default. Single-flow apps don't need `--invite-model`.

```bash
rails g pu:invites:install \
  --entity-model=FunderOrganization --user-model=SpenderAccount \
  --invite-model=FunderInvite

rails g pu:invites:install \
  --entity-model=Project --user-model=Member \
  --invite-model=ProjectInvite
```

Each invocation creates an independent model (`Invites::FunderInvite`), controller (`Invites::FunderInvitationsController`), route (`/funder_invitations/:token`), and helper (`funder_invitation_path`). The shared `Invites::WelcomeController` accumulates each class into `invite_classes`; `pending_invite` checks all flows in priority order (first-match wins).

Model-level overrides for non-default association names:

```ruby
def user_attribute         = :spender_account     # belongs_to :spender_account
def invite_entity_attribute = :funder_organization # belongs_to :funder_organization
```

Controller-level (auto-generated, but shown for clarity):

```ruby
# welcome_controller.rb
def invite_classes
  [::Invites::FunderInvite, ::Invites::ProjectInvite]
end

# funder_invitations_controller.rb
def invitation_path_for(token)
  funder_invitation_path(token: token)
end
```

## Invitables — app models notified on accept

An "invitable" is an app model that triggers invitations and gets notified when one is accepted. Examples: `Tenant`, `TeamMember`, `ProjectCollaborator`.

```bash
rails generate pu:invites:invitable Tenant
rails generate pu:invites:invitable TeamMember --role=member
rails generate pu:invites:invitable Tenant --dest=my_package
```

Then implement the callback:

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

Without `on_invite_accepted`, the invitable never learns about the new user.

## The flow

### 1. Admin sends the invite

```ruby
entity.invite_user(email: "user@example.com", role: :member)
tenant.invite_user(email: "user@example.com")          # from invitable context
```

### 2. Email goes out

Token-based URL: `https://app.example.com/invitations/abc123...`

### 3. User accepts

**Existing user:** clicks link → logs in (or already logged in) → email validated → membership created → invitable notified via `on_invite_accepted`.

**New user:** clicks link → "Create Account" → signs up with the invited email → membership created → invitable notified.

### 4. Pending invite check

After login, users land on `/welcome` where pending invites are shown:

```ruby
include Plutonium::Invites::PendingInviteCheck
```

Rodauth wiring (required for redirect):

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

### Custom validation

Extend the model:

```ruby
class Invites::UserInvite < Invites::ResourceRecord
  validate :email_not_already_member

  private

  def email_not_already_member
    existing = membership_model.joins(:user)
      .where(entity: entity, users: {email: email}).exists?
    errors.add(:email, "is already a member") if existing
  end
end
```

### Domain enforcement / custom roles

```bash
rails g pu:invites:install --enforce-domain
rails g pu:invites:install --roles=viewer,editor,admin,owner
```

## Portal connection

```ruby
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
    register_package Invites::Engine
  end
end
```

Invites are entity-scoped automatically: `Invites::UserInvite belongs_to :entity` → `associated_with` resolves directly → admins see only invites for their org.

## Common issues

- **"Invite not found"** — token expired (default 1 week), invite cancelled, or no longer `pending`.
- **Email mismatch** — `enforce_email?` is on by default. The accepting user's email must match the invited email. Override `def enforce_email? = false` only if you fully understand the security trade-off.
- **Rodauth redirect after login** — make sure `login_redirect "/welcome"` is set in the rodauth plugin.

---

## Related skills

- [[plutonium-resource]] — model declarations (`belongs_to`, `has_one :through`, custom scopes), `permitted_associations` for show-page tabs.
- [[plutonium-behavior]] — `relation_scope` syntax, policy authorization context, controller presentation hooks.
- [[plutonium-app]] — portal setup, `scope_to_entity`, mounting engines.
- [[plutonium-auth]] — Rodauth signup flow for invite acceptance.
