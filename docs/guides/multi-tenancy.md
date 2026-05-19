# Multi-tenancy

Isolate data by organization, account, or any other "entity". Plutonium handles the URL strategy, query scoping, form injection, and `belongs_to` auto-detection automatically.

## Goal

Each tenant sees only their own records. Queries are filtered, forms inject the tenant on create, URLs include the tenant id, and policies receive the tenant for authorization.

## 🚨 Critical

- **Never bypass `default_relation_scope`.** Overriding `relation_scope` with `where(organization: ...)` or manual joins triggers `verify_default_relation_scope_applied!` at runtime. Make sure `default_relation_scope(relation)` is called somewhere in the chain — explicitly here, or via `super` to a parent policy (e.g., a package base) that calls it.
- **Always declare an association path from the model to the entity.** Direct `belongs_to`, `has_one :through`, or a custom `associated_with_<entity>` scope. If `associated_with` can't resolve, fix the **model**, not the policy.
- **Compound uniqueness scoped to the tenant FK.** `validates :code, uniqueness: {scope: :organization_id}` — without this, uniqueness leaks across tenants.

## Quickest path: `pu:saas:setup`

```bash
rails g pu:saas:setup --user Customer --entity Organization
```

This **meta-generator** creates the user + entity + membership trio AND runs `pu:saas:portal`, `pu:profile:setup`, `pu:saas:welcome`, and `pu:invites:install` in one shot. The portal is fully wired for entity scoping.

See [Reference › Auth › Accounts › SaaS setup](/reference/auth/accounts#saas-setup-pu-saas-setup).

## Manual setup

### 1. Create the entity model

```bash
rails g pu:res:scaffold Organization name:string:uniq slug:string:uniq --dest=main_app
```

### 2. Add the FK to each tenant-scoped resource

```bash
rails g pu:res:scaffold Post organization:belongs_to title:string content:text --dest=main_app
rails db:migrate
```

### 3. Scope the portal to the entity

```ruby
# packages/customer_portal/lib/engine.rb
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

Or pass `--scope=Organization` to `pu:pkg:portal` and the engine wires this automatically.

### 4. Mount the portal

```ruby
# config/routes.rb
mount CustomerPortal::Engine, at: "/customer"
```

URLs now include the entity id: `/customer/organizations/42/posts`.

### 5. Compound uniqueness

```ruby
class Post < ResourceRecord
  belongs_to :organization
  validates :slug, uniqueness: {scope: :organization_id}
end
```

🚨 Without the `scope:`, the same slug in different orgs would collide.

## Strategies

### Path strategy (default)

```ruby
scope_to_entity Organization, strategy: :path
# → /organizations/:organization_id/posts
```

### Custom param key

```ruby
scope_to_entity Organization, strategy: :path, param_key: :org_id
# → /orgs/:org_id/posts
```

### Subdomain / session / custom

```ruby
scope_to_entity Organization, strategy: :current_organization
```

Then implement the method on the portal's controller concern:

```ruby
module CustomerPortal::Concerns::Controller
  extend ActiveSupport::Concern
  include Plutonium::Portal::Controller

  private

  def current_organization
    @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
  end
end
```

## Three model shapes

How tenant scoping resolves depends on how the model relates to the entity. Three shapes, pick the lightest:

### 1. Direct `belongs_to`

```ruby
class Post < ResourceRecord
  belongs_to :organization
end
# Post.associated_with(org) → Post.where(organization: org)
```

Auto-detected. Use when the model naturally has a direct FK to the entity.

### 2. Join table (`belongs_to` AND `belongs_to`)

```ruby
class Membership < ResourceRecord
  belongs_to :user
  belongs_to :organization   # auto-detected
end
```

### 3. Grandchild — `has_one :through`

```ruby
class Post < ResourceRecord
  belongs_to :user
  has_one :organization, through: :user   # ← critical
end
```

Auto-detected via `reflect_on_all_associations`. Declaring `has_one :through` is the lightest fix when the path is two hops.

Full mechanics: [Reference › Tenancy › Entity scoping › Three model shapes](/reference/tenancy/entity-scoping#three-model-shapes).

## Custom scope (when the path is polymorphic or needs SQL control)

```ruby
class Comment < ResourceRecord
  scope :associated_with_organization, ->(org) {
    joins(task: :project).where(projects: {organization_id: org.id})
  }
end
```

Plutonium picks this up **before** trying association detection.

## Accessing the scoped entity

```ruby
# Controller / views
current_scoped_entity
scoped_to_entity?

# Policy
entity_scope
```

## Policy filtering on top of default

```ruby
relation_scope do |relation|
  default_relation_scope(relation).where(archived: false)
end
```

🚨 `default_relation_scope(relation)` must be called somewhere in the chain — otherwise the runtime verification raises. Calling it explicitly here is safest; `super` works only if the parent policy also calls it.

## Cross-tenant operations — super-admin portal

Create a separate portal **without** `scope_to_entity`:

```ruby
module SuperAdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine
    # No scope_to_entity — sees all tenants
  end
end
```

This portal's policies see everything. Don't enable public signup here.

## Multiple associations to the same entity

If a model has two `belongs_to` to the entity class (e.g. `Match belongs_to :home_team, :away_team`), Plutonium raises:

```
Match has multiple associations to Competition::Team: home_team, away_team.
Plutonium cannot auto-detect which one to use for entity scoping.
```

Override on the controller:

```ruby
class MatchesController < ::ResourceController
  private
  def scoped_entity_association = :home_team
end
```

## Common issues

- **`verify_default_relation_scope_applied!` raises** — your custom `relation_scope` doesn't call `default_relation_scope(relation)`. Fix by composing: `default_relation_scope(relation).where(...)`.
- **`Could not resolve the association between 'Model' and 'Entity'`** — the model has no path to the entity. Fix on the **model** (declare `has_one :through` or a custom `associated_with_<entity>` scope). Never paper over with `where` in the policy.
- **Records leak across tenants** — likely a missing compound-uniqueness scope on the model. Add `validates :code, uniqueness: {scope: :organization_id}`.
- **Forms show the entity field anyway** — check `present_scoped_entity?` / `submit_scoped_entity?` on the controller (defaults are `false`).
- **Want to bypass scoping in one place** — use `skip_default_relation_scope!` explicitly, NOT a silent `where` bypass.

## Related

- [Reference › Tenancy › Entity scoping](/reference/tenancy/entity-scoping) — full surface
- [Reference › Behavior › Policies](/reference/behavior/policies) — `relation_scope` syntax
- [Reference › App › Portals](/reference/app/portals) — `scope_to_entity` engine config
- [Nested resources](./nested-resources) — parent scoping (takes precedence over entity scoping)
- [User invites](./user-invites) — invitation-based membership onboarding
