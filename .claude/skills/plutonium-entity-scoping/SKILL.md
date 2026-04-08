---
name: plutonium-entity-scoping
description: Use BEFORE writing relation_scope, associated_with, scoping a model to a tenant, or any multi-tenancy work. Also when configuring entity strategies on a portal. The single source of truth for Plutonium entity scoping.
---

# Plutonium Entity Scoping

The single source of truth for how Plutonium scopes records to a tenant/entity in multi-tenant apps. Entity scoping spans models, policies, portals, and invites — this skill consolidates the canonical rules so you don't have to stitch them together from four other skills.

## 🚨 Critical (read first)

- **Never bypass `default_relation_scope`.** Overriding `relation_scope` with `where(organization: ...)` or manual joins to the entity skips Plutonium's scoping and triggers `verify_default_relation_scope_applied!`. Always call `default_relation_scope(relation)` explicitly (not `super`).
- **Always declare an association path from the model to the entity.** If `associated_with` can't find a path — direct `belongs_to`, `has_one :through`, or a custom `associated_with_<entity>` scope — Plutonium raises. Fix the **model**, not the policy.
- **Use a generator to scaffold scoped resources.** `pu:saas:setup`, `pu:pkg:portal --scope=Entity`, and `pu:res:scaffold` do the right thing. Hand-wiring scoping is how leaks happen.
- **Parent scoping beats entity scoping.** When a parent is present (nested resource), `default_relation_scope` scopes via the parent, not via `entity_scope`. Don't double-scope.
- **Related skills:** `plutonium-model` (associations, `associated_with`), `plutonium-policy` (`relation_scope` overrides), `plutonium-portal` (entity strategies), `plutonium-invites` (membership-backed scoping).

## Quick checklist

Scoping a new model to a tenant:

1. Pick the shape: direct child, join table, or grandchild (see [Three model shapes](#three-model-shapes)).
2. Declare the association path on the model (`belongs_to`, `has_one :through`, or a custom `associated_with_<entity>` scope).
3. Verify `Model.associated_with(entity)` returns the right records in `rails runner`.
4. Confirm the portal is scoped: `scope_to_entity Entity, strategy: :path` (or custom) in the portal engine.
5. Leave `relation_scope` alone in the policy unless you need **extra** filters on top of the default.
6. If you do override `relation_scope`, wrap with `default_relation_scope(relation).where(...)`.
7. Add compound uniqueness scoped to the entity on the model (`validates :code, uniqueness: {scope: :organization_id}`).
8. Test: create a record in org A, confirm it does NOT appear when scoped to org B.

## How entity scoping works

Plutonium's entity scoping is built on three cooperating pieces:

- **Portal**: declares which entity class it scopes to (`scope_to_entity Organization, strategy: :path`) and how to resolve the current entity from the request.
- **Policy**: `default_relation_scope(relation)` calls `relation.associated_with(entity_scope)`, applying the scope to every collection query.
- **Model**: `associated_with(entity)` resolves the scope via a custom scope, a direct association, or auto-detected `has_one :through` chain.

The `default_relation_scope` is enforced — if you override `relation_scope` without calling it, `verify_default_relation_scope_applied!` raises at runtime.

## `associated_with` resolution

`Model.associated_with(entity)` resolves in this order:

1. **Custom named scope** `associated_with_<model_name>` (e.g. `associated_with_organization`) — highest priority, full control over the SQL.
2. **Direct `belongs_to` to the entity class** — `WHERE <entity>_id = ?`, most efficient.
3. **`has_one` / `has_one :through` to the entity class** — JOIN + WHERE, auto-detected via `reflect_on_all_associations`.
4. **Reverse `has_many` from the entity** — JOIN required, logs a warning (less efficient).

If none apply, raises:

```
Could not resolve the association between 'Model' and 'Entity'
```

with guidance to either add an association or define the custom scope.

## `default_relation_scope` and safe `relation_scope` overrides

`default_relation_scope(relation)` does two things:

1. If a **parent** is present (nested resource), scopes the relation via the parent association.
2. Otherwise, applies `relation.associated_with(entity_scope)`.

### Correct overrides

```ruby
# ✅ Best: don't override at all — the inherited scope already calls default_relation_scope.

# ✅ Add extra filters on top of default scope
relation_scope do |relation|
  default_relation_scope(relation).where(archived: false)
end

# ✅ Role-based extra filter
relation_scope do |relation|
  relation = default_relation_scope(relation)
  user.admin? ? relation : relation.where(author: user)
end
```

### Wrong overrides

```ruby
# ❌ Manually filtering by the scoped entity — bypasses default_relation_scope
relation_scope do |relation|
  relation.where(organization: current_scoped_entity)
end

# ❌ Manual joins — same problem
relation_scope do |relation|
  relation.joins(:project).where(projects: {organization_id: current_scoped_entity.id})
end

# ❌ Missing default_relation_scope entirely — raises at runtime
relation_scope do |relation|
  relation.where(published: true)
end
```

**Do not rely on `super`** from inside `relation_scope do ... end`. `default_relation_scope` is the documented public contract; `super` semantics depend on how ActionPolicy's DSL registered the scope and aren't guaranteed.

### Intentionally skipping the scope

Rare, but possible:

```ruby
relation_scope do |relation|
  skip_default_relation_scope!
  relation
end
```

Before reaching for this, consider a separate portal without scoping.

## Entity strategies (portal configuration)

The portal declares how the current entity is resolved from the request.

### Path strategy

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

Routes become `/organizations/:organization_id/posts`. The portal extracts `params[:organization_id]` and loads the entity automatically.

### Custom strategy

```ruby
module AdminPortal
  class Engine < Rails::Engine
    include Plutonium::Portal::Engine

    config.after_initialize do
      scope_to_entity Organization, strategy: :current_organization
    end
  end
end

module AdminPortal
  module Concerns
    module Controller
      extend ActiveSupport::Concern
      include Plutonium::Portal::Controller

      private

      def current_organization
        @current_organization ||= Organization.find_by!(subdomain: request.subdomain)
      end
    end
  end
end
```

The strategy symbol must match a method name on the controller.

### Accessing the scoped entity

```ruby
current_scoped_entity  # => current Organization
scoped_to_entity?      # => true/false
```

Inside a policy, the same entity is available as `entity_scope`.

## Three model shapes

The `associated_with` resolver handles three common model shapes. Pick the lightest one that fits.

### Shape 1: Direct child (belongs_to the entity)

```ruby
class Organization < ResourceRecord
  has_many :projects
end

class Project < ResourceRecord
  belongs_to :organization
end

# Usage
Project.associated_with(org)
# => Project.where(organization: org)     # simple WHERE, most efficient
```

**When to use:** the model naturally has a direct foreign key to the entity. No extra work; auto-detected.

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
  belongs_to :organization

  # ← auto-detection already finds :organization via belongs_to
end

# Usage
Membership.associated_with(org)
# => Membership.where(organization: org)
```

**When to use:** a pure join table. The `belongs_to :organization` is sufficient.

If instead the join table is the scope target and you want to scope `Project` → `Membership` → `Organization`, add a `has_one :through`:

```ruby
class ProjectMember < ResourceRecord
  belongs_to :project
  belongs_to :user
  has_one :organization, through: :project  # ← enables auto-scoping
end
```

Now `ProjectMember.associated_with(org)` resolves via the `has_one :through` automatically.

### Shape 3: Grandchild (multiple hops via `has_one :through`)

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
  has_one :organization, through: :project   # ← critical line
end

# Deeper
class Comment < ResourceRecord
  belongs_to :task
  has_one :project, through: :task
  has_one :organization, through: :project   # ← enables auto-scoping
end

# Usage
Task.associated_with(org)
# => resolves via the :organization has_one :through

Comment.associated_with(org)
# => resolves via Comment -> Task -> Project -> Organization
```

**When to use:** the model is two+ hops away from the entity. Declaring `has_one :organization, through: ...` is the **lightest fix** — `associated_with` finds it via `reflect_on_all_associations` with no policy override needed.

### When to fall back to a custom scope

Use a custom `associated_with_<model_name>` scope when:

- The path is polymorphic.
- The path needs conditional logic.
- You want explicit SQL for performance (e.g. avoid a multi-join chain).

```ruby
class Comment < ResourceRecord
  scope :associated_with_organization, ->(org) do
    joins(task: :project).where(projects: {organization_id: org.id})
  end
end

# Plutonium picks this up BEFORE trying association detection.
```

## How the pieces fit together

1. An admin opens `/organizations/42/projects`.
2. Portal's `scope_to_entity Organization, strategy: :path` extracts `42`, loads the `Organization`, sets `current_scoped_entity`.
3. The controller calls the policy. The policy's inherited `relation_scope` calls `default_relation_scope(relation)`.
4. `default_relation_scope` has no parent (this is a top-level nested resource from the portal's perspective), so it calls `relation.associated_with(current_scoped_entity)`.
5. `Project.associated_with(org)` resolves via the direct `belongs_to :organization` → `Project.where(organization: org)`.
6. The controller renders only that organization's projects. Records from other orgs are invisible.

Any model that cannot be reached from the entity via these rules must declare a `has_one :through` or a custom scope. Policies must never work around this — work around it in the **model**.

## Gotchas

- **Policy tries to filter by entity directly.** Wrong — that bypasses `default_relation_scope`. Add the association path to the model instead.
- **`super` inside `relation_scope`.** Unreliable. Call `default_relation_scope(relation)` explicitly.
- **Multiple associations to the same entity class.** E.g. `Match belongs_to :home_team, :away_team` both pointing at `Team`. Plutonium raises — override `scoped_entity_association` on the controller to pick one.
- **`param_key` differs from association name.** Fine — Plutonium finds the association by **class**, not param key. You can still `scope_to_entity Competition::Team, param_key: :team` and have the model use `belongs_to :competition_team`.
- **Forgetting compound uniqueness.** A unique constraint on `:code` alone leaks uniqueness across tenants. Use `validates :code, uniqueness: {scope: :organization_id}`.
- **Skipping the scope "temporarily" for debugging.** Use `skip_default_relation_scope!` explicitly — never leave a `where` bypass in the code.

## Related skills

- `plutonium-model` — `associated_with` mechanics, declaring associations, `has_one :through` patterns.
- `plutonium-policy` — writing `relation_scope` safely, bulk authorization, attribute permissions.
- `plutonium-portal` — entity strategies (path, custom), `scope_to_entity`, mounting.
- `plutonium-invites` — how invites and memberships interact with entity scoping.
- `plutonium-nested-resources` — parent scoping semantics, which take precedence over entity scoping.
