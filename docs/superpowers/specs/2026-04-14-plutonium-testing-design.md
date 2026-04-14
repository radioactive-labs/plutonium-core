# Plutonium::Testing — Design Spec

**Date:** 2026-04-14
**Status:** Approved (pre-implementation)
**Audience:** End-app developers using Plutonium

---

## Goal

Ship `Plutonium::Testing` — a public, opt-in collection of Minitest concerns that give Plutonium app developers default test coverage for resources, policies, definitions, interactions, models, nested scoping, portal access, and authentication. Pair the module with a `plutonium-testing` skill and a Rails generator (`pu:test:scaffold`) that produces ready-to-run test files per (resource × portal) pairing.

## Non-Goals

- RSpec support (Minitest only for first cut).
- A test data builder / factory layer (out of scope; callers wire their own factories or fixtures).
- Replacing Plutonium's own internal `test/support/shared_tests/` ahead of the public API landing — the migration is the *last* implementation step and serves as dogfooding.

## Approach

- **Loading model:** opt-in `require "plutonium/testing"` in the consumer's `test/test_helper.rb`. No autoload, no production cost. Mirrors `ActiveSupport::Testing::*` conventions.
- **Granularity:** one concern per category. Callers `include` exactly what they need. No umbrella module.
- **DSL + stub methods:** declarative config (`resource_tests_for Post, portal: :admin`) for shape; abstract stub methods (raising `NotImplementedError`) for test data the caller must provide.
- **Portal-centric:** the `portal:` symbol is the single unit of configuration. It resolves to path prefix, default sign-in helper, expected scoping, and allowed action set by introspecting the mounted portal engine. Same resource × different portal = different test file.

---

## Architecture

### File Layout

```
lib/plutonium/
  testing.rb                           # top-level require; loads submodules
  testing/
    dsl.rb                             # shared `resource_tests_for` + portal resolution
    auth_helpers.rb                    # login_as / sign_out / with_portal (portal-aware)
    resource_crud.rb                   # integration CRUD matrix
    resource_policy.rb                 # permit? × action × role; relation_scope filtering
    resource_definition.rb             # fields/inputs/displays/columns/scopes smoke
    resource_interaction.rb            # interaction outcome assertions
    resource_model.rb                  # associated_with, SGID, has_cents
    nested_resource.rb                 # tenant-scoped CRUD + boundary assertions
    portal_access.rb                   # cross-portal access boundaries

lib/generators/pu/test/
  install/install_generator.rb         # one-time setup
  install/templates/plutonium_testing.rb.tt
  scaffold/scaffold_generator.rb       # per-resource × portal scaffold
  scaffold/templates/integration_test.rb.tt
  scaffold/templates/policy_test.rb.tt
  scaffold/templates/definition_test.rb.tt

test/plutonium/testing/                # tests for the testing module itself
  dsl_test.rb
  auth_helpers_test.rb
  resource_crud_test.rb
  resource_policy_test.rb
  resource_definition_test.rb
  resource_interaction_test.rb
  resource_model_test.rb
  nested_resource_test.rb
  portal_access_test.rb

test/generators/pu/test/
  install_generator_test.rb
  scaffold_generator_test.rb

.claude/skills/plutonium-testing/
  SKILL.md

docs/guides/testing.md
```

### Loading

`lib/plutonium/testing.rb` is the entry point:

```ruby
require "plutonium/testing/dsl"
require "plutonium/testing/auth_helpers"
require "plutonium/testing/resource_crud"
require "plutonium/testing/resource_policy"
require "plutonium/testing/resource_definition"
require "plutonium/testing/resource_interaction"
require "plutonium/testing/resource_model"
require "plutonium/testing/nested_resource"
require "plutonium/testing/portal_access"
```

Consumers add `require "plutonium/testing"` to `test/test_helper.rb` (the `pu:test:install` generator does this for them).

---

## DSL

`Plutonium::Testing::DSL` is included by every concern. Provides one class-level method:

```ruby
resource_tests_for ResourceClass,
  portal:      :admin,                           # required: portal symbol
  path_prefix: "/admin",                         # optional: explicit override
  parent:      :organization,                    # optional: nested-resource parent
  actions:     %i[index show new create edit update destroy],  # optional: opt-in set
  skip:        %i[destroy]                       # optional: opt-out individual tests
```

The portal symbol drives:

| Derived from portal | Example for `:admin` | Example for `:org` |
|---|---|---|
| `path_prefix` | `/admin` | `/org/:organization_id` |
| Default sign-in | admin Rodauth strategy | org-member Rodauth strategy |
| Expected entity scoping | unscoped | scoped to `@organization` |
| Allowed action set | from definition | from definition |

DSL stores the current portal in a test-class-local attr; `AuthHelpers` reads it as default when no `portal:` kwarg is given.

### Cross-portal tests

For tests that touch multiple portals (`PortalAccess` concern), `portal:` is an explicit kwarg on helper calls:

```ruby
login_as(@admin, portal: :admin)
login_as(@user,  portal: :org)
with_portal(:org) { get "/org/posts" }    # block form
```

---

## Concerns

### `Plutonium::Testing::ResourceCrud`

Generates index / show / new / create / edit / update / destroy integration tests against the portal-mounted resource.

**Stubs (caller must implement):**
```ruby
def create_resource!         # -> persisted record
def valid_create_params      # -> Hash for POST
def valid_update_params      # -> Hash for PATCH
```

Sign-in is automatic from the portal's auth strategy unless the caller overrides `sign_in_for_tests(account, portal:)`.

### `Plutonium::Testing::ResourcePolicy`

Asserts the `permit?` matrix across action × role and `relation_scope` filtering.

**Stubs:**
```ruby
def policy_roles             # -> { admin: -> { @admin }, member: -> { @user } }
def policy_record            # -> record instance under test
def policy_matrix            # -> { index: %i[admin member], destroy: %i[admin] }
```

### `Plutonium::Testing::ResourceDefinition`

Smoke-tests that all registered fields/inputs/displays/columns/scopes/filters render without error against a persisted record. Introspects the definition class via `Plutonium::Definition::DefineableProps`. **No caller stubs required** for the happy path.

### `Plutonium::Testing::ResourceInteraction`

Outcome-assertion helpers for `Plutonium::Resource::Interaction` subclasses.

**Helpers:**
- `assert_interaction_success(interaction_class, **input)`
- `assert_interaction_failure(interaction_class, **input)`
- `assert_interaction_redirect(interaction_class, to:, **input)`
- `assert_interaction_renders(interaction_class, view:, **input)`

**Stubs:**
```ruby
def interaction_class
def valid_interaction_input
```

### `Plutonium::Testing::ResourceModel`

Covers `associated_with` scope behavior, SGID routing, and `has_cents` money helpers. DSL flags select which features to test:

```ruby
resource_tests_for Post, portal: :admin,
  associated_with: :organization,
  sgid_routing:    true,
  has_cents:       %i[price]
```

Only generates test methods for enabled features.

### `Plutonium::Testing::NestedResource`

Same CRUD matrix as `ResourceCrud` but asserts scope boundaries: index excludes records from sibling tenants; show on a sibling-tenant record returns 404.

**Stubs:**
```ruby
def parent_record!           # -> persisted parent/tenant
def other_parent_record!     # -> a different tenant for boundary tests
```

### `Plutonium::Testing::PortalAccess`

Cross-portal access boundaries.

**DSL:**
```ruby
portal_access_matrix \
  admin:  %i[admin_portal],
  member: %i[org_portal storefront_portal]
```

Asserts unauthorized portals return 403 or redirect to login.

---

## Auth Helpers

`Plutonium::Testing::AuthHelpers` is included transitively by every concern.

**Public API:**
```ruby
login_as(account)                    # uses portal from DSL
login_as(account, portal: :admin)    # explicit override
sign_out                              # uses portal from DSL
sign_out(portal: :admin)
current_account                       # uses portal from DSL
current_account(portal: :admin)
with_portal(:org) { ... }            # scoped portal switch
```

**Implementation:**
- Looks up the portal's declared auth strategy from the mounted portal engine config.
- For Rodauth (stock Plutonium): fakes the session cookie directly; no full login round-trip.
- **Override hook** for non-Rodauth apps: caller defines `sign_in_for_tests(account, portal:)` and `AuthHelpers` defers to it.

The `pu:test:install` generator scaffolds a commented-out override in `test/support/plutonium_testing.rb`.

---

## Generators

### `pu:test:install`

One-time project setup. Idempotent.

- Adds `require "plutonium/testing"` to `test/test_helper.rb` (no-op if present).
- Creates `test/support/plutonium_testing.rb` with commented-out override stubs for non-Rodauth auth.

### `pu:test:scaffold`

Per-resource scaffold. Produces one file per (resource × portal).

```bash
rails g pu:test:scaffold Blogging::Post --portals=admin,org
rails g pu:test:scaffold Blogging::Post --portals=admin --concerns=crud,policy,definition
rails g pu:test:scaffold Blogging::Post --portals=org --parent=organization --dest=blogging
```

**Flags:**
- `--portals=admin,org` (required) — emits one file per portal.
- `--concerns=crud,policy,definition,nested,model,interaction,portal_access` (default: `crud,policy,definition`).
- `--parent=organization` — wires `NestedResource` parent stub.
- `--dest=main_app|package_name` — output destination (matches `pu:res:scaffold` convention).

**Example output** (`test/integration/admin_portal/blogging_posts_test.rb`):

```ruby
require "test_helper"

class AdminPortal::BloggingPostsTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::ResourceCrud
  include Plutonium::Testing::ResourcePolicy
  include Plutonium::Testing::ResourceDefinition

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!       # TODO: replace with your factory
    login_as(@admin)
  end

  def create_resource!
    Blogging::Post.create!(title: "X", body: "...")    # TODO: adjust
  end

  def valid_create_params
    { title: "New", body: "..." }                       # TODO: adjust
  end

  def valid_update_params
    { title: "Updated" }                                # TODO: adjust
  end

  def policy_roles
    { admin: -> { @admin } }                            # TODO: add other roles
  end

  def policy_record
    create_resource!
  end

  def policy_matrix
    { index: %i[admin], show: %i[admin], create: %i[admin],
      update: %i[admin], destroy: %i[admin] }           # TODO: tighten
  end
end
```

Stub method bodies are pre-filled with best-guess values from model introspection (column types, associations).

---

## Skill

`.claude/skills/plutonium-testing/SKILL.md` follows the existing skill conventions in `.claude/skills/`.

**Frontmatter `description`:**
> Use BEFORE writing tests for a Plutonium resource, running `pu:test:scaffold`, or including `Plutonium::Testing::*` concerns. Covers the full testing toolkit: CRUD, policy, definition, interaction, model, nested, portal access, and auth helpers.

**Sections:**
1. When to use
2. Quick start (install + scaffold + first run)
3. DSL reference (`resource_tests_for` keywords + portal resolution table)
4. Concerns catalog (one section per concern with stub contract + example)
5. Auth helpers
6. Generator reference (`pu:test:install`, `pu:test:scaffold` flags)
7. Customization & escape hatches (non-Rodauth auth, skipping defaults, custom assertions)
8. Common pitfalls (forgotten stubs, portal mismatch, tenant leakage)

The top-level `plutonium` router skill gets one new entry pointing to `plutonium-testing`.

---

## Docs

`docs/guides/testing.md` mirrors the skill content for human-facing documentation. Linked from the guides section in `docs/.vitepress/config.ts`.

---

## In-Repo Adoption (Dogfooding)

After all concerns and generators land, port the dummy app's tests:

- `test/integration/admin_portal/resources_test.rb` and the other portal test files migrate to `Plutonium::Testing::*` concerns.
- `test/support/shared_tests/blogging_post_tests.rb` and `catalog_product_tests.rb` are deleted or shrunk to anything that doesn't fit the generic concerns.

Acceptance: zero coverage loss (compare test method counts before/after) and the entire suite still passes across `rails-7`, `rails-8.0`, `rails-8.1` appraisals.

---

## Implementation Sequence

1. Module skeleton + entry point (`lib/plutonium/testing.rb`).
2. Shared DSL + portal resolution.
3. Auth helpers.
4. Each concern (parallelizable after #2 and #3): ResourceCrud, ResourcePolicy, ResourceDefinition, ResourceInteraction, ResourceModel, NestedResource, PortalAccess.
5. Generators: `pu:test:install`, then `pu:test:scaffold`.
6. Skill + docs.
7. In-repo migration (last — dogfoods the public API).

---

## Open Questions

None at design time. Implementation may surface portal-resolution edge cases (engines mounted at non-standard paths, multiple engines per account type) that warrant follow-up.
