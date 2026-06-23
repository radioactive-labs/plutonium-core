# Policy

Authorization for resources. Built on [ActionPolicy](https://actionpolicy.evilmartians.io/). Plutonium adds:

- Attribute permissions (`permitted_attributes_for_*`)
- Association permissions (`permitted_associations`)
- Automatic entity scoping via `default_relation_scope`
- Derived action methods (`update?` inherits from `create?`, etc.)

## 🚨 Critical

- **`create?` and `read?` default to `false`.** You MUST override them explicitly. Everything else (`update?`, `destroy?`, `index?`, `show?`, …) derives from one of those.
- **`permitted_attributes_for_*` must be explicit in production.** Dev auto-detects; production raises.
- **`relation_scope` must end up calling `default_relation_scope(relation)` somewhere in the chain.** Prefer calling it explicitly in your override. `super` is fine when extending a parent policy (e.g., a package base) that itself calls it. The runtime check verifies it was hit somewhere — not in this specific class.
- **For `has_cents` fields, use the virtual name** (`:price`), NEVER `:price_cents`.
- **Don't put `*_attributes` hashes in `permitted_attributes_for_*`.** Nested forms are extracted from the form definition, not the policy. List the association name (`:variants`) and the `nested_input` in the definition handles the rest.
- **Custom action ⇒ policy method.** `action :publish` needs `def publish?`. Undefined methods return `false` → action silently disappears.
- **Index has no `record`.** Record-dependent `_for_read` overrides need an explicit `_for_index` too (see [below](#index-has-no-record)).

## Base class

```ruby
# app/policies/resource_policy.rb — installed once
class ResourcePolicy < Plutonium::Resource::Policy
end

# app/policies/post_policy.rb — per resource, generated
class PostPolicy < ResourcePolicy
  def create? = user.present?
  def read?   = true

  def permitted_attributes_for_create
    %i[title content]
  end

  def permitted_attributes_for_read
    %i[title content author created_at]
  end
end
```

## Authorization context

Inside a policy:

| Variable | Description |
|---|---|
| `user` | Current authenticated user (required) |
| `record` | Resource being authorized |
| `entity_scope` | Current scoped entity (multi-tenancy) |
| `parent` | Parent record for nested resources (nil otherwise) |
| `parent_association` | Association name on parent (e.g. `:comments`) |

## Action permissions

### Must override

```ruby
def create?  # default: false
  user.present?
end

def read?    # default: false
  true
end
```

### Derived (inherit automatically)

| Method | Inherits from | Override when |
|---|---|---|
| `update?` | `create?` | Different update rules |
| `destroy?` | `create?` | Different delete rules |
| `index?` | `read?` | Custom listing rules |
| `show?` | `read?` | Record-specific read rules |
| `new?` | `create?` | Rarely needed |
| `edit?` | `update?` | Rarely needed |
| `search?` | `index?` | Search-specific rules |
| `typeahead?` | `index?` | Autocomplete on inputs/filters targeting this resource |

### Custom actions

Define `def <action>?` matching the definition's `action :<action>`. Undefined methods return `false`:

```ruby
def publish? = update? && record.draft?
def archive? = create? && !record.archived?
def invite_user? = user.admin?
```

### Bulk actions — per-record authorization

```ruby
def bulk_archive?
  create? && !record.locked?    # checked per record in the selection
end
```

How it works:

- Policy is checked **per record** in the selected set.
- **Backend:** if any record fails, the entire request is rejected.
- **UI:** only actions ALL selected records support are shown (intersection).
- Records come from `current_authorized_scope` — users can only select records they're allowed to access.

## Attribute permissions

```ruby
# Must override for production
def permitted_attributes_for_read
  %i[title content author published_at created_at]
end

def permitted_attributes_for_create
  %i[title content]
end
```

### Derived

| Method | Inherits from |
|---|---|
| `permitted_attributes_for_update` | `permitted_attributes_for_create` |
| `permitted_attributes_for_index` | `permitted_attributes_for_read` |
| `permitted_attributes_for_show` | `permitted_attributes_for_read` |
| `permitted_attributes_for_new` | `permitted_attributes_for_create` |
| `permitted_attributes_for_edit` | `permitted_attributes_for_update` |

### Per-action override

```ruby
def permitted_attributes_for_index
  %i[title author created_at]              # minimal for the table
end

def permitted_attributes_for_read
  %i[title content author tags created_at] # fuller for the show page
end
```

### Index has no `record`

🚨 `permitted_attributes_for_index` is evaluated at the **collection level** — `record` is `nil`. `permitted_attributes_for_show` (and `_for_read`) ARE evaluated per record.

If you write a record-dependent `_for_read`:

```ruby
def permitted_attributes_for_read
  attrs = %i[title content]
  attrs << :archive_reason if record.archived?   # uses record
  attrs
end
```

…you MUST also define an explicit `permitted_attributes_for_index` — otherwise inheritance kicks in, runs the `_for_read` body during the table render, and `record.archived?` blows up on `NoMethodError: undefined method 'archived?' for nil`.

```ruby
def permitted_attributes_for_index
  %i[title content]                          # no record-dependent fields
end
```

Same rule for `permitted_attributes_for_create` vs `_for_new` (new has no persisted record).

### Conditional attribute access

```ruby
def permitted_attributes_for_create
  attrs = %i[title content]
  attrs += %i[featured author_id] if user.admin?
  attrs
end

def permitted_attributes_for_update
  case record.status
  when 'draft'     then %i[title content category_id]
  when 'published' then %i[content]    # only the body once published
  else                  []
  end
end
```

### Definition declares HOW, policy declares WHAT

`permitted_attributes_for_*` controls **which fields appear** on a view. The definition's `field`/`input`/`display`/`column` declarations only control **how** they render. A `field :name` in the definition does nothing unless `:name` is also in the relevant `permitted_attributes_for_*`.

Common mistake: adding a definition declaration and wondering why the field doesn't show — check the policy.

### Anti-pattern: nested-attributes hashes

```ruby
# ❌ NEVER
def permitted_attributes_for_create
  [
    :name,
    {variants_attributes: [:id, :name, :_destroy]},
    {comments_attributes: [:id, :body, :_destroy]}
  ]
end
```

Plutonium extracts nested params via the form definition, not the policy. Hash entries here get iterated as field names by the form renderer and render as literal text inputs with names like `model[{:variants_attributes=>[...]}]`.

```ruby
# ✅ Policy permits just the association name
def permitted_attributes_for_create
  [:name, :variants]
end
```

`nested_input :variants` in the definition handles the rest. See [Resource › Definition › Nested inputs](/reference/resource/definition#nested-inputs).

### Auto-detection (dev only)

In development, undefined `permitted_attributes_for_*` methods auto-detect from the model. **Production raises** with a clear error:

```
🚨 Resource field auto-detection: PostPolicy#permitted_attributes_for_create
Auto-detected resource fields result in security holes and will fail outside of development.
```

Always declare explicitly before deploying.

## Association permissions

```ruby
def permitted_associations
  %i[comments tags author]
end
```

Declares which associations get their own **tab on the show page**. When non-empty, the show page renders a tablist: a "Details" tab (the main field card + metadata aside) plus one tab per association — each lazy-loaded via a frame navigator panel pointing at the associated `has_many` collection, `has_one` record, or `belongs_to` target. When empty, the show page renders without tabs. If `permitted_attributes_for_show` resolves to **no fields**, the empty Details tab is omitted and the first association tab leads instead.

Each named association must:

- Exist on the model (raises `ArgumentError: unknown association ...` otherwise).
- Point to a class that's itself a registered Plutonium resource (raises `... is not a registered resource` otherwise).

This is **NOT** the same as:

- **Nested forms** — declared with `nested_input :variants` in the definition, requires `accepts_nested_attributes_for` on the model. See [Resource › Definition › Nested inputs](/reference/resource/definition#nested-inputs).
- **Association fields on tables / show details** — controlled by `permitted_attributes_for_index` / `_for_show` listing the association name.

## Collection scoping (`relation_scope`)

Filter which records the user can see.

### Always compose with `default_relation_scope`

🚨 `relation_scope` MUST end up calling `default_relation_scope(relation)` somewhere in the chain. `super` works — `Plutonium::Resource::Policy` defines a default scope block that calls `default_relation_scope`, so a subclass that does `super(relation).where(...)` is fine. Calling `default_relation_scope` explicitly is also fine (and required when you skip the parent chain). Plutonium enforces this at runtime via `verify_default_relation_scope_applied!`.

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

### Wrong patterns

```ruby
# ❌ Manually filtering by entity — bypasses default_relation_scope
relation_scope { |r| r.where(organization: current_scoped_entity) }

# ❌ Manual joins — same problem
relation_scope { |r| r.joins(:project).where(projects: {organization_id: current_scoped_entity.id}) }

# ❌ Missing default_relation_scope entirely — raises at runtime
relation_scope { |r| r.where(published: true) }
```

### What `default_relation_scope` does

1. If a **parent** is present (nested resource), scopes via the parent association.
2. Otherwise, applies `relation.associated_with(entity_scope)` for multi-tenancy.

Parent scoping takes precedence over entity scoping — the parent was already authorized and entity-scoped during its own authorization, so double-scoping isn't needed.

Full mechanics in [Tenancy › Entity scoping](/reference/tenancy/entity-scoping).

### Intentionally skipping

Rare. Use `skip_default_relation_scope!` explicitly — never silently bypass:

```ruby
relation_scope do |relation|
  skip_default_relation_scope!
  relation
end
```

Before reaching for this, consider a separate, unscoped portal.

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

## Authorization errors

```ruby
# Failed authorization raises ActionPolicy::Unauthorized

# Handle globally
rescue_from ActionPolicy::Unauthorized do
  redirect_to root_path, alert: "Not authorized"
end
```

## Common patterns

### Block archived records

```ruby
def update?  = !record.try(:archived?) && super
def destroy? = !record.try(:archived?) && super
```

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

### Status-based

```ruby
def update?
  return false if record.archived?
  owner? || admin?
end
```

### Time-based

```ruby
def update?
  return false if record.created_at < 24.hours.ago
  owner?
end
```

## Debugging

```ruby
# Console
user = User.find(1)
post = Post.find(1)

policy = PostPolicy.new(post, user: user)
policy.update?
policy.permitted_attributes_for_update
```

## Related

- [Controllers](./controllers) — call policies via `authorize_current!` and `authorized_resource_scope`
- [Interactions](./interactions) — custom actions whose policy methods you define
- [Resource › Actions](/reference/resource/actions) — registering actions that need policy methods
- [Tenancy › Entity scoping](/reference/tenancy/entity-scoping) — `default_relation_scope`, three model shapes, custom scopes
- [ActionPolicy docs](https://actionpolicy.evilmartians.io/) — the underlying library
