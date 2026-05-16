# Authorization

Control what users can do once authenticated. Plutonium uses ActionPolicy with extensions for attribute permissions and tenant scoping.

## Goal

For each resource, decide who can create / read / update / destroy / run custom actions, and which fields they can see and edit.

## The three layers

Every policy controls three things:

1. **Action permissions** — `create?`, `read?`, `update?`, `destroy?`, plus your custom action methods.
2. **Attribute permissions** — `permitted_attributes_for_create`, `_for_read`, etc.
3. **Collection scope** — `relation_scope` (which records show up in lists).

## 🚨 Critical

- **`create?` and `read?` default to `false`.** Always override them explicitly. Derived methods (`update?`, `show?`, `index?`) inherit automatically.
- **`permitted_attributes_for_*` must be explicit in production.** Dev auto-detects; production raises.
- **`relation_scope` must end up calling `default_relation_scope(relation)` somewhere in the chain.** Prefer calling it explicitly in your override. `super` is fine when extending a parent policy (e.g., a package-level base) that itself calls `default_relation_scope`. See [Reference › Behavior › Policies](/reference/behavior/policies).
- **Custom action ⇒ policy method.** `action :publish` needs `def publish?` on the policy. Undefined methods return `false` → action silently disappears.

## Steps

### 1. Open the generated policy

After `pu:res:scaffold` + `pu:res:conn`, you have:

- `app/policies/post_policy.rb` (base policy)
- `packages/admin_portal/app/policies/admin_portal/post_policy.rb` (per-portal override, seeded by `pu:res:conn`)

### 2. Override `create?` and `read?` explicitly

```ruby
class PostPolicy < ResourcePolicy
  def create? = user.present?
  def read?   = true
end
```

These default to `false` — without an explicit override, nobody can create or read records.

### 3. Override derived methods only when rules differ

`update?` inherits from `create?`. `index?`/`show?` inherit from `read?`. Only override when the rule is genuinely different:

```ruby
def update?
  user.admin? || record.author == user
end

def destroy?
  user.admin?
end
```

### 4. Declare attribute permissions

```ruby
def permitted_attributes_for_create
  %i[title content category]
end

def permitted_attributes_for_read
  %i[title content category author published_at created_at]
end
```

::: warning Index has no `record`
`permitted_attributes_for_index` runs at collection level — `record` is `nil`. If you write a `record`-dependent `_for_read`, you MUST also declare an explicit `_for_index`. See [Reference › Behavior › Policies › Index has no record](/reference/behavior/policies#index-has-no-record).
:::

### 5. Custom action methods

```ruby
def publish?
  update? && record.draft?
end

def archive?
  user.admin?
end
```

The method name matches the action name plus `?`. Undefined methods return `false`.

### 6. Optionally filter the collection — `relation_scope`

```ruby
relation_scope do |relation|
  default_relation_scope(relation).where(published: true)
end
```

🚨 `default_relation_scope(relation)` must be called somewhere in the chain — otherwise `verify_default_relation_scope_applied!` raises at runtime. Calling it explicitly here is safest. `super` works only when the parent policy also calls it.

## Common patterns

### Owner-based

```ruby
def update?  = record.author == user || user.admin?
def destroy? = update?
```

### Role-based

```ruby
def create? = user.admin? || user.editor?

def update?
  return true if user.admin?
  user.editor? && record.author == user
end
```

### Block archived records

```ruby
def update?  = !record.try(:archived?) && super
def destroy? = !record.try(:archived?) && super
```

### Conditional attribute access

```ruby
def permitted_attributes_for_create
  attrs = %i[title content]
  attrs += %i[featured author_id] if user.admin?
  attrs
end
```

### Time-based

```ruby
def update?
  return false if record.created_at < 24.hours.ago
  owner?
end
```

## Bulk action authorization — per record

```ruby
def bulk_archive?
  create? && !record.locked?   # checked PER record in the selection
end
```

- **Backend:** if any selected record fails, the entire request is rejected.
- **UI:** only actions ALL selected records support are shown (intersection).

Records come from `current_authorized_scope` — users can only select records they can access.

## Portal-specific policies

```ruby
class PostPolicy < ResourcePolicy
  def create? = user.present?
end

# Admin — more permissive
class AdminPortal::PostPolicy < ::PostPolicy
  include AdminPortal::ResourcePolicy

  def destroy? = true
  def permitted_attributes_for_create = %i[title content featured internal_notes]
end

# Public — read-only
class PublicPortal::PostPolicy < ::PostPolicy
  include PublicPortal::ResourcePolicy
  def create? = false
end
```

## Show-page association tabs

```ruby
def permitted_associations
  %i[comments tags author]
end
```

Drives the show-page tablist. Each named association must exist on the model AND be a registered Plutonium resource. See [Reference › Behavior › Policies › Association permissions](/reference/behavior/policies#association-permissions).

::: warning Not for nested forms
`permitted_associations` is for show-page navigation tabs, NOT nested forms. Nested forms come from `nested_input :variants` in the definition. See [Reference › Resource › Definition › Nested inputs](/reference/resource/definition#nested-inputs).
:::

## Multi-tenant scoping

When the portal sets `scope_to_entity Organization`, the inherited `relation_scope` automatically filters everything to the current org — no work in the policy. To add filters on top:

```ruby
relation_scope do |relation|
  default_relation_scope(relation).where(archived: false)
end
```

See [Multi-tenancy](./multi-tenancy) and [Reference › Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

## Anti-pattern: nested-attributes hashes in policies

```ruby
# ❌ NEVER
def permitted_attributes_for_create
  [:name, {variants_attributes: [:id, :name, :_destroy]}]
end
```

Nested params are extracted by the form definition, not the policy. The hash entry renders as a literal text input. Use just the association name:

```ruby
# ✅ Policy permits just the association name
def permitted_attributes_for_create
  [:name, :variants]
end
```

`nested_input :variants` in the definition handles the rest. See [Reference › Resource › Definition › Nested inputs](/reference/resource/definition#nested-inputs).

## Custom authorization context

```ruby
# Policy
class PostPolicy < ResourcePolicy
  authorize :department, allow_nil: true
  def create? = department&.allows_posting?
end

# Controller
class PostsController < ResourceController
  authorize :department, through: :current_department
  private
  def current_department = current_user.department
end
```

## Common issues

- **Undefined custom action policy method** — the button silently disappears (undefined returns `false`). Add `def my_action?` to the policy.
- **`record.X` crashes during index** — `record` is `nil` on index. Add an explicit `permitted_attributes_for_index` that doesn't depend on `record`.
- **`verify_default_relation_scope_applied!` raises** — your custom `relation_scope` doesn't call `default_relation_scope(relation)`. Fix by composing: `default_relation_scope(relation).where(...)`.
- **`super` in `relation_scope`** — works when you're extending a parent policy that itself calls `default_relation_scope`. If you're not sure (or you're inheriting from `Plutonium::Resource::Policy` directly), call `default_relation_scope(relation)` explicitly. The runtime check verifies `default_relation_scope` was hit somewhere — not that you wrote it in this class.

## Related

- [Reference › Behavior › Policies](/reference/behavior/policies) — full policy surface
- [Reference › Tenancy › Entity scoping](/reference/tenancy/entity-scoping) — `default_relation_scope`, multi-tenant patterns
- [Authentication](./authentication) — who's the user in the first place
- [Multi-tenancy](./multi-tenancy) — entity scoping setup
- [Custom actions](./custom-actions) — defining the actions that need policy methods
