# Nested Resources

Set up parent/child relationships so `/companies/:id/nested_properties` works automatically.

## Goal

`Company has_many :properties`, and you want:

- A "Properties" tab on the Company show page.
- A nested URL `/companies/123/nested_properties` for the company's properties.
- Forms that auto-fill the parent (no manual hidden field).
- Queries scoped to the parent (sibling companies' properties invisible).

All of this happens with no manual route wiring — Plutonium generates it from the association.

## Steps

### 1. Scaffold parent and child

```bash
rails g pu:res:scaffold Company name:string --dest=main_app
rails g pu:res:scaffold Property company:belongs_to name:string --dest=main_app
rails db:migrate
```

### 2. Connect both to the portal

```bash
rails g pu:res:conn Company Property --dest=admin_portal
```

Plutonium reads the `has_many :properties` association on `Company` and registers nested routes for `Property` automatically.

### 3. (Optional) Expose the relationship on the Company show page

```ruby
class CompanyPolicy < ResourcePolicy
  def permitted_associations
    %i[properties]
  end
end
```

This adds a "Properties" tab on the Company show page that loads the nested collection. See [Reference › Behavior › Policies › Association permissions](/reference/behavior/policies#association-permissions).

### 4. Visit the URL

```
/admin/companies/1/nested_properties
```

Properties index, scoped to Company #1. Forms hide the company field (already determined by URL).

## Generated routes

Plutonium prefixes nested routes with `nested_` so they don't conflict with top-level:

| Route | Purpose |
|---|---|
| `/companies/:company_id/nested_properties` | `has_many` index |
| `/companies/:company_id/nested_properties/new` | new |
| `/companies/:company_id/nested_properties/:id` | show |
| `/companies/:company_id/nested_company_profile` | `has_one` show (no `:id`) |
| `/companies/:company_id/nested_company_profile/new` | `has_one` new |

`has_one` associations get singular routes — index redirects to show (or new if no record exists).

## What Plutonium does automatically

1. **Resolves the parent** via `current_parent`, authorized for `:read?`.
2. **Scopes queries** via the parent association (`company.properties` for `has_many`; `where(company_id: ...)` for `has_one`).
3. **Assigns the parent** on create (injected into `resource_params`).
4. **Hides the parent field** in forms and displays.

No hidden fields. No manual scoping.

## URL generation

Use `resource_url_for` with the `parent:` option:

```ruby
resource_url_for(Property, parent: company)
# => /admin/companies/123/nested_properties

resource_url_for(property, parent: company)
# => /admin/companies/123/nested_properties/456

resource_url_for(Property, action: :new, parent: company)
resource_url_for(property, action: :edit, parent: company)

# Interactions compose with parent
resource_url_for(property, parent: company, interaction: :archive)
resource_url_for(Property, parent: company, interaction: :bulk_delete, ids: [1, 2])
```

## Common patterns

### Show parent on standalone listings

By default, the parent field is hidden in forms/displays (it's in the URL). To show it on the standalone (non-nested) listing:

```ruby
class PropertiesController < ::ResourceController
  private
  def present_parent? = current_parent.nil?
end
```

### Custom parent resolution (e.g. by slug)

```ruby
def current_parent
  @current_parent ||= Company.friendly.find(params[:company_id])
end
```

### Compound uniqueness within parent

```ruby
class Property < ResourceRecord
  belongs_to :company
  validates :code, uniqueness: {scope: :company_id}
end
```

Without the scope, the same code in different companies would collide.

### Custom routes on nested resources

```ruby
register_resource ::Property do
  member do
    get  :analytics, as: :analytics    # `as:` is REQUIRED
    post :archive,   as: :archive
  end
end
```

::: warning Always pass `as:`
Without `as:`, `resource_url_for(property, parent: company, action: :analytics)` fails — no named route to look up.
:::

## Policy authorization context

The child policy automatically receives the parent:

```ruby
class PropertyPolicy < ResourcePolicy
  # parent              => the Company instance
  # parent_association  => :properties

  def create?
    parent.present? && user.member_of?(parent)
  end
end
```

The parent is authorized for `:read?` before `current_parent` returns — children inherit the parent's access requirements.

## Parent scoping vs entity scoping

When a parent is present, **parent scoping wins**: `default_relation_scope` scopes via the parent association, NOT `entity_scope`. The parent was already entity-scoped during its own authorization — double-scoping isn't needed.

In the child policy, just call `default_relation_scope` — it handles both cases:

```ruby
relation_scope do |relation|
  default_relation_scope(relation)    # parent when present, entity_scope otherwise
end
```

See [Reference › Tenancy › Nested resources › Parent vs entity scoping](/reference/tenancy/nested-resources#parent-vs-entity-scoping).

## Nesting limitations

Plutonium supports **one level of nesting only**:

- ✅ `/companies/:company_id/nested_properties` (parent → child)
- ❌ `/companies/:company_id/nested_properties/:property_id/nested_units` (grandparent → parent → child)

For deeper hierarchies, use top-level routes plus association tabs on the show page (`permitted_associations`).

## Inline `+` add on the parent form

When a form has an association select (e.g. picking the company on a Property form), the inline `+` button next to the select opens the parent's `:new` action. If the parent form is already in a modal, the `+` opens a **stacked secondary modal** so the in-progress form isn't lost. See [Reference › UI › Forms › Association inputs](/reference/ui/forms#association-inputs).

## Common issues

- **Nested route doesn't exist** — both parent AND child must be registered in the same portal (`pu:res:conn`).
- **Parent shows up in the form anyway** — check `present_parent?` / `submit_parent?` on the controller. Default is to hide on nested routes.
- **Multiple `belongs_to` to the same parent class** (e.g. `Match belongs_to :home_team, :away_team`) — Plutonium raises. Override `scoped_entity_association` to specify. See [Reference › Tenancy › Entity scoping](/reference/tenancy/entity-scoping#multiple-associations-to-the-same-entity-class).
- **`resource_url_for` returns wrong URL for a nested resource** — check that custom routes use `as:`.

## Related

- [Reference › Tenancy › Nested resources](/reference/tenancy/nested-resources) — full surface
- [Reference › Behavior › Controllers](/reference/behavior/controllers) — `current_parent`, presentation hooks
- [Reference › Behavior › Policies](/reference/behavior/policies#association-permissions) — `permitted_associations`
- [Multi-tenancy](./multi-tenancy) — how entity scoping interacts with parent scoping
- [Adding resources](./adding-resources) — basic resource setup
