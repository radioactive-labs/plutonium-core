# Testing

Plutonium ships `Plutonium::Testing` — opt-in Minitest concerns that give your app default test coverage for resources, policies, definitions, interactions, models, nested scoping, portal access, and authentication.

## Quick start

```bash
# Once per app
rails g pu:test:install

# Per resource × portal pairing
rails g pu:test:scaffold Blogging::Post --portals=admin,org

# Run
bin/rails test
```

`pu:test:install` adds `require "plutonium/testing"` to `test/test_helper.rb` and creates `test/support/plutonium_testing.rb` (a stub for non-Rodauth auth overrides).

`pu:test:scaffold` produces one test file per (resource × portal) pairing with concerns pre-included and stub method bodies pre-filled with `TODO` markers.

## Anatomy of a test file

```ruby
# test/integration/admin_portal/blogging_post_test.rb
require "test_helper"

class AdminPortal::BloggingPostTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::ResourceCrud
  include Plutonium::Testing::ResourcePolicy
  include Plutonium::Testing::ResourceDefinition

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    login_as(@admin)
  end

  # --- ResourceCrud stubs ---
  def create_resource!; create_post!(user: @user, organization: @org); end
  def valid_create_params
    {title: "x", body: "y", status: :draft,
     user: @user.to_sgid.to_s, organization: @org.to_sgid.to_s}
  end
  def valid_update_params; {title: "Updated"}; end

  # --- ResourcePolicy stubs ---
  def policy_roles; {admin: -> { @admin }}; end
  def policy_record; create_post!(user: @user, organization: @org); end
  def policy_matrix
    {index: %i[admin], show: %i[admin], create: %i[admin],
     update: %i[admin], destroy: %i[admin]}
  end
end
```

Running this produces 15+ test cases: 7 CRUD + 2 policy + 3 definition + any `skip:` exclusions.

## The DSL

Every concern uses the same class-level method:

```ruby
resource_tests_for ResourceClass,
  portal:           :admin,                                # required
  path_prefix:      "/admin",                              # optional override
  parent:           :organization,                         # for nested resources
  actions:          %i[index show new create edit update destroy],
  skip:             %i[destroy],
  associated_with:  :organization,                         # ResourceModel only
  sgid_routing:     true,                                  # ResourceModel only
  has_cents:        %i[price]                              # ResourceModel only
```

The **portal symbol** drives path prefix, default auth strategy, and scoping expectations. The resolver walks `Rails.application.routes.routes` for the engine mount — no manual configuration.

## Concerns

| Concern | What it generates | Stubs required |
|---|---|---|
| `ResourceCrud` | index/show/new/create/edit/update/destroy | `create_resource!`, `valid_create_params`, `valid_update_params` |
| `ResourcePolicy` | permit? × role × action matrix + relation_scope smoke | `policy_roles`, `policy_record`, `policy_matrix` |
| `ResourceDefinition` | definition class + defineable prop smoke | none |
| `ResourceInteraction` | `assert_interaction_success/failure` helpers | `interaction_class`, `valid_interaction_input` |
| `ResourceModel` | `associated_with`, SGID, `has_cents` | `model_test_record` |
| `NestedResource` | nested CRUD + sibling-tenant boundaries | `parent_record!`, `other_parent_record!`, `create_resource!(parent:)` |
| `PortalAccess` | cross-portal access matrix | `login_as_role`, `portal_root_path` |

Mix and match — `include` only what you want.

## Auth helpers

```ruby
login_as(account)                    # uses portal from DSL
login_as(account, portal: :admin)    # explicit override
sign_out                              # uses portal from DSL
current_account                       # uses portal from DSL
with_portal(:org) { ... }            # scoped portal switch
```

### Non-Rodauth auth

Define `sign_in_for_tests(account, portal:)` in your test class (or in `test/support/plutonium_testing.rb` for project-wide use):

```ruby
def sign_in_for_tests(account, portal:)
  # your custom auth flow here
  post "/your-login", params: {token: account.auth_token}
end
```

`AuthHelpers` detects it and defers automatically.

## Generators

### `pu:test:install`

Idempotent. Adds the require line and creates the override stub.

### `pu:test:scaffold`

| Flag | Default | Purpose |
|---|---|---|
| `--portals=admin,org` | required | Emit one file per portal |
| `--concerns=...` | `crud,policy,definition` | Subset of concerns to include |
| `--parent=organization` | none | Wires `NestedResource` parent |
| `--dest=main_app\|<package>` | `main_app` | Output destination |

Output: `test/integration/<portal>_portal/<resource>_test.rb`.

## Customization

- **Skip individual tests:** `resource_tests_for Klass, portal: :admin, skip: %i[destroy]`
- **Restrict action set:** `resource_tests_for Klass, portal: :admin, actions: %i[index show]`
- **Add custom tests:** regular `test "..."` blocks coexist with the generated matrix.
- **Custom path prefix:** `path_prefix: "/v2/admin"` overrides portal resolution.

## Common pitfalls

- **Forgotten stubs raise `NotImplementedError`** with the stub name — look for the missing method.
- **Portal mismatch:** `:admin` expects `AdminPortal::Engine`. Pass `path_prefix:` if your engine is named differently.
- **Tenant leakage in stubs:** for an org portal, `create_resource!` must return a record bound to the test's `@org`.
- **`policy_record` for tenant-scoped resources** must belong to a tenant the role can access — otherwise even allowed roles see `false`.
- **Nested resources need `parent:` in the DSL AND a parent record** from `parent_record!`. Both are required for path interpolation.
- **`PortalAccess` uses `portal_access_for`**, not `resource_tests_for`. Don't mix them on the same class.

## See also

- [Authorization](/guides/authorization) — write the policy this concern verifies
- [Multi-tenancy](/guides/multi-tenancy) — entity scoping that drives nested-resource tests
- [Authentication](/guides/authentication) — Rodauth setup behind the default login flow
