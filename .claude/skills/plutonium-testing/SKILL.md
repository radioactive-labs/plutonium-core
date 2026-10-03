---
name: plutonium-testing
description: 'Use BEFORE writing tests for a Plutonium resource, running pu:test:scaffold, or including Plutonium::Testing::* concerns. Covers the full testing toolkit: CRUD, policy, definition, interaction, model, nested, portal access, and auth helpers.'
---

# Plutonium Testing

## 🚨 Critical (read first)

- **Use the generators.** `pu:test:install` once per app, then `pu:test:scaffold ResourceClass --portals=...` per resource × portal. Hand-written test files drift from conventions.
- **Tests are opt-in.** `Plutonium::Testing` is only loaded when `require "plutonium/testing"` runs; it's never autoloaded, never present in production.
- **One file per (resource × portal).** Same model in admin and org portals = two test files. Each portal has different auth, scoping, and allowed actions.
- **Stub methods are required.** Concerns ship with `NotImplementedError` stubs: your test class supplies the test data via `create_resource!`, `valid_create_params`, `policy_roles`, etc.

---

## 🛑 Before you scaffold tests: confirm the shape (ASK: don't infer)

"Write tests for X" leaves out what actually drives the files. Resolve each, confirming by inspection (next section):

1. **Which concerns?** `crud` / `policy` / `definition` / `model` / `nested` / `interaction` / `portal_access`. Don't scaffold all blindly, pick what the resource needs.
2. **Which portals?** **One file per (resource × portal)**: each has different auth, scoping, and allowed actions. A resource in admin + org ⇒ two files.
3. **Nested or entity-scoped?** If the portal calls `scope_to_entity Model, strategy: :path` (e.g. `/org/:id/...`), any "records from another tenant aren't reachable" requirement is the `NestedResource` concern with the entity as the parent: scaffold with `--concerns=crud,nested --parent=organization`. `--parent` alone does not add the `NestedResource` include. See [Entity-scoped portals](#entity-scoped-portals-crud--tenant-isolation) for the two-class layout this needs.
4. **Auth flavor.** Rodauth (the default `login_as` POSTs the hardcoded `password123`) or custom (override `sign_in_for_tests`)?

**Never ship a guessed policy matrix, factory name, or field list**: read the model/definition/policy for the real actions, roles, and fields before filling stubs.

## ✅ Before you scaffold: verify the ground truth (CHECK: read it, don't ask for it)

You have file access: **inspect**; don't ask the user to describe their setup.

| Check | How | Why it matters |
|---|---|---|
| Harness installed | grep `test/test_helper.rb` for `require "plutonium/testing"` | Concerns never autoload; run `pu:test:install` first |
| Resource exposed in each named portal | The resource is `register_resource`'d in each portal | `--portals=` must match mounted engines |
| Portal engine names | `:admin` ⇒ `AdminPortal::Engine` | Mismatch ⇒ pass `path_prefix:` explicitly |
| Login password | Test accounts seeded with `password123` (fixtures/factories) | `login_as` POSTs that hardcoded value, or use `sign_in_for_tests` |
| Tenant binding | `create_resource!`/`policy_record` return `@tenant`-bound records | Else scope tests pass for the wrong reason |
| Entity strategy | grep the portal's `lib/engine.rb` for `scope_to_entity` | `:path` strategy ⇒ the resolved prefix is the bare mount (`/org`), so CRUD needs a `current_path_prefix` override and tenant isolation needs `NestedResource` |

Inspect with your own tools **before** scaffolding.

## 🛠 Use the generator: fill the stubs, don't hand-write

| Task | Generator | Verify first |
|---|---|---|
| Install harness (once per app) | `pu:test:install` | Not already in `test_helper.rb` |
| Scaffold tests | `pu:test:scaffold Klass --portals=… --concerns=…` | Harness installed; resource exposed in those portals |

Hand-written test files drift from conventions; scaffold, then fill the `NotImplementedError` stubs with tenant-correct data.

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

**`valid_update_params` is also the assertion.** After the PATCH, the update test runs `assert_equal value, record.reload.public_send(attr)` for every key. So:

- Use values that read back identically: enums as strings (`status: "published"`, since the enum reader returns a String and `:published` would fail).
- Keep association SGIDs out of it. The loop only skips values starting with `gid://`, but `to_sgid.to_s` is a signed token, so it would compare the token to the associated record and fail. Reassigning an association belongs in its own `test` block that PATCHes the SGID and asserts `record.reload.user == other_user`. `valid_create_params` has no such check, so SGIDs are fine there.

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

Each role lambda is `instance_exec`'d inside the test, once per (action × role), so returning accounts built in `setup` is the intended shape. A lambda that calls `create_user!` would mint a new account on every call, without the membership a tenant-scoped policy checks. Read the policy for the real answers: the matrix above is an example, not a default.

### `Plutonium::Testing::ResourceDefinition`

Smoke-tests the resource definition: the class is constantize-able, every defineable prop dictionary (fields/inputs/displays/columns/scopes/filters/sorts/actions) is queryable, and declared fields exist on the model.

**No stubs required** for the happy path.

### `Plutonium::Testing::ResourceInteraction`

Outcome-assertion helpers for `Plutonium::Interaction::Base` subclasses.

**Helpers:**
- `assert_interaction_success(klass, **input)` → returns the success outcome
- `assert_interaction_failure(klass, **input)` → returns the failure outcome
- `interaction_view_context` (overridable) → the view context both helpers pass in; override it only when the interaction reads something from the view context

Use the helpers for both outcomes; they build the interaction and call it for you.

```ruby
test "PublishProduct moves a draft to active" do
  product = create_product!(status: :draft)
  assert_interaction_success(Catalog::PublishProduct, resource: product)
  assert product.reload.active?
end

test "PublishProduct fails for a product that isn't a draft" do
  product = create_product!(status: :active)
  assert_interaction_failure(Catalog::PublishProduct, resource: product)
  assert product.reload.active?   # state unchanged
end
```

The failure outcome carries no validation errors (they live on the interaction instance), so assert the unchanged state rather than building the interaction by hand to read `errors`.

`ResourceInteraction` includes neither the DSL nor `AuthHelpers`. A file scaffolded with only `--concerns=interaction` still has the template's `resource_tests_for` and `login_as(@account)`, which raise `NoMethodError`: delete both (the helpers need no portal and no login).

### `Plutonium::Testing::ResourceModel`

Tests `associated_with` scope, SGID routing, and `has_cents` accessors, gated by DSL flags.

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
- `parent_record!` → current tenant (called several times per test, so return the same record each time, e.g. `@org`)
- `other_parent_record!` → sibling tenant
- `create_resource!(parent:)` → persisted record under given parent

The concern builds its URLs as `"#{current_path_prefix}/#{parent.id}/#{collection}"`, so it expects the bare portal mount as the prefix and inserts the parent id itself.

#### Entity-scoped portals: CRUD + tenant isolation

In a `strategy: :path` portal, the two concerns need different prefixes and different `create_resource!` signatures:

| | `ResourceCrud` | `NestedResource` |
|---|---|---|
| URL built | `prefix/collection` | `prefix/parent.id/collection` |
| Prefix needed | `/org/#{@org.to_param}` (override `current_path_prefix`) | `/org` (the resolved default) |
| Calls | `create_resource!` | `create_resource!(parent:)` |

One class can't satisfy both, so split the scaffolded file into two classes:

```bash
rails g pu:test:scaffold Catalog::Variant --portals=org --concerns=crud,nested --parent=organization
```

```ruby
class OrgPortal::CatalogVariantTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Catalog::Variant, portal: :org

  setup do
    @org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    @product = create_product!(user: @user, organization: @org)
    login_as(@user)                       # :org logs in through /users/login
  end

  def current_path_prefix = "/org/#{@org.to_param}"
  def create_resource! = create_variant!(product: @product)
  def valid_create_params = {name: "Red", sku: "RED-1", stock_count: 5, product: @product.to_sgid.to_s}
  def valid_update_params = {name: "Red / Large"}
end

class OrgPortal::CatalogVariantNestedTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::NestedResource

  resource_tests_for Catalog::Variant, portal: :org, parent: :organization

  setup do
    @org = create_organization!
    @other_org = create_organization!
    @user = create_user!
    create_membership!(organization: @org, user: @user)
    login_as(@user)
  end

  def parent_record! = @org
  def other_parent_record! = @other_org

  def create_resource!(parent:)
    create_variant!(product: create_product!(organization: parent))
  end
end
```

`create_resource!(parent:)` must create under `parent`, not always under `@org`: the isolation test passes `other_parent_record!` and expects a 404 (or redirect) for that record.

### `Plutonium::Testing::PortalAccess`

Cross-portal access boundaries. Uses its own DSL, not `resource_tests_for`.

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

`login_as` and friends come from `Plutonium::Testing::AuthHelpers`, which only some concerns pull in. The default portal comes from the DSL (`resource_tests_for`), which is a separate include:

| Concern | `login_as` available | Bare `login_as(account)` works |
|---|---|---|
| `ResourceCrud`, `NestedResource` | yes | yes (portal from `resource_tests_for`) |
| `PortalAccess` | yes | no: pass `portal:` every time |
| `ResourcePolicy`, `ResourceDefinition`, `ResourceModel` | no | no |
| `ResourceInteraction` | no | no |

A hand-written integration test that only includes the app's own helpers (e.g. an `IntegrationTestHelper`) has no `login_as` at all. Add `include Plutonium::Testing::AuthHelpers` (and `require "plutonium/testing"` if `test_helper.rb` doesn't) and pass `portal:` explicitly. Likewise, delete the scaffold's `login_as(@account)` from a file whose concerns don't provide it.

```ruby
login_as(account)                          # uses portal from DSL
login_as(account, portal: :admin)          # explicit override
sign_out                                    # uses portal from DSL
sign_out(portal: :admin)
current_account                             # uses portal from DSL
current_account(portal: :admin)
with_portal(:org) { ... }                  # scoped portal switch
```

**Default Rodauth login expects `password: "password123"`.** `login_as` POSTs to `/<account_table>/login` with that hardcoded password. The table comes from the portal: `:admin` ⇒ `/admins/login`, `:user` and `:org` ⇒ `/users/login`, anything else is pluralized (`:locus` ⇒ `/locus/login`), so log org members in with `portal: :user` from portals that aren't named `:org`. Either seed test accounts with it (fixtures/factories) or override via `sign_in_for_tests` below.

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
| `--parent=organization` | none | Adds `parent:` to `resource_tests_for` and, only together with `nested` in `--concerns`, the `parent_record!`/`other_parent_record!` stubs |
| `--dest=main_app\|<package>` | `main_app` | Output destination |

Output path: `test/integration/<portal>_portal/<resource_underscored>_test.rb`.

The template is one class with every requested include, a `setup` that calls `login_as(@account)`, and a no-argument `create_resource!`. Treat it as a starting point: drop `login_as`/`resource_tests_for` where the concerns don't provide them (see Auth helpers), and split `crud` and `nested` into two classes for entity-scoped portals.

## Customization & escape hatches

- **Skip individual tests:** `resource_tests_for Klass, portal: :admin, skip: %i[destroy]`
- **Restrict action set:** `resource_tests_for Klass, portal: :admin, actions: %i[index show]`
- **Custom assertions:** add regular `test "..."` blocks alongside the generated matrix; they coexist.
- **Non-Rodauth auth:** override `sign_in_for_tests`. See AuthHelpers section.
- **Custom path prefix:** `path_prefix: "/v2/admin"` overrides portal resolution.

## Common pitfalls

- **Forgotten stubs raise `NotImplementedError`** with the stub name. Look for the missing method in your test class.
- **Portal mismatch:** `:admin` portal expects `AdminPortal::Engine` constant. If your portal is named differently, pass `path_prefix:` explicitly.
- **Tenant leakage in stubs:** `create_resource!` for an org portal must return a record bound to the test's `@org`. Otherwise scope filtering tests will pass for the wrong reason.
- **`policy_record` for tenant-scoped resources** must belong to a tenant the role has access to; otherwise even allowed roles will see `false`.
- **Nested paths come from `parent_record!.id`**, so it must return a real, persisted tenant the logged-in account belongs to. `parent: :foo` in the DSL documents the relationship; the concern doesn't read it.
- **Entity-scoped CRUD hitting `/org/<collection>`** (404 or routing error): a `:path` portal resolves to the bare mount, so override `current_path_prefix` to include the tenant. Don't do this in a `NestedResource` class, which adds the id itself.
- **`PortalAccess` doesn't use `resource_tests_for`**: use `portal_access_for` instead. Mixing them on the same class is undefined behavior.

## Related skills

- [[plutonium-behavior]]: policies (verified by `ResourcePolicy`), interactions (asserted by `ResourceInteraction`)
- [[plutonium-resource]]: definition props the smoke test introspects (`field`, `input`, `display`, `column`, `scope`, `filter`, `sort`, `action`)
- [[plutonium-tenancy]]: `relation_scope`, parent scoping, nested resources (matched by `NestedResource`)
- [[plutonium-app]]: portal mounting and entity strategies that drive auth/scoping
- [[plutonium-auth]]: Rodauth setup behind the default login flow
