# Entity Scoping

Multi-tenant data isolation. Built on three cooperating pieces — portal, policy, model — that together ensure queries never leak across tenants.

## 🚨 Critical

- **Never bypass `default_relation_scope`.** Overriding `relation_scope` with `where(organization: ...)` or manual joins to the entity triggers `verify_default_relation_scope_applied!`. Always call `default_relation_scope(relation)` explicitly.
- **Don't rely on `super`** inside `relation_scope` — call `default_relation_scope(relation)` by name.
- **Fix the MODEL, not the policy.** If `associated_with` can't resolve, declare an association path (`belongs_to`, `has_one :through`) OR a custom `associated_with_<entity>` scope on the model. Never paper over it with a `where` in the policy.
- **Compound uniqueness scoped to the tenant FK** — `validates :code, uniqueness: {scope: :organization_id}`.
- **Multiple associations to the same entity class** require overriding `scoped_entity_association` on the controller.

## The three pieces

| Piece | Role | Where |
|---|---|---|
| **Portal** | Declares the entity class and resolution strategy | `scope_to_entity Organization, strategy: :path` in the engine |
| **Policy** | Applies the scope to every collection query | `default_relation_scope(relation)` (auto-called) |
| **Model** | Resolves the scope path | Direct `belongs_to`, `has_one :through`, or custom scope |

`default_relation_scope` is enforced — if you override `relation_scope` without calling it, `verify_default_relation_scope_applied!` raises at runtime.

## `associated_with` resolution

`Model.associated_with(entity)` resolves in this order:

1. **Custom scope** `associated_with_<entity_name>` (e.g. `associated_with_organization`) — highest priority, full SQL control.
2. **Direct `belongs_to` to the entity class** — `WHERE <entity>_id = ?`, most efficient.
3. **`has_one` / `has_one :through` to the entity class** — JOIN + WHERE, auto-detected via `reflect_on_all_associations`.
4. **Reverse `has_many` from the entity** — JOIN required, logs a warning (less efficient).

If none apply:

```
Could not resolve the association between 'Model' and 'Entity'
```

Fix on the **model** — either declare an association path (`belongs_to`, `has_one :through`) OR define a custom `associated_with_<entity>` scope. Never work around this by overriding `relation_scope` in the policy.

## Three model shapes

The `associated_with` resolver handles three common shapes. Pick the lightest that fits.

### Shape 1: Direct child (`belongs_to` the entity)

```ruby
class Organization < ResourceRecord
  has_many :projects
end

class Project < ResourceRecord
  belongs_to :organization
end

Project.associated_with(org)
# => Project.where(organization: org)    — simple WHERE, most efficient
```

Auto-detected. Use this when the model naturally has a direct FK to the entity.

### Shape 2: Join table (membership-style)

A join table linking users to entities, where the entity is reachable via one of the `belongs_to`:

```ruby
class User < ResourceRecord
  has_many :memberships
  has_many :organizations, through: :memberships
end

class Organization < ResourceRecord
  has_many :memberships
  has_many :users, through: :memberships
end

class Membership < ResourceRecord
  belongs_to :user
  belongs_to :organization    # ← auto-detection finds :organization via belongs_to
end

Membership.associated_with(org)
# => Membership.where(organization: org)
```

If the join table is itself a parent and the scoped target is two hops away, add `has_one :through`:

```ruby
class ProjectMember < ResourceRecord
  belongs_to :project
  belongs_to :user
  has_one :organization, through: :project   # ← enables auto-scoping
end
```

Now `ProjectMember.associated_with(org)` resolves via the `has_one :through`.

### Shape 3: Grandchild (multi-hop via `has_one :through`)

```ruby
class Organization < ResourceRecord
  has_many :projects
end

class Project < ResourceRecord
  belongs_to :organization
  has_many :tasks
end

class Task < ResourceRecord
  belongs_to :project
  has_one :organization, through: :project   # ← critical
end

# Deeper
class Comment < ResourceRecord
  belongs_to :task
  has_one :project, through: :task
  has_one :organization, through: :project   # ← enables auto-scoping at 3 hops
end
```

`Task.associated_with(org)` and `Comment.associated_with(org)` both auto-resolve.

::: tip Declaring `has_one :through` is the lightest fix
For grandchildren, the `has_one :through` on the model is all you need — `associated_with` finds it automatically. No policy override needed.
:::

### When to fall back to a custom scope

Use a custom `associated_with_<entity>` scope when:

- The path is polymorphic.
- The path needs conditional logic.
- You want explicit SQL for performance (e.g. avoid a multi-join chain).

```ruby
class Comment < ResourceRecord
  scope :associated_with_organization, ->(org) do
    joins(task: :project).where(projects: {organization_id: org.id})
  end
end
```

Plutonium picks this up **before** trying association detection.

## `relation_scope` — safe override patterns

`default_relation_scope(relation)` does two things:

1. If a **parent** is present (nested resource), scopes via the parent association.
2. Otherwise, applies `relation.associated_with(entity_scope)`.

### Correct

```ruby
# ✅ Best — don't override at all. The inherited scope already calls default_relation_scope.

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

::: danger Don't use `super`
`super` inside `relation_scope` is unreliable — its semantics depend on how ActionPolicy's DSL registered the scope. Call `default_relation_scope(relation)` by name.
:::

### Intentionally skipping the scope

Rare, but possible:

```ruby
relation_scope do |relation|
  skip_default_relation_scope!
  relation
end
```

Before reaching for this, consider a separate, unscoped portal.

## Portal entity strategies

The portal declares how the current entity is resolved from the request.

### Path strategy (most common)

```ruby
module CustomerPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :path
    end
  end
end
```

Routes become `/organizations/:organization_id/posts`. The portal extracts `params[:organization_id]` and loads the entity automatically.

### Custom strategy (subdomain, session, etc.)

```ruby
module CustomerPortal::Concerns::Controller
  extend ActiveSupport::Concern
  include Plutonium::Portal::Controller

  private

  def current_organization
    @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
  end
end

# Engine
scope_to_entity Organization, strategy: :current_organization
```

The strategy symbol must match a method name on the controller concern.

### Custom param key

When the param name differs from the entity model name:

```ruby
scope_to_entity Organization, strategy: :path, param_key: :org_id
# → /orgs/:org_id/posts
```

### Accessing the scoped entity

```ruby
# Controller / views
current_scoped_entity     # => current Organization
scoped_to_entity?         # => true / false

# Policy
entity_scope              # => current Organization
```

## Cross-tenant operations

### Super-admin portal — no scoping

Create a separate portal without `scope_to_entity`:

```ruby
module SuperAdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    # No scope_to_entity — sees all tenants
  end
end
```

This portal's policies see everything. Don't enable public signup here.

### Conditional scoping

```ruby
class PostPolicy < ResourcePolicy
  relation_scope do |relation|
    return default_relation_scope(relation).where(category: :public) if user.guest?
    default_relation_scope(relation)
  end
end
```

## Multiple associations to the same entity class

Example: `Match belongs_to :home_team, :away_team` both pointing at `Team`. Plutonium raises:

```
Match has multiple associations to Competition::Team: home_team, away_team.
Plutonium cannot auto-detect which one to use for entity scoping.
Override `scoped_entity_association` in your controller to specify the association.
```

Override on the controller:

```ruby
class MatchesController < ::ResourceController
  private
  def scoped_entity_association = :home_team
end
```

## `param_key` differs from association name

Plutonium matches by **class**, not param key:

```ruby
# Portal config
scope_to_entity Competition::Team, param_key: :team

# Model — association name differs from param_key, but Plutonium finds by class
class Match < ApplicationRecord
  belongs_to :competition_team   # ← Plutonium auto-detects this
end
```

## How the pieces fit together

1. An admin opens `/organizations/42/projects`.
2. Portal's `scope_to_entity Organization, strategy: :path` extracts `42`, loads the `Organization`, sets `current_scoped_entity`.
3. The controller calls the policy. The policy's inherited `relation_scope` calls `default_relation_scope(relation)`.
4. `default_relation_scope` has no parent (top-level nested-from-portal), so it calls `relation.associated_with(current_scoped_entity)`.
5. `Project.associated_with(org)` resolves via the direct `belongs_to :organization` → `Project.where(organization: org)`.
6. Only that organization's projects render. Records from other orgs are invisible.

Any model that can't be reached from the entity via these rules MUST declare a `has_one :through` or a custom scope.

## Compound uniqueness

Always scope tenant-affecting uniqueness constraints:

```ruby
class Property < ResourceRecord
  belongs_to :organization
  validates :code, uniqueness: {scope: :organization_id}    # ← critical
end
```

Without the scope, uniqueness leaks across tenants — Org A and Org B could collide on the same code.

## Gotchas

- **Policy tries to filter by entity directly.** Wrong — bypasses `default_relation_scope`. Add the association path to the model instead.
- **`super` inside `relation_scope`.** Unreliable. Use `default_relation_scope(relation)` explicitly.
- **Multiple associations to the same entity class.** Override `scoped_entity_association`.
- **`param_key` differs from association name.** Fine — Plutonium finds the association by class.
- **Forgetting compound uniqueness.** A unique constraint on `:code` alone leaks across tenants.
- **"Temporary" `where` bypass for debugging.** Use `skip_default_relation_scope!` explicitly — never leave a `where` bypass in code.

## Related

- [Nested resources](./nested-resources) — parent scoping takes precedence over entity scoping
- [Invites](./invites) — membership-based onboarding
- [Resource › Model](/reference/resource/model) — `associated_with`, model conventions
- [Behavior › Policy](/reference/behavior/policies) — `relation_scope` syntax
- [App › Portals](/reference/app/portals) — `scope_to_entity` engine config
