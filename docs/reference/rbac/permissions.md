# RBAC Permissions

::: warning Experimental
RBAC is experimental. The permission key format may change in a future release.
:::

## Key format

A permission key is `<resource>.<action>`. The resource segment is the model's `model_name.i18n_key`, so namespaced models keep their slash:

| Model | Key prefix |
|-------|-----------|
| `Hr::Employee` | `hr/employee` |
| `Blogging::Post` | `blogging/post` |
| `Plutonium::Rbac::Role` | `rbac_role` |

Restricted fields add a segment: `hr/employee.salary.read`.

## The catalog

`Plutonium::Rbac::Catalog` is every grantable key, built from your code at first use (and rebuilt after a development reload). The role grid, role validation and sync all read it.

| Source | Keys added |
|--------|-----------|
| Each resource governed by at least one policy that includes `Plutonium::Rbac::Policy` | `read`, `create`, `update`, `destroy`, `export` |
| Each action declared on any of that resource's definitions (base or portal) that is not a Plutonium built-in | `<action>` |
| Each field named by `rbac_restricted_attributes` on its RBAC policies | `<field>.read`, `<field>.write` |
| `Plutonium::Rbac.permission` | the declared key |

A resource whose policies do not include the mixin gets no keys, because nothing would read them. A role that names such a key fails validation with "contains an unknown permission".

```bash
rails runner 'puts Plutonium::Rbac::Catalog.keys.sort'
```

For the dummy app's `Hr::Employee` (a `promote` action, a restricted `salary`) plus the role resource:

```
hr/employee.create
hr/employee.destroy
hr/employee.export
hr/employee.promote
hr/employee.read
hr/employee.salary.read
hr/employee.salary.write
hr/employee.update
rbac_role.create
rbac_role.destroy
rbac_role.export
rbac_role.read
rbac_role.update
```

### Wildcards

| Granted key | Grants |
|-------------|--------|
| `hr/employee.*` | every key starting with `hr/employee.`, field keys included |
| `*` | every key |

Only [system roles](/reference/rbac/roles#system-roles) may hold wildcards. A tenant or custom role must list concrete catalog keys.

## Default predicates

Include the mixin in a policy (the installer adds it to `ResourcePolicy`, or to the class named by `--policy`):

```ruby
class ResourcePolicy < Plutonium::Resource::Policy
  include Plutonium::Rbac::Policy
end
```

| Predicate | Without RBAC | With RBAC |
|---|---|---|
| `read?` | `false` | `granted?(:read)` |
| `create?` | `false` | `granted?(:create)` |
| `update?` | delegates to `create?` | `granted?(:update)` |
| `destroy?` | delegates to `create?` | `granted?(:destroy)` |
| `export_csv?` | `false` | `granted?(:export)` |
| `index?`, `show?` | delegate to `read?` | unchanged |
| `new?` | delegates to `create?` | unchanged |
| `edit?`, `kanban_move?`, `reposition?` | delegate to `update?` | unchanged |
| `search?`, `typeahead?` | delegate to `index?` | unchanged |

A method defined in the policy class or a subclass wins over the mixin. A `def create? = true` left in a policy keeps creation open to everyone and RBAC never runs for it. `pu:rbac:install` removes the always-`true` `create?`/`read?` pair from the `--policy` file and warns about any other `create?`/`read?` body it finds there; predicates in subclasses are yours to delete.

### `granted?`

Public on every RBAC policy.

| Argument | Checks |
|----------|--------|
| A symbol, `granted?(:update)` | `<this policy's resource>.update` |
| A string, `granted?("reports.view")` | that full key |

The current holder comes from [`rbac_holder`](/reference/rbac/#the-holder-resolver). With no holder, `granted?` is `false`.

## Custom actions

Every action a definition declares gets a predicate with no method:

```ruby
class Hr::EmployeeDefinition < Hr::ResourceDefinition
  action :promote, interaction: Hr::PromoteEmployee
end
```

`Hr::EmployeePolicy#promote?` returns `granted?(:promote)`, which checks `hr/employee.promote`. A predicate for an action no definition declares raises `NoMethodError`.

To add record state, define the method and call `super`:

```ruby
class Blogging::PostPolicy < Blogging::ResourcePolicy
  def publish? = super && record.draft?
end
```

The action now needs both `blogging/post.publish` and a draft record. `def publish? = update? && record.draft?` gates the action on `.update` instead, and the `publish` key stops doing anything.

## Restricted fields

```ruby
class Hr::EmployeePolicy < Hr::ResourcePolicy
  rbac_restricted_attributes :salary

  def permitted_attributes_for_create
    [:organization, :name, :salary]
  end

  def permitted_attributes_for_read
    [:organization, :name, :salary]
  end
end
```

| Side | Methods filtered | Key required |
|------|------------------|--------------|
| Read | `permitted_attributes_for_read`, `_index`, `_show`, `_export` | `hr/employee.salary.read` |
| Write | `permitted_attributes_for_create`, `_update`, `_new`, `_edit` | `hr/employee.salary.write` |

Keep listing the field in `permitted_attributes_for_*`; the macro only removes it. The filter wraps subclass overrides too, so a portal policy that redefines `permitted_attributes_for_index` is still filtered. `rbac_restricted_attributes` can be called more than once; names accumulate.

Sorts, filters and search declared on a restricted field are not filtered. A holder without `.read` can still order or narrow records by the hidden value, so do not declare them on restricted fields.

## Declared permissions

For a permission that is not one resource action, declare it in `config/initializers/rbac.rb`:

```ruby
Plutonium::Rbac.permission "reports.view", label: "View reports"
```

| Option | Default |
|--------|---------|
| `label:` | the key, humanized |
| `group:` | the first segment, humanized (`"Reports"`) |

The group is the heading it appears under in the role grid. Check it with the full key:

```ruby
def view_reports? = granted?("reports.view")
```

## Related

- [Roles](/reference/rbac/roles): where keys are stored and assigned
- [Behavior › Policies](/reference/behavior/policies): the policy base class
- [Resource › Actions](/reference/resource/actions): declaring the actions that become keys
