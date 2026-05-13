# Nested Resources

Plutonium auto-generates nested routes from `has_many` and `has_one` associations on a registered parent. No manual route wiring — `belongs_to` on the child plus `register_resource` for both is enough.

## 🚨 Critical

- **One level only.** Grandparent → parent → child nested routes are NOT supported. Use top-level routes for deeper relationships.
- **Parent scoping beats entity scoping.** When a parent is present, `default_relation_scope` scopes via the parent, NOT via `entity_scope`. Don't double-scope.
- **Named custom routes.** When adding member/collection routes on a nested resource, always pass `as:` — otherwise `resource_url_for` will fail.
- **The parent is authorized for `:read?`** before `current_parent` returns. The child policy receives the parent in its context.

## Setup

```bash
rails g pu:res:scaffold Company name:string --dest=main_app
rails g pu:res:scaffold Property company:belongs_to name:string --dest=main_app
rails g pu:res:conn Company Property --dest=admin_portal
```

Then register both in the portal:

```ruby
# packages/admin_portal/config/routes.rb
register_resource ::Company
register_resource ::Property        # has belongs_to :company
register_resource ::CompanyProfile  # has_one :company_profile on Company
```

## Generated routes

Plutonium prefixes nested routes with `nested_` so they don't conflict with the top-level routes:

| Route | Purpose |
|---|---|
| `/companies/:company_id/nested_properties` | `has_many` index |
| `/companies/:company_id/nested_properties/new` | new |
| `/companies/:company_id/nested_properties/:id` | show |
| `/companies/:company_id/nested_company_profile` | `has_one` show (no `:id`) |
| `/companies/:company_id/nested_company_profile/new` | `has_one` new |

For `has_one`:

- Routes are singular (no `:id` param).
- Index redirects to show (or new if no record exists).
- Only one record can exist per parent.
- Forms don't show the parent field (determined by URL).

## Automatic behavior on nested routes

When the controller is hit via a nested route, Plutonium automatically:

1. **Resolves the parent** via `current_parent`, authorized for `:read?`.
2. **Scopes queries** via the parent association:
   - `has_many` → `parent.send(parent_association)` (e.g. `company.properties`)
   - `has_one` → `relation.where(foreign_key => parent.id)` with limit
3. **Assigns the parent** on create (injected into `resource_params`).
4. **Hides the parent field** in forms and displays (already determined by URL).

You don't add hidden parent fields or filter queries manually.

## Controller methods

```ruby
current_parent              # parent record (e.g. Company instance)
current_nested_association  # association name (e.g. :properties)
parent_route_param          # URL param (e.g. :company_id)
parent_input_param          # form param / association name (e.g. :company)
```

## Parent vs entity scoping

When a parent is present, **parent scoping wins**: `default_relation_scope` scopes via the parent association, NOT `entity_scope`. The parent was already authorized and entity-scoped during its own authorization — double-scoping is redundant.

In the child's policy, just call `default_relation_scope` — it handles both cases:

```ruby
class PropertyPolicy < ResourcePolicy
  relation_scope do |relation|
    default_relation_scope(relation)    # parent when present, entity_scope otherwise
  end
end
```

For composite filtering on top of the default:

```ruby
relation_scope do |relation|
  default_relation_scope(relation).where(archived: false)
end
```

## URL generation

`resource_url_for(...)` with the `parent:` option:

```ruby
# Child collection (has_many)
resource_url_for(Property, parent: company)
# => /companies/123/nested_properties

# Child record
resource_url_for(property, parent: company)
# => /companies/123/nested_properties/456

# New child
resource_url_for(Property, action: :new, parent: company)
# => /companies/123/nested_properties/new

# Edit child
resource_url_for(property, action: :edit, parent: company)
# => /companies/123/nested_properties/456/edit

# Singular (has_one)
resource_url_for(company_profile, parent: company)
# => /companies/123/nested_company_profile

resource_url_for(CompanyProfile, action: :new, parent: company)
# => /companies/123/nested_company_profile/new

# Interactions compose with parent
resource_url_for(property, parent: company, interaction: :archive)
resource_url_for(Property, parent: company, interaction: :import)
resource_url_for(Property, parent: company, interaction: :bulk_delete, ids: [1, 2])
```

### Cross-package URLs

```ruby
# From AdminPortal, generate URL to a CustomerPortal resource
resource_url_for(property, parent: company, package: CustomerPortal)
```

## Authorization context

The child policy receives the parent automatically:

```ruby
class PropertyPolicy < ResourcePolicy
  # parent              => the Company instance
  # parent_association  => :properties

  def create?
    parent.present? && user.member_of?(parent)
  end

  def read?
    parent.present? && record.company == parent
  end
end
```

The parent is authorized for `:read?` before `current_parent` returns — children inherit the parent's access requirements.

## Parameter handling

The parent is injected into `resource_params` automatically:

```ruby
# When creating a property under /companies/123/nested_properties
resource_params
# => { name: "...", company: <Company:123>, company_id: 123 }
```

No hidden parent fields needed in forms.

## Presentation hooks

Control whether the parent field appears in views/forms:

```ruby
class PropertiesController < ::ResourceController
  private

  def present_parent?  = true     # show on displays (default: false)
  def submit_parent?   = false    # include in forms (defaults to present_parent?)
end
```

Conditional — show parent only when accessed standalone:

```ruby
def present_parent?
  current_parent.nil?
end
```

## Custom parent resolution

Override `current_parent` for non-default lookup:

```ruby
class PropertiesController < ::ResourceController
  private

  def current_parent
    @current_parent ||= Company.friendly.find(params[:company_id])
  end
end
```

## Custom routes on nested resources

```ruby
register_resource ::Property do
  member do
    get  :analytics, as: :analytics
    post :archive,   as: :archive
  end
  collection do
    get  :report,    as: :report
  end
end
```

Generates `/companies/:company_id/nested_properties/:id/analytics`, etc.

::: warning Always pass `as:`
Without `as:`, `resource_url_for(property, parent: company, action: :analytics)` fails — there's no named route to look up.
:::

## Compound uniqueness

Scope uniqueness to the parent FK:

```ruby
class Property < ResourceRecord
  belongs_to :company
  validates :code, uniqueness: {scope: :company_id}
end
```

Without the scope, the same code in different companies would collide.

## Custom association scope (for complex relationships)

When the parent path isn't a direct `belongs_to`, define a custom scope on the child:

```ruby
class Property < ResourceRecord
  scope :associated_with_organization, ->(org) {
    joins(:company).where(companies: {organization_id: org.id})
  }
end
```

Useful when the child is nested under a grandparent-style entity. See [Entity scoping › Three model shapes](./entity-scoping#three-model-shapes).

## Breadcrumbs

Auto-include the parent: `Companies > Acme Corp > Properties > Property #123`.

## Nesting limitations

Plutonium supports **one level of nesting**:

- ✅ `/companies/:company_id/nested_properties` (parent → child)
- ❌ `/companies/:company_id/nested_properties/:property_id/nested_units` (grandparent → parent → child)

For deeper hierarchies, use top-level routes plus association tabs on the show page (see [Behavior › Policy › Association permissions](/reference/behavior/policies#association-permissions) and [Resource › Definition › Custom page classes](/reference/resource/definition#custom-page-classes)).

## Related

- [Entity scoping](./entity-scoping) — what happens when no parent is present
- [Invites](./invites) — membership-based onboarding
- [Behavior › Policy](/reference/behavior/policies) — `relation_scope`, parent context
- [Behavior › Controllers](/reference/behavior/controllers) — `current_parent`, presentation hooks
- [App › Portals](/reference/app/portals) — `register_resource` and custom member/collection routes
