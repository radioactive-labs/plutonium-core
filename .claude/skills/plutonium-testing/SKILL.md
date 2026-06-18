---
name: plutonium-testing
description: Use BEFORE writing tests for a Plutonium resource, running pu:test:scaffold, or including Plutonium::Testing::* concerns. Covers the full testing toolkit — CRUD, policy, definition, interaction, model, nested, portal access, and auth helpers.
---

# Plutonium Testing

## 🚨 Critical (read first)

- **Use the generators.** `pu:test:install` once per app, then `pu:test:scaffold ResourceClass --portals=...` per resource × portal. Hand-written test files drift from conventions.
- **Tests are opt-in.** `Plutonium::Testing` is only loaded when `require "plutonium/testing"` runs — it's never autoloaded, never present in production.
- **One file per (resource × portal).** Same model in admin and org portals = two test files. Each portal has different auth, scoping, and allowed actions.
- **Stub methods are required.** Concerns ship with `NotImplementedError` stubs — your test class supplies the test data via `create_resource!`, `valid_create_params`, `policy_roles`, etc.

---

## 🛑 Before you scaffold tests: confirm the shape (ASK — don't infer)

"Write tests for X" leaves out what actually drives the files. Resolve each — confirming by inspection (next section):

1. **Which concerns?** `crud` / `policy` / `definition` / `model` / `nested` / `interaction` / `portal_access`. Don't scaffold all blindly — pick what the resource needs.
2. **Which portals?** **One file per (resource × portal)** — each has different auth, scoping, and allowed actions. A resource in admin + org ⇒ two files.
3. **Nested?** A child resource needs `--parent=` **and** a real `parent_record!` stub.
4. **Auth flavor.** Rodauth (the default `login_as` POSTs the hardcoded `password123`) or custom (override `sign_in_for_tests`)?

**Never ship a guessed policy matrix, factory name, or field list** — read the model/definition/policy for the real actions, roles, and fields before filling stubs.

## ✅ Before you scaffold: verify the ground truth (CHECK — read it, don't ask for it)

You have file access — **inspect**; don't ask the user to describe their setup.

| Check | How | Why it matters |
|---|---|---|
| Harness installed | grep `test/test_helper.rb` for `require "plutonium/testing"` | Concerns never autoload — run `pu:test:install` first |
| Resource exposed in each named portal | The resource is `register_resource`'d in each portal | `--portals=` must match mounted engines |
| Portal engine names | `:admin` ⇒ `AdminPortal::Engine` | Mismatch ⇒ pass `path_prefix:` explicitly |
| Login password | Test accounts seeded with `password123` (fixtures/factories) | `login_as` POSTs that hardcoded value, or use `sign_in_for_tests` |
| Tenant binding | `create_resource!`/`policy_record` return `@tenant`-bound records | Else scope tests pass for the wrong reason |

Inspect with your own tools **before** scaffolding.

## 🛠 Use the generator — fill the stubs, don't hand-write

| Task | Generator | Verify first |
|---|---|---|
| Install harness (once per app) | `pu:test:install` | Not already in `test_helper.rb` |
| Scaffold tests | `pu:test:scaffold Klass --portals=… --concerns=…` | Harness installed; resource exposed in those portals |

Hand-written test files drift from conventions — scaffold, then fill the `NotImplementedError` stubs with tenant-correct data.

---

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

## DSL reference

Every concern uses the same class-level DSL:

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

The **portal symbol** drives:

| Derived | `:admin` example | `:org` example |
|---|---|---|
| `path_prefix` | `/admin` | `/org` |
| Default sign-in helper | admin Rodauth | user Rodauth |
| Allowed action set | from definition | from definition |

`path_prefix` is auto-resolved from the mounted portal engine. For mounts inside `constraints` (typical Plutonium setup), the resolver walks the route tree and finds the engine.

## Concerns catalog

Each concern is `include`d separately. Pick the ones you need.

### `Plutonium::Testing::ResourceCrud`

Generates index / show / new / create / edit / update / destroy integration tests against the portal-mounted resource.

**Stubs:**
- `create_resource!` → persisted record
- `valid_create_params` → Hash for POST
- `valid_update_params` → Hash for PATCH

```ruby
class AdminPortal::BloggingPostsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
    @user = create_user!
    @org = create_organization!
    login_as(@admin)
  end

  def create_resource! = create_post!(user: @user, organization: @org)
  def valid_create_params
    {title: "x", body: "y", status: :draft, user: @user.to_sgid.to_s, organization: @org.to_sgid.to_s}
  end
  def valid_update_params = {title: "Updated"}
end
```

### `Plutonium::Testing::ResourcePolicy`

Asserts the `permit?` matrix across action × role and verifies `relation_scope` returns an `ActiveRecord::Relation`.

**Stubs:**
- `policy_roles` → `{role_sym => -> { account }}`
- `policy_record` → persisted record under test
- `policy_matrix` → `{action_sym => [allowed_role_syms]}`
- `policy_context` (optional) → extra kwargs (defaults to `{entity_scope: nil}`)

```ruby
def policy_roles = {admin: -> { @admin }, member: -> { @user }}
def policy_record = create_post!(user: @user, organization: @org)
def policy_matrix = {
  index: %i[admin member], show: %i[admin member],
  create: %i[admin], update: %i[admin], destroy: %i[admin]
}
```

### `Plutonium::Testing::ResourceDefinition`

Smoke-tests the resource definition: the class is constantize-able, every defineable prop dictionary (fields/inputs/displays/columns/scopes/filters/sorts/actions) is queryable, and declared fields exist on the model.

**No stubs required** for the happy path.

### `Plutonium::Testing::ResourceInteraction`

Outcome-assertion helpers for `Plutonium::Interaction::Base` subclasses.

**Helpers:**
- `assert_interaction_success(klass, **input)` → returns the success outcome
- `assert_interaction_failure(klass, **input)` → returns the failure outcome
- `interaction_view_context` (overridable) → defaults to a mock view context

```ruby
test "RebuildSearchInteraction succeeds" do
  outcome = assert_interaction_success(RebuildSearchInteraction, since: 1.day.ago)
  assert_equal 42, outcome.value[:rebuilt_count]
end
```

### `Plutonium::Testing::ResourceModel`

Tests `associated_with` scope, SGID routing, and `has_cents` accessors — gated by DSL flags.

**Stubs:**
- `model_test_record` → persisted record

```ruby
resource_tests_for Catalog::Product, portal: :admin,
  associated_with: :organization,
  sgid_routing: true,
  has_cents: %i[price]

def model_test_record = create_product!(user: @user, organization: @org)
```

Only the flagged features generate tests.

### `Plutonium::Testing::NestedResource`

Asserts CRUD under a parent + scope-boundary tests (sibling tenants invisible).

**Stubs:**
- `parent_record!` → current tenant
- `other_parent_record!` → sibling tenant
- `create_resource!(parent:)` → persisted record under given parent

### `Plutonium::Testing::PortalAccess`

Cross-portal access boundaries. Uses its own DSL — not `resource_tests_for`.

```ruby
class PortalAccessTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::PortalAccess

  portal_access_for portals: %i[admin org],
    matrix: {admin: %i[admin], member: %i[org]}

  setup do
    @admin = create_admin!
    @user = create_user!
    @org = create_organization!
    create_membership!(organization: @org, user: @user)
  end

  def login_as_role(role)
    case role
    when :admin then login_as(@admin, portal: :admin)
    when :member then login_as(@user, portal: :user)
    end
  end

  def portal_root_path(portal)
    case portal
    when :admin then "/admin"
    when :org then "/org/#{@org.id}"
    end
  end
end
```

Generates one test per (role × portal). Allowed = `200|302`; blocked = `302|401|403|404`.

## Auth helpers

`Plutonium::Testing::AuthHelpers` is included transitively by every concern.

```ruby
login_as(account)                          # uses portal from DSL
login_as(account, portal: :admin)          # explicit override
sign_out                                    # uses portal from DSL
sign_out(portal: :admin)
current_account                             # uses portal from DSL
current_account(portal: :admin)
with_portal(:org) { ... }                  # scoped portal switch
```

**Default Rodauth login expects `password: "password123"`** — `login_as` POSTs to `/<account_table>/login` with that hardcoded password. Either seed test accounts with it (fixtures/factories) or override via `sign_in_for_tests` below.

**Override hook for non-Rodauth apps (or to bypass Rodauth in tests):** define `sign_in_for_tests(account, portal:)` in your test class (or in `test/support/plutonium_testing.rb` for project-wide use). `AuthHelpers` will defer to it.

```ruby
def sign_in_for_tests(account, portal:)
  # your custom auth flow here
end
```

## Generator reference

### `pu:test:install`

```bash
rails g pu:test:install
```

- Adds `require "plutonium/testing"` to `test/test_helper.rb` (idempotent)
- Creates `test/support/plutonium_testing.rb` with override stub

### `pu:test:scaffold`

```bash
rails g pu:test:scaffold Blogging::Post --portals=admin,org
rails g pu:test:scaffold Blogging::Post --portals=admin --concerns=crud,policy,definition
rails g pu:test:scaffold Blogging::Post --portals=org --parent=organization --dest=blogging
```

| Flag | Default | Purpose |
|---|---|---|
| `--portals=admin,org` | required | Emit one file per portal |
| `--concerns=...` | `crud,policy,definition` | Concerns to include (`crud,policy,definition,nested,model,interaction,portal_access`) |
| `--parent=organization` | none | Wires `NestedResource` parent |
| `--dest=main_app\|<package>` | `main_app` | Output destination |

Output path: `test/integration/<portal>_portal/<resource_underscored>_test.rb`.

## Customization & escape hatches

- **Skip individual tests:** `resource_tests_for Klass, portal: :admin, skip: %i[destroy]`
- **Restrict action set:** `resource_tests_for Klass, portal: :admin, actions: %i[index show]`
- **Custom assertions:** add regular `test "..."` blocks alongside the generated matrix — they coexist.
- **Non-Rodauth auth:** override `sign_in_for_tests`. See AuthHelpers section.
- **Custom path prefix:** `path_prefix: "/v2/admin"` overrides portal resolution.

## Common pitfalls

- **Forgotten stubs raise `NotImplementedError`** with the stub name. Look for the missing method in your test class.
- **Portal mismatch:** `:admin` portal expects `AdminPortal::Engine` constant. If your portal is named differently, pass `path_prefix:` explicitly.
- **Tenant leakage in stubs:** `create_resource!` for an org portal must return a record bound to the test's `@org`. Otherwise scope filtering tests will pass for the wrong reason.
- **`policy_record` for tenant-scoped resources** must belong to a tenant the role has access to — otherwise even allowed roles will see `false`.
- **Nested resources need `parent: :foo`** in the DSL AND a real parent record from `parent_record!`. Without both, path interpolation fails.
- **`PortalAccess` doesn't use `resource_tests_for`** — use `portal_access_for` instead. Mixing them on the same class is undefined behavior.

## Related skills

- [[plutonium-behavior]] — policies (verified by `ResourcePolicy`), interactions (asserted by `ResourceInteraction`)
- [[plutonium-resource]] — definition props the smoke test introspects (`field`, `input`, `display`, `column`, `scope`, `filter`, `sort`, `action`)
- [[plutonium-tenancy]] — `relation_scope`, parent scoping, nested resources (matched by `NestedResource`)
- [[plutonium-app]] — portal mounting and entity strategies that drive auth/scoping
- [[plutonium-auth]] — Rodauth setup behind the default login flow
