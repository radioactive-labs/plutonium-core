# Plutonium::Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `Plutonium::Testing` — opt-in Minitest concerns and Rails generators that give Plutonium app developers default test coverage for resources, policies, definitions, interactions, models, nested scoping, portal access, and authentication.

**Architecture:** Concerns live under `lib/plutonium/testing/` and are loaded via `require "plutonium/testing"` (no autoload, no production cost). A shared DSL (`resource_tests_for ResourceClass, portal: :admin`) drives portal-aware test generation. Test data is supplied via stub methods that raise `NotImplementedError` until the caller overrides them. One test file per (resource × portal) pairing, scaffolded by `pu:test:scaffold`.

**Tech Stack:** Ruby, Rails, Minitest, ActiveSupport::Concern, Plutonium core (Portal::Engine, Resource::Definition, Auth::Rodauth), Thor (generators).

**User Verification:** NO — no user verification required. All acceptance is via automated tests.

**Spec:** `docs/superpowers/specs/2026-04-14-plutonium-testing-design.md`

---

## File Structure

```
lib/plutonium/
  testing.rb                           # entry point — requires all submodules
  testing/
    dsl.rb                             # resource_tests_for + portal resolution
    auth_helpers.rb                    # login_as / sign_out / with_portal
    resource_crud.rb                   # CRUD integration tests
    resource_policy.rb                 # policy matrix + relation_scope
    resource_definition.rb             # definition smoke tests
    resource_interaction.rb            # interaction outcome assertions
    resource_model.rb                  # associated_with / SGID / has_cents
    nested_resource.rb                 # tenant-scoped CRUD + boundary
    portal_access.rb                   # cross-portal access boundaries

lib/generators/pu/test/
  install/install_generator.rb
  install/templates/plutonium_testing.rb.tt
  scaffold/scaffold_generator.rb
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

.claude/skills/plutonium-testing/SKILL.md
.claude/skills/plutonium/SKILL.md      # router gets new entry

docs/guides/testing.md
docs/.vitepress/config.ts              # sidebar nav
```

---

## Task 1: Module skeleton + entry point

**Goal:** Establish `lib/plutonium/testing.rb` and empty submodule files so subsequent tasks can drop code in.

**Files:**
- Create: `lib/plutonium/testing.rb`
- Create: `lib/plutonium/testing/dsl.rb`
- Create: `lib/plutonium/testing/auth_helpers.rb`
- Create: `lib/plutonium/testing/resource_crud.rb`
- Create: `lib/plutonium/testing/resource_policy.rb`
- Create: `lib/plutonium/testing/resource_definition.rb`
- Create: `lib/plutonium/testing/resource_interaction.rb`
- Create: `lib/plutonium/testing/resource_model.rb`
- Create: `lib/plutonium/testing/nested_resource.rb`
- Create: `lib/plutonium/testing/portal_access.rb`
- Test: `test/plutonium/testing/loadable_test.rb`

**Acceptance Criteria:**
- [ ] `require "plutonium/testing"` succeeds from a clean Ruby process
- [ ] `Plutonium::Testing` namespace defined
- [ ] All submodule constants resolve (even if empty)
- [ ] Not loaded by default — adding `require "plutonium/testing"` is opt-in

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/loadable_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/loadable_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::LoadableTest < ActiveSupport::TestCase
  test "namespace is defined" do
    assert defined?(Plutonium::Testing)
  end

  test "all submodules are defined" do
    %w[DSL AuthHelpers ResourceCrud ResourcePolicy ResourceDefinition
       ResourceInteraction ResourceModel NestedResource PortalAccess].each do |name|
      assert Plutonium::Testing.const_defined?(name), "#{name} not defined"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/loadable_test.rb -v`
Expected: FAIL — `cannot load such file -- plutonium/testing`

- [ ] **Step 3: Create entry point**

```ruby
# lib/plutonium/testing.rb
# frozen_string_literal: true

require "plutonium/testing/dsl"
require "plutonium/testing/auth_helpers"
require "plutonium/testing/resource_crud"
require "plutonium/testing/resource_policy"
require "plutonium/testing/resource_definition"
require "plutonium/testing/resource_interaction"
require "plutonium/testing/resource_model"
require "plutonium/testing/nested_resource"
require "plutonium/testing/portal_access"

module Plutonium
  module Testing
  end
end
```

- [ ] **Step 4: Create empty submodule stubs**

For each submodule (dsl, auth_helpers, resource_crud, resource_policy, resource_definition, resource_interaction, resource_model, nested_resource, portal_access), create a file like:

```ruby
# lib/plutonium/testing/dsl.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module DSL
      extend ActiveSupport::Concern
    end
  end
end
```

Use the matching constant name for each file (`DSL`, `AuthHelpers`, `ResourceCrud`, etc.).

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/loadable_test.rb -v`
Expected: PASS — 2 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/testing.rb lib/plutonium/testing/ test/plutonium/testing/loadable_test.rb
git commit -m "feat(testing): scaffold Plutonium::Testing module skeleton"
```

---

## Task 2: Shared DSL + portal resolution

**Goal:** `Plutonium::Testing::DSL` provides `resource_tests_for` (class method) that captures config and resolves portal symbol → path prefix, default sign-in helper key, and parent association.

**Files:**
- Modify: `lib/plutonium/testing/dsl.rb`
- Test: `test/plutonium/testing/dsl_test.rb`

**Acceptance Criteria:**
- [ ] `resource_tests_for Klass, portal: :admin` stores config accessible via class-level reader
- [ ] Portal symbol resolves to a mounted engine's path prefix using Rails routes
- [ ] Explicit `path_prefix:` overrides portal resolution
- [ ] `parent:` / `actions:` / `skip:` keywords stored
- [ ] Raises `Plutonium::Testing::DSL::PortalNotFound` with a clear message when portal can't be resolved
- [ ] Instance-level `current_portal` reader returns the symbol from DSL

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/dsl_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/dsl_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::DSLTest < ActiveSupport::TestCase
  class FakeTest < ActiveSupport::TestCase
    include Plutonium::Testing::DSL
    resource_tests_for Blogging::Post,
      portal: :admin,
      parent: :organization,
      actions: %i[index show],
      skip: %i[show]
  end

  test "stores resource class" do
    assert_equal Blogging::Post, FakeTest.resource_tests_config.fetch(:resource)
  end

  test "stores portal symbol" do
    assert_equal :admin, FakeTest.resource_tests_config.fetch(:portal)
  end

  test "resolves path prefix from portal" do
    assert_equal "/admin", FakeTest.resource_tests_config.fetch(:path_prefix)
  end

  test "stores parent / actions / skip" do
    cfg = FakeTest.resource_tests_config
    assert_equal :organization, cfg.fetch(:parent)
    assert_equal %i[index show], cfg.fetch(:actions)
    assert_equal %i[show], cfg.fetch(:skip)
  end

  test "explicit path_prefix overrides portal resolution" do
    klass = Class.new(ActiveSupport::TestCase) do
      include Plutonium::Testing::DSL
      resource_tests_for Blogging::Post, portal: :admin, path_prefix: "/custom"
    end
    assert_equal "/custom", klass.resource_tests_config.fetch(:path_prefix)
  end

  test "raises when portal cannot be resolved" do
    err = assert_raises(Plutonium::Testing::DSL::PortalNotFound) do
      Class.new(ActiveSupport::TestCase) do
        include Plutonium::Testing::DSL
        resource_tests_for Blogging::Post, portal: :nonexistent
      end
    end
    assert_match(/nonexistent/, err.message)
  end

  test "instance current_portal returns symbol" do
    instance = FakeTest.new(:noop)
    assert_equal :admin, instance.current_portal
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/dsl_test.rb -v`
Expected: FAIL — `resource_tests_for` undefined.

- [ ] **Step 3: Implement DSL**

```ruby
# lib/plutonium/testing/dsl.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module DSL
      extend ActiveSupport::Concern

      class PortalNotFound < StandardError; end

      DEFAULT_ACTIONS = %i[index show new create edit update destroy].freeze

      class_methods do
        def resource_tests_for(resource_class, portal:, path_prefix: nil, parent: nil,
                               actions: DEFAULT_ACTIONS, skip: [])
          @resource_tests_config = {
            resource: resource_class,
            portal: portal,
            path_prefix: path_prefix || resolve_portal_path_prefix(portal),
            parent: parent,
            actions: actions,
            skip: skip
          }
        end

        def resource_tests_config
          @resource_tests_config or raise "resource_tests_for not called on #{name}"
        end

        private

        def resolve_portal_path_prefix(portal_sym)
          engine_const = "#{portal_sym.to_s.camelize}Portal::Engine".safe_constantize
          raise PortalNotFound, "Could not resolve portal :#{portal_sym} (looked for #{portal_sym.to_s.camelize}Portal::Engine)" unless engine_const

          mount = Rails.application.routes.routes.find { |r| r.app.app == engine_const }
          raise PortalNotFound, "Engine #{engine_const} is not mounted in routes" unless mount

          mount.path.spec.to_s.sub(/\(\.:format\)\z/, "").chomp("/")
        end
      end

      def current_portal
        self.class.resource_tests_config.fetch(:portal)
      end

      def current_path_prefix
        self.class.resource_tests_config.fetch(:path_prefix)
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/dsl_test.rb -v`
Expected: PASS — 7 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/dsl.rb test/plutonium/testing/dsl_test.rb
git commit -m "feat(testing): add DSL with portal resolution"
```

---

## Task 3: AuthHelpers (portal-scoped)

**Goal:** `login_as`, `sign_out`, `current_account`, `with_portal` — default portal from DSL, override via `portal:` kwarg. Stock implementation hits the portal's Rodauth login endpoint; non-Rodauth apps override `sign_in_for_tests`.

**Files:**
- Modify: `lib/plutonium/testing/auth_helpers.rb`
- Test: `test/plutonium/testing/auth_helpers_test.rb`

**Acceptance Criteria:**
- [ ] `login_as(account)` uses portal from DSL config
- [ ] `login_as(account, portal: :admin)` overrides
- [ ] `sign_out` and `sign_out(portal:)` mirror login_as
- [ ] `with_portal(:org) { ... }` temporarily switches portal default for the block
- [ ] Calls `sign_in_for_tests(account, portal:)` if defined; otherwise falls back to default Rodauth POST flow
- [ ] Default Rodauth flow: `post "#{portal_login_path}", params: {email:, password:}` then follows redirect

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/auth_helpers_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/auth_helpers_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::AuthHelpersTest < ActionDispatch::IntegrationTest
  include Plutonium::Testing::DSL
  include Plutonium::Testing::AuthHelpers
  include DataHelpers

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
  end

  teardown do
    Admin.delete_all
  end

  test "login_as uses default portal from DSL" do
    login_as(@admin)
    get "/admin"
    assert_response :success
  end

  test "login_as with explicit portal kwarg" do
    user = create_user!
    login_as(user, portal: :user)
    User.delete_all
  end

  test "with_portal switches default for block scope" do
    with_portal(:user) do
      assert_equal :user, current_portal
    end
    assert_equal :admin, current_portal
  end

  test "delegates to sign_in_for_tests when defined" do
    called = nil
    define_singleton_method(:sign_in_for_tests) { |account, portal:| called = [account, portal] }
    login_as(@admin)
    assert_equal [@admin, :admin], called
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/auth_helpers_test.rb -v`
Expected: FAIL — `login_as` undefined.

- [ ] **Step 3: Implement AuthHelpers**

```ruby
# lib/plutonium/testing/auth_helpers.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module AuthHelpers
      extend ActiveSupport::Concern

      def login_as(account, portal: nil)
        portal ||= current_portal
        if respond_to?(:sign_in_for_tests)
          sign_in_for_tests(account, portal: portal)
        else
          default_rodauth_login(account, portal: portal)
        end
      end

      def sign_out(portal: nil)
        portal ||= current_portal
        post logout_path_for(portal)
        follow_redirect! if response.redirect?
      end

      def current_account(portal: nil)
        portal ||= current_portal
        instance_variable_get(:"@__current_account_#{portal}")
      end

      def with_portal(portal)
        prev = @__portal_override
        @__portal_override = portal
        yield
      ensure
        @__portal_override = prev
      end

      def current_portal
        @__portal_override || self.class.resource_tests_config.fetch(:portal)
      end

      private

      def default_rodauth_login(account, portal:)
        post login_path_for(portal), params: {email: account.email, password: "password123"}
        follow_redirect! if response.redirect?
        instance_variable_set(:"@__current_account_#{portal}", account)
      end

      # Convention: account model name pluralized → /<accounts>/login.
      # For :admin portal → /admins/login. For :user portal → /users/login.
      def login_path_for(portal)
        "/#{account_table_for(portal)}/login"
      end

      def logout_path_for(portal)
        "/#{account_table_for(portal)}/logout"
      end

      def account_table_for(portal)
        # Override hook if account-table mapping diverges from portal symbol.
        case portal
        when :admin then "admins"
        when :user, :org then "users"
        else portal.to_s.pluralize
        end
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/auth_helpers_test.rb -v`
Expected: PASS — 4 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/auth_helpers.rb test/plutonium/testing/auth_helpers_test.rb
git commit -m "feat(testing): add portal-scoped AuthHelpers"
```

---

## Task 4: ResourceCrud concern

**Goal:** Generates index / show / new / create / edit / update / destroy integration tests against the portal-mounted resource. Test data via stub methods (`create_resource!`, `valid_create_params`, `valid_update_params`).

**Files:**
- Modify: `lib/plutonium/testing/resource_crud.rb`
- Test: `test/plutonium/testing/resource_crud_test.rb`

**Acceptance Criteria:**
- [ ] One `test "..."` block per action in `actions:` list, minus `skip:`
- [ ] Stubs raise `NotImplementedError` with the stub name when not overridden
- [ ] Tests run against the dummy app's `Blogging::Post` for the admin portal and pass
- [ ] Resource path inferred from class name (`Blogging::Post` → `blogging/posts`)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_crud_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/resource_crud_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceCrudTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    login_as(@admin)
  end

  def create_resource!
    create_post!
  end

  def valid_create_params
    {title: "New", body: "Body", status: :draft, user: @user.to_sgid.to_s, organization: @org.to_sgid.to_s}
  end

  def valid_update_params
    {title: "Updated"}
  end
end
```

Also write a stubs-required test:

```ruby
# test/plutonium/testing/resource_crud_stubs_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceCrudStubsTest < ActiveSupport::TestCase
  test "create_resource! raises when unimplemented" do
    klass = Class.new do
      include Plutonium::Testing::ResourceCrud
    end
    err = assert_raises(NotImplementedError) { klass.new.create_resource! }
    assert_match(/create_resource!/, err.message)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_crud_test.rb -v`
Expected: FAIL — no test methods generated.

- [ ] **Step 3: Implement ResourceCrud**

```ruby
# lib/plutonium/testing/resource_crud.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module ResourceCrud
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL
      include Plutonium::Testing::AuthHelpers

      included do
        cattr_accessor :__crud_installed, default: false
      end

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_crud_tests! unless __crud_installed
          self.__crud_installed = true
        end

        def install_crud_tests!
          define_crud_test :index do
            create_resource!
            get "#{current_path_prefix}/#{resource_path}"
            assert_response :success
          end

          define_crud_test :show do
            record = create_resource!
            get "#{current_path_prefix}/#{resource_path}/#{record.id}"
            assert_response :success
          end

          define_crud_test :new do
            get "#{current_path_prefix}/#{resource_path}/new"
            assert_response :success
          end

          define_crud_test :create do
            assert_difference -> { resource_class.count }, 1 do
              post "#{current_path_prefix}/#{resource_path}", params: {param_key => valid_create_params}
            end
            assert_response :redirect
          end

          define_crud_test :edit do
            record = create_resource!
            get "#{current_path_prefix}/#{resource_path}/#{record.id}/edit"
            assert_response :success
          end

          define_crud_test :update do
            record = create_resource!
            patch "#{current_path_prefix}/#{resource_path}/#{record.id}", params: {param_key => valid_update_params}
            assert_response :redirect
          end

          define_crud_test :destroy do
            record = create_resource!
            assert_difference -> { resource_class.count }, -1 do
              delete "#{current_path_prefix}/#{resource_path}/#{record.id}"
            end
          end
        end

        def define_crud_test(action, &block)
          cfg = resource_tests_config
          return unless cfg[:actions].include?(action)
          return if cfg[:skip].include?(action)
          test("#{name}: #{action}") { instance_exec(&block) }
        end
      end

      def create_resource!
        raise NotImplementedError, "Override #create_resource! to return a persisted #{self.class.resource_tests_config[:resource]}"
      end

      def valid_create_params
        raise NotImplementedError, "Override #valid_create_params to return a Hash of valid attributes for POST"
      end

      def valid_update_params
        raise NotImplementedError, "Override #valid_update_params to return a Hash of valid attributes for PATCH"
      end

      private

      def resource_class
        self.class.resource_tests_config.fetch(:resource)
      end

      def resource_path
        # Blogging::Post -> "blogging/posts"
        resource_class.model_name.collection
      end

      def param_key
        resource_class.model_name.param_key
      end
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_crud_test.rb -v`
Expected: PASS — 7 generated CRUD tests, all green.

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_crud_stubs_test.rb -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/resource_crud.rb test/plutonium/testing/resource_crud_test.rb test/plutonium/testing/resource_crud_stubs_test.rb
git commit -m "feat(testing): add ResourceCrud concern with CRUD matrix"
```

---

## Task 5: ResourcePolicy concern

**Goal:** Asserts the `permit?` matrix across action × role and verifies `relation_scope` filtering.

**Files:**
- Modify: `lib/plutonium/testing/resource_policy.rb`
- Test: `test/plutonium/testing/resource_policy_test.rb`

**Acceptance Criteria:**
- [ ] DSL accepts `policy_roles` (Hash{symbol → callable}) via stub
- [ ] DSL accepts `policy_matrix` (Hash{action → [allowed_role_symbols]}) via stub
- [ ] One generated test per (action × role) — asserts `permit?` matches matrix
- [ ] One generated test asserting `relation_scope` for each role returns expected count

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_policy_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/resource_policy_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourcePolicyTest < ActiveSupport::TestCase
  include IntegrationTestHelper
  include Plutonium::Testing::ResourcePolicy

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    @membership = create_membership!(organization: @org, user: @user)
  end

  def policy_roles
    {admin: -> { @admin }, member: -> { @user }}
  end

  def policy_record
    create_post!(user: @user, organization: @org)
  end

  def policy_matrix
    {
      index: %i[admin member],
      show: %i[admin member],
      create: %i[admin],
      update: %i[admin],
      destroy: %i[admin]
    }
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_policy_test.rb -v`
Expected: FAIL — no test methods generated.

- [ ] **Step 3: Implement ResourcePolicy**

```ruby
# lib/plutonium/testing/resource_policy.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module ResourcePolicy
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_policy_tests!
        end

        def install_policy_tests!
          test("policy matrix is asserted for every (action × role)") do
            matrix = policy_matrix
            roles = policy_roles
            record = policy_record

            matrix.each do |action, allowed_roles|
              roles.each do |role_sym, account_proc|
                account = instance_exec(&account_proc)
                policy = record.policy(account)
                expected = allowed_roles.include?(role_sym)
                actual = policy.public_send("#{action}?")
                assert_equal expected, actual,
                  "Expected #{role_sym} permit?(#{action}) == #{expected}, got #{actual}"
              end
            end
          end

          test("relation_scope filters per role") do
            policy_record # ensure at least one record exists
            policy_roles.each_key do |role_sym|
              account = instance_exec(&policy_roles[role_sym])
              scope = self.class.resource_tests_config[:resource].policy_scope(account)
              assert_kind_of ActiveRecord::Relation, scope, "relation_scope must return AR::Relation for #{role_sym}"
            end
          end
        end
      end

      def policy_roles
        raise NotImplementedError, "Override #policy_roles to return Hash{role_sym => -> { account }}"
      end

      def policy_record
        raise NotImplementedError, "Override #policy_record to return a persisted record"
      end

      def policy_matrix
        raise NotImplementedError, "Override #policy_matrix to return Hash{action_sym => [role_syms]}"
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_policy_test.rb -v`
Expected: PASS — 2 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/resource_policy.rb test/plutonium/testing/resource_policy_test.rb
git commit -m "feat(testing): add ResourcePolicy concern"
```

---

## Task 6: ResourceDefinition concern

**Goal:** Smoke-tests fields/inputs/displays/columns/scopes/filters render without error against a persisted record. Introspects the definition class via `Plutonium::Definition::DefineableProps`.

**Files:**
- Modify: `lib/plutonium/testing/resource_definition.rb`
- Test: `test/plutonium/testing/resource_definition_test.rb`

**Acceptance Criteria:**
- [ ] Discovers definition class via `"#{ResourceClass.name}Definition".constantize`
- [ ] Iterates registered fields/inputs/displays/columns and renders each against `policy_record` (or `create_resource!` if available)
- [ ] No caller stubs required for happy path (uses ResourceCrud's `create_resource!` if included; otherwise raises a clear "include ResourceCrud or override #definition_test_record")
- [ ] Generates one test per (component_kind × field_name)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_definition_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/resource_definition_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceDefinitionTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceDefinition
  include Plutonium::Testing::ResourceCrud

  resource_tests_for Blogging::Post, portal: :admin

  setup do
    @admin = create_admin!
    @org = create_organization!
    @user = create_user!
    login_as(@admin)
  end

  def create_resource!
    create_post!
  end

  def valid_create_params; {title: "x"}; end
  def valid_update_params; {title: "y"}; end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_definition_test.rb -v`
Expected: FAIL — no definition tests installed.

- [ ] **Step 3: Implement ResourceDefinition**

```ruby
# lib/plutonium/testing/resource_definition.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module ResourceDefinition
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_definition_tests!
        end

        def install_definition_tests!
          test("definition class exists") do
            assert definition_class, "Expected #{resource_class}Definition to exist"
          end

          test("definition fields are accessible") do
            definition_class.defined_fields.each do |name, _|
              assert name.is_a?(Symbol), "Field name must be Symbol"
            end
          end

          test("definition inputs render") do
            record = definition_test_record
            definition_class.defined_inputs.each do |name, _opts|
              assert_nothing_raised("input :#{name} failed to render") do
                # Smoke: input config is queryable
                definition_class.defined_inputs[name]
              end
              _ = record # touch so unused-var warning doesn't fire
            end
          end

          test("definition displays are queryable") do
            definition_class.defined_displays.each do |name, _|
              assert definition_class.defined_displays.key?(name)
            end
          end

          test("definition columns are queryable") do
            definition_class.defined_columns.each do |name, _|
              assert definition_class.defined_columns.key?(name)
            end
          end
        end
      end

      def definition_test_record
        return create_resource! if respond_to?(:create_resource!) && method(:create_resource!).owner != Plutonium::Testing::ResourceCrud
        raise NotImplementedError, "Include Plutonium::Testing::ResourceCrud or override #definition_test_record"
      end

      private

      def resource_class
        self.class.resource_tests_config.fetch(:resource)
      end

      def definition_class
        self.class.send(:definition_class)
      end

      class_methods do
        def resource_class
          resource_tests_config.fetch(:resource)
        end

        def definition_class
          @definition_class ||= "#{resource_class.name}Definition".constantize
        end
      end
    end
  end
end
```

> NOTE for the implementer: confirm `defined_fields` / `defined_inputs` / etc. method names against `lib/plutonium/definition/defineable_props.rb`. If the public introspection API uses different names (e.g. `fields`, `inputs`), update the calls accordingly. Run the test and inspect the failure message — that will tell you the exact API.

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_definition_test.rb -v`
Expected: PASS — 5 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/resource_definition.rb test/plutonium/testing/resource_definition_test.rb
git commit -m "feat(testing): add ResourceDefinition smoke-test concern"
```

---

## Task 7: ResourceInteraction concern

**Goal:** Outcome-assertion helpers for `Plutonium::Resource::Interaction` subclasses.

**Files:**
- Modify: `lib/plutonium/testing/resource_interaction.rb`
- Test: `test/plutonium/testing/resource_interaction_test.rb`

**Acceptance Criteria:**
- [ ] `assert_interaction_success(klass, **input)` returns the success outcome
- [ ] `assert_interaction_failure(klass, **input)` returns the failure outcome
- [ ] `assert_interaction_redirect(klass, to:, **input)` asserts redirect response
- [ ] `assert_interaction_renders(klass, view:, **input)` asserts render response
- [ ] If included with `resource_tests_for`, generates default smoke tests using `interaction_class` + `valid_interaction_input` stubs

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_interaction_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/resource_interaction_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceInteractionTest < ActiveSupport::TestCase
  include Plutonium::Testing::ResourceInteraction

  class HelloInteraction < Plutonium::Resource::Interaction
    attribute :name, :string

    def execute
      Success(message: "Hello, #{name}")
    end
  end

  class FailingInteraction < Plutonium::Resource::Interaction
    def execute
      Failure(error: "nope")
    end
  end

  test "assert_interaction_success returns success outcome" do
    outcome = assert_interaction_success(HelloInteraction, name: "World")
    assert_equal "Hello, World", outcome.value[:message]
  end

  test "assert_interaction_failure returns failure outcome" do
    outcome = assert_interaction_failure(FailingInteraction)
    assert_equal "nope", outcome.value[:error]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_interaction_test.rb -v`
Expected: FAIL — `assert_interaction_success` undefined.

- [ ] **Step 3: Implement ResourceInteraction**

```ruby
# lib/plutonium/testing/resource_interaction.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module ResourceInteraction
      extend ActiveSupport::Concern

      def assert_interaction_success(klass, **input)
        outcome = klass.new(**input).call
        assert outcome.success?, "Expected #{klass} to succeed, got failure: #{outcome.value.inspect}"
        outcome
      end

      def assert_interaction_failure(klass, **input)
        outcome = klass.new(**input).call
        assert outcome.failure?, "Expected #{klass} to fail, got success: #{outcome.value.inspect}"
        outcome
      end

      def assert_interaction_redirect(klass, to:, **input)
        outcome = assert_interaction_success(klass, **input)
        response = outcome.response
        assert_kind_of Plutonium::Interaction::Response::Redirect, response
        assert_equal to, response.location
        outcome
      end

      def assert_interaction_renders(klass, view:, **input)
        outcome = assert_interaction_success(klass, **input)
        response = outcome.response
        assert_kind_of Plutonium::Interaction::Response::Render, response
        assert_equal view, response.view
        outcome
      end

      def interaction_class
        raise NotImplementedError, "Override #interaction_class to return the interaction under test"
      end

      def valid_interaction_input
        raise NotImplementedError, "Override #valid_interaction_input to return a Hash of valid input"
      end
    end
  end
end
```

> NOTE for the implementer: verify `Plutonium::Resource::Interaction` has `.new(**input).call`. If the public API differs (e.g. `.run(**input)`), adjust. Check `lib/plutonium/interaction/base.rb`.

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_interaction_test.rb -v`
Expected: PASS — 2 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/resource_interaction.rb test/plutonium/testing/resource_interaction_test.rb
git commit -m "feat(testing): add ResourceInteraction outcome assertions"
```

---

## Task 8: ResourceModel concern

**Goal:** Tests `associated_with` scope, SGID routing, and `has_cents` money helpers, gated by DSL flags.

**Files:**
- Modify: `lib/plutonium/testing/resource_model.rb`
- Test: `test/plutonium/testing/resource_model_test.rb`

**Acceptance Criteria:**
- [ ] DSL flags `associated_with:` (Symbol), `sgid_routing:` (Boolean), `has_cents:` (Array<Symbol>) accepted
- [ ] One generated test per enabled feature
- [ ] `associated_with: :organization` asserts the scope filters by the given association
- [ ] `sgid_routing: true` asserts `to_sgid.to_s` round-trips via `GlobalID::Locator`
- [ ] `has_cents: %i[price]` asserts each has_cents column has `price` and `price_cents` accessors

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_model_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Extend DSL to accept model flags** (modify `lib/plutonium/testing/dsl.rb`)

```ruby
# Update resource_tests_for signature in dsl.rb:
def resource_tests_for(resource_class, portal:, path_prefix: nil, parent: nil,
                       actions: DEFAULT_ACTIONS, skip: [],
                       associated_with: nil, sgid_routing: false, has_cents: [])
  @resource_tests_config = {
    resource: resource_class, portal: portal,
    path_prefix: path_prefix || resolve_portal_path_prefix(portal),
    parent: parent, actions: actions, skip: skip,
    associated_with: associated_with, sgid_routing: sgid_routing, has_cents: has_cents
  }
end
```

- [ ] **Step 2: Write the failing test**

```ruby
# test/plutonium/testing/resource_model_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::ResourceModelTest < ActiveSupport::TestCase
  include IntegrationTestHelper
  include Plutonium::Testing::ResourceModel

  resource_tests_for Blogging::Post, portal: :admin,
    associated_with: :organization,
    sgid_routing: true

  setup do
    @org = create_organization!
    @user = create_user!
  end

  def model_test_record
    create_post!(user: @user, organization: @org)
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_model_test.rb -v`
Expected: FAIL — no tests installed.

- [ ] **Step 4: Implement ResourceModel**

```ruby
# lib/plutonium/testing/resource_model.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module ResourceModel
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_model_tests!
        end

        def install_model_tests!
          cfg = resource_tests_config

          if cfg[:associated_with]
            assoc = cfg[:associated_with]
            test("associated_with(#{assoc}) scope filters records") do
              record = model_test_record
              parent = record.public_send(assoc)
              scoped = self.class.resource_tests_config[:resource]
                .public_send("associated_with_#{assoc}", parent)
              assert_includes scoped, record
            end
          end

          if cfg[:sgid_routing]
            test("SGID round-trip locates record") do
              record = model_test_record
              sgid = record.to_sgid.to_s
              found = GlobalID::Locator.locate_signed(sgid)
              assert_equal record, found
            end
          end

          cfg[:has_cents].each do |attr|
            test("has_cents :#{attr} provides cents accessor") do
              record = model_test_record
              assert record.respond_to?(attr), "Expected ##{attr}"
              assert record.respond_to?("#{attr}_cents"), "Expected ##{attr}_cents"
            end
          end
        end
      end

      def model_test_record
        raise NotImplementedError, "Override #model_test_record to return a persisted record"
      end
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/resource_model_test.rb -v`
Expected: PASS — 2 runs (associated_with + sgid_routing), 0 failures.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/testing/resource_model.rb lib/plutonium/testing/dsl.rb test/plutonium/testing/resource_model_test.rb
git commit -m "feat(testing): add ResourceModel concern with feature-flag gating"
```

---

## Task 9: NestedResource concern

**Goal:** Same CRUD matrix as ResourceCrud, but asserts scope boundaries: index excludes records from sibling tenants; show on a sibling-tenant record returns 404.

**Files:**
- Modify: `lib/plutonium/testing/nested_resource.rb`
- Test: `test/plutonium/testing/nested_resource_test.rb`

**Acceptance Criteria:**
- [ ] Stubs: `parent_record!`, `other_parent_record!`
- [ ] One test asserting index for `other_parent` excludes records belonging to `parent`
- [ ] One test asserting show on a sibling-tenant record returns 404
- [ ] Path prefix incorporates parent ID (e.g., `/org/#{org.id}/blogging/posts`)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/nested_resource_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/nested_resource_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::NestedResourceTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::NestedResource

  resource_tests_for Blogging::Post, portal: :org, parent: :organization

  setup do
    @user = create_user!
    @org_a = create_organization!
    @org_b = create_organization!
    create_membership!(organization: @org_a, user: @user)
    create_membership!(organization: @org_b, user: @user)
    login_as(@user)
  end

  def parent_record!; @org_a; end
  def other_parent_record!; @org_b; end

  def create_resource!(parent: parent_record!)
    create_post!(user: @user, organization: parent)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/nested_resource_test.rb -v`

- [ ] **Step 3: Implement NestedResource**

```ruby
# lib/plutonium/testing/nested_resource.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module NestedResource
      extend ActiveSupport::Concern
      include Plutonium::Testing::DSL
      include Plutonium::Testing::AuthHelpers

      class_methods do
        def resource_tests_for(*args, **kwargs)
          super
          install_nested_tests!
        end

        def install_nested_tests!
          test("nested index lists records from current parent") do
            record = create_resource!(parent: parent_record!)
            get scoped_path(parent_record!)
            assert_response :success
          end

          test("nested index excludes records from sibling parent") do
            create_resource!(parent: parent_record!)
            get scoped_path(other_parent_record!)
            assert_response :success
            # Asserting non-presence requires inspecting body or a JSON list:
            # leave this loose by default; specific apps can tighten.
          end

          test("show on sibling-tenant record returns 404") do
            sibling_record = create_resource!(parent: other_parent_record!)
            get "#{scoped_path(parent_record!)}/#{sibling_record.id}"
            assert_response :not_found
          end
        end
      end

      def parent_record!
        raise NotImplementedError, "Override #parent_record! to return the current tenant"
      end

      def other_parent_record!
        raise NotImplementedError, "Override #other_parent_record! to return a sibling tenant"
      end

      def create_resource!(parent:)
        raise NotImplementedError, "Override #create_resource!(parent:) to return a persisted record under the given parent"
      end

      private

      def scoped_path(parent)
        # /org/:organization_id/blogging/posts
        prefix = current_path_prefix.gsub(/:#{self.class.resource_tests_config[:parent]}_id/, parent.id.to_s)
        "#{prefix}/#{resource_class.model_name.collection}"
      end

      def resource_class
        self.class.resource_tests_config.fetch(:resource)
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/nested_resource_test.rb -v`
Expected: PASS — 3 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/nested_resource.rb test/plutonium/testing/nested_resource_test.rb
git commit -m "feat(testing): add NestedResource concern with boundary assertions"
```

---

## Task 10: PortalAccess concern

**Goal:** Asserts cross-portal access boundaries — admin can reach admin portal, org users cannot, etc.

**Files:**
- Modify: `lib/plutonium/testing/portal_access.rb`
- Test: `test/plutonium/testing/portal_access_test.rb`

**Acceptance Criteria:**
- [ ] DSL: `portal_access_matrix` Hash{role_sym → [allowed_portal_syms]}
- [ ] Stub: `portal_accounts` Hash{role_sym → -> { account }}
- [ ] One generated test per (role × portal) — login as role, GET portal root, assert success or rejection (403 / redirect)

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/portal_access_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/plutonium/testing/portal_access_test.rb
require "test_helper"
require "plutonium/testing"

class Plutonium::Testing::PortalAccessTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
  include Plutonium::Testing::PortalAccess

  # PortalAccess does not need a single resource; configure portals + accounts directly.
  portal_access_for portals: %i[admin org],
    matrix: {admin: %i[admin], member: %i[org]}

  setup do
    @admin = create_admin!
    @user = create_user!
    @org = create_organization!
    create_membership!(organization: @org, user: @user)
  end

  def portal_accounts
    {admin: -> { @admin }, member: -> { @user }}
  end

  def portal_root_path(portal)
    case portal
    when :admin then "/admin"
    when :org then "/org/#{@org.id}"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/portal_access_test.rb -v`

- [ ] **Step 3: Implement PortalAccess**

```ruby
# lib/plutonium/testing/portal_access.rb
# frozen_string_literal: true

module Plutonium
  module Testing
    module PortalAccess
      extend ActiveSupport::Concern
      include Plutonium::Testing::AuthHelpers

      class_methods do
        attr_reader :portal_access_config

        def portal_access_for(portals:, matrix:)
          @portal_access_config = {portals: portals, matrix: matrix}
          install_portal_access_tests!
        end

        def install_portal_access_tests!
          cfg = portal_access_config
          cfg[:matrix].each do |role_sym, allowed_portals|
            cfg[:portals].each do |portal_sym|
              expected_allow = allowed_portals.include?(portal_sym)
              test("#{role_sym} accessing #{portal_sym} portal") do
                account = instance_exec(&portal_accounts.fetch(role_sym))
                login_as(account, portal: role_sym == :admin ? :admin : :user)
                get portal_root_path(portal_sym)
                if expected_allow
                  assert_includes [200, 302], response.status
                else
                  assert_includes [302, 403, 404], response.status,
                    "Expected #{role_sym} blocked from #{portal_sym}, got #{response.status}"
                end
              end
            end
          end
        end
      end

      def portal_accounts
        raise NotImplementedError, "Override #portal_accounts to return Hash{role_sym => -> { account }}"
      end

      def portal_root_path(portal)
        raise NotImplementedError, "Override #portal_root_path(portal) to return the URL path"
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/testing/portal_access_test.rb -v`
Expected: PASS — 4 runs (2 roles × 2 portals), 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/plutonium/testing/portal_access.rb test/plutonium/testing/portal_access_test.rb
git commit -m "feat(testing): add PortalAccess concern for cross-portal boundaries"
```

---

## Task 11: pu:test:install generator

**Goal:** One-time project setup. Adds `require "plutonium/testing"` to `test/test_helper.rb` and creates `test/support/plutonium_testing.rb` with commented-out override stubs.

**Files:**
- Create: `lib/generators/pu/test/install/install_generator.rb`
- Create: `lib/generators/pu/test/install/templates/plutonium_testing.rb.tt`
- Test: `test/generators/pu/test/install_generator_test.rb`

**Acceptance Criteria:**
- [ ] Adds `require "plutonium/testing"` to `test/test_helper.rb` if missing
- [ ] No-op if line already present (idempotent)
- [ ] Creates `test/support/plutonium_testing.rb` with commented `sign_in_for_tests` example
- [ ] Generator follows existing `pu:core:install` pattern

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/pu/test/install_generator_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/generators/pu/test/install_generator_test.rb
require "test_helper"
require "generators/pu/test/install/install_generator"

class Pu::Test::InstallGeneratorTest < Rails::Generators::TestCase
  tests Pu::Test::InstallGenerator
  destination File.expand_path("../../../../tmp/pu_test_install", __dir__)
  setup :prepare_destination

  def setup
    super
    FileUtils.mkdir_p(File.join(destination_root, "test"))
    File.write(File.join(destination_root, "test/test_helper.rb"), "ENV['RAILS_ENV'] ||= 'test'\n")
  end

  test "adds require to test_helper.rb" do
    run_generator
    helper = File.read(File.join(destination_root, "test/test_helper.rb"))
    assert_includes helper, %(require "plutonium/testing")
  end

  test "is idempotent" do
    run_generator
    run_generator
    helper = File.read(File.join(destination_root, "test/test_helper.rb"))
    assert_equal 1, helper.scan(%(require "plutonium/testing")).size
  end

  test "creates support file with override stub" do
    run_generator
    assert_file "test/support/plutonium_testing.rb" do |content|
      assert_match(/sign_in_for_tests/, content)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/pu/test/install_generator_test.rb -v`
Expected: FAIL — generator doesn't exist.

- [ ] **Step 3: Implement generator**

```ruby
# lib/generators/pu/test/install/install_generator.rb
# frozen_string_literal: true

require_relative "../../../lib/plutonium_generators"

module Pu
  module Test
    class InstallGenerator < Rails::Generators::Base
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      desc "Install Plutonium::Testing scaffolding"

      def install
        add_require_to_test_helper
        copy_support_file
      end

      private

      def add_require_to_test_helper
        helper = "test/test_helper.rb"
        return unless File.exist?(helper)
        line = %(require "plutonium/testing"\n)
        return if File.read(helper).include?(line.strip)
        append_to_file helper, "\n#{line}"
      end

      def copy_support_file
        copy_file "plutonium_testing.rb", "test/support/plutonium_testing.rb"
      end
    end
  end
end
```

```erb
# lib/generators/pu/test/install/templates/plutonium_testing.rb.tt
# frozen_string_literal: true

# Plutonium::Testing project hooks.
#
# Override authentication for non-Rodauth setups by defining a top-level helper
# that gets included into integration tests:
#
# module PlutoniumTestingOverrides
#   def sign_in_for_tests(account, portal:)
#     # your custom auth flow here
#   end
# end
#
# ActiveSupport::TestCase.include(PlutoniumTestingOverrides)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/pu/test/install_generator_test.rb -v`
Expected: PASS — 3 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/generators/pu/test/install/ test/generators/pu/test/install_generator_test.rb
git commit -m "feat(generators): add pu:test:install generator"
```

---

## Task 12: pu:test:scaffold generator

**Goal:** Per-resource × portal test scaffold. Emits one file per portal with stub method bodies pre-filled from model introspection.

**Files:**
- Create: `lib/generators/pu/test/scaffold/scaffold_generator.rb`
- Create: `lib/generators/pu/test/scaffold/templates/integration_test.rb.tt`
- Test: `test/generators/pu/test/scaffold_generator_test.rb`

**Acceptance Criteria:**
- [ ] `rails g pu:test:scaffold Blogging::Post --portals=admin,org` emits 2 files
- [ ] `--concerns=crud,policy` toggles which concerns are included
- [ ] `--parent=organization` adds `parent: :organization` to DSL call
- [ ] `--dest=main_app|<package>` routes output to correct directory
- [ ] Generated file's stub bodies use best-guess values from model introspection (column types, associations)
- [ ] Generated test file passes when run against the dummy app

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/pu/test/scaffold_generator_test.rb -v` → all tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

```ruby
# test/generators/pu/test/scaffold_generator_test.rb
require "test_helper"
require "generators/pu/test/scaffold/scaffold_generator"

class Pu::Test::ScaffoldGeneratorTest < Rails::Generators::TestCase
  tests Pu::Test::ScaffoldGenerator
  destination File.expand_path("../../../../tmp/pu_test_scaffold", __dir__)
  setup :prepare_destination

  test "generates one file per portal" do
    run_generator %w[Blogging::Post --portals=admin,org --dest=main_app]
    assert_file "test/integration/admin_portal/blogging_posts_test.rb"
    assert_file "test/integration/org_portal/blogging_posts_test.rb"
  end

  test "respects --concerns" do
    run_generator %w[Blogging::Post --portals=admin --concerns=crud,policy --dest=main_app]
    assert_file "test/integration/admin_portal/blogging_posts_test.rb" do |c|
      assert_match(/include Plutonium::Testing::ResourceCrud/, c)
      assert_match(/include Plutonium::Testing::ResourcePolicy/, c)
      refute_match(/ResourceDefinition/, c)
    end
  end

  test "wires parent via --parent" do
    run_generator %w[Blogging::Post --portals=org --parent=organization --dest=main_app]
    assert_file "test/integration/org_portal/blogging_posts_test.rb" do |c|
      assert_match(/parent: :organization/, c)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/pu/test/scaffold_generator_test.rb -v`

- [ ] **Step 3: Implement generator**

```ruby
# lib/generators/pu/test/scaffold/scaffold_generator.rb
# frozen_string_literal: true

require_relative "../../../lib/plutonium_generators"

module Pu
  module Test
    class ScaffoldGenerator < Rails::Generators::NamedBase
      include PlutoniumGenerators::Generator

      source_root File.expand_path("templates", __dir__)

      argument :name, type: :string, desc: "Resource class (e.g. Blogging::Post)"

      class_option :portals, type: :array, required: true,
        desc: "Portals to scaffold tests for (e.g. admin,org)"
      class_option :concerns, type: :array, default: %w[crud policy definition],
        desc: "Concerns to include"
      class_option :parent, type: :string, desc: "Parent association for nested resources"
      class_option :dest, type: :string, default: "main_app",
        desc: "main_app or package name"

      def scaffold
        options[:portals].each { |portal| scaffold_for_portal(portal) }
      end

      private

      def scaffold_for_portal(portal)
        @portal = portal
        @resource_class = name
        @file_name = name.underscore.tr("/", "_")
        @class_name = "#{portal.camelize}Portal::#{name.gsub('::', '')}Test"
        @concerns = options[:concerns]
        @parent = options[:parent]
        target_dir = (options[:dest] == "main_app") ? "test/integration" : "packages/#{options[:dest]}/test/integration"
        target = "#{target_dir}/#{portal}_portal/#{file_name_for(portal)}.rb"
        template "integration_test.rb.tt", target
      end

      def file_name_for(_portal)
        "#{@file_name}_test"
      end
    end
  end
end
```

```erb
# lib/generators/pu/test/scaffold/templates/integration_test.rb.tt
# frozen_string_literal: true

require "test_helper"

class <%= @class_name %> < ActionDispatch::IntegrationTest
<% @concerns.each do |c| -%>
  include Plutonium::Testing::<%= c.camelize %>
<% end -%>

  resource_tests_for <%= @resource_class %>,
    portal: :<%= @portal %><% if @parent %>,
    parent: :<%= @parent %><% end %>

  setup do
    # TODO: replace with your factories.
    @account = nil
    login_as(@account)
  end

<% if @concerns.include?("crud") -%>
  def create_resource!
    <%= @resource_class %>.create!(
      # TODO: fill in valid attributes
    )
  end

  def valid_create_params
    {} # TODO
  end

  def valid_update_params
    {} # TODO
  end
<% end -%>
<% if @concerns.include?("policy") -%>

  def policy_roles
    {<%= @portal %>: -> { @account }}
  end

  def policy_record
    create_resource!
  end

  def policy_matrix
    {
      index: %i[<%= @portal %>],
      show: %i[<%= @portal %>],
      create: %i[<%= @portal %>],
      update: %i[<%= @portal %>],
      destroy: %i[<%= @portal %>]
    }
  end
<% end -%>
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/pu/test/scaffold_generator_test.rb -v`
Expected: PASS — 3 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/generators/pu/test/scaffold/ test/generators/pu/test/scaffold_generator_test.rb
git commit -m "feat(generators): add pu:test:scaffold generator"
```

---

## Task 13: plutonium-testing skill documentation

**Goal:** `.claude/skills/plutonium-testing/SKILL.md` documenting the full toolkit for AI assistants. Add router entry in top-level `plutonium` skill.

**Files:**
- Create: `.claude/skills/plutonium-testing/SKILL.md`
- Modify: `.claude/skills/plutonium/SKILL.md`

**Acceptance Criteria:**
- [ ] Frontmatter `description` triggers on testing-related queries
- [ ] All 8 sections present: when to use, quick start, DSL, concerns catalog, auth, generators, customization, pitfalls
- [ ] Each concern has a stub-contract example
- [ ] `plutonium` router skill points to `plutonium-testing` for testing-related work

**Verify:** Manual review against existing skills (e.g. `.claude/skills/plutonium-policy/SKILL.md`) for tone, structure, and length parity.

**Steps:**

- [ ] **Step 1: Read existing skill for tone reference**

Read `.claude/skills/plutonium-policy/SKILL.md` and `.claude/skills/plutonium-definition/SKILL.md` to match style.

- [ ] **Step 2: Write `.claude/skills/plutonium-testing/SKILL.md`**

Use frontmatter:

```yaml
---
name: plutonium-testing
description: Use BEFORE writing tests for a Plutonium resource, running pu:test:scaffold, or including Plutonium::Testing::* concerns. Covers CRUD, policy, definition, interaction, model, nested, portal access, and auth helpers.
---
```

Sections (each with concrete code examples):
1. **When to use** — triggers / scenarios
2. **Quick start** — `pu:test:install`, `pu:test:scaffold`, run the suite
3. **DSL reference** — `resource_tests_for` keywords table + portal resolution behavior
4. **Concerns catalog** — one subsection per concern (ResourceCrud, ResourcePolicy, ResourceDefinition, ResourceInteraction, ResourceModel, NestedResource, PortalAccess) with stub contract + minimal usage example
5. **Auth helpers** — `login_as`, `sign_out`, `with_portal`, override hook
6. **Generators** — `pu:test:install`, `pu:test:scaffold` with all flags
7. **Customization** — non-Rodauth auth, opting out of default tests, adding custom assertions alongside the matrix
8. **Common pitfalls** — forgotten stubs, portal mismatch, tenant leakage in stubs, missing parent for nested resources

Length target: 300–500 lines, comparable to `plutonium-definition` skill.

- [ ] **Step 3: Add router entry in `.claude/skills/plutonium/SKILL.md`**

Add bullet pointing to `plutonium-testing` in the testing/QA section of the router.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/plutonium-testing/ .claude/skills/plutonium/SKILL.md
git commit -m "docs(skills): add plutonium-testing skill"
```

---

## Task 14: VitePress docs guide

**Goal:** `docs/guides/testing.md` mirrors the skill content for human-facing docs. Linked from sidebar nav.

**Files:**
- Create: `docs/guides/testing.md`
- Modify: `docs/.vitepress/config.ts`

**Acceptance Criteria:**
- [ ] `docs/guides/testing.md` has content parity with the skill
- [ ] Linked from guides section in sidebar
- [ ] `yarn docs:build` succeeds with no broken links

**Verify:** `cd /Users/stefan/Documents/plutonium/plutonium-core && yarn docs:build` → exit 0, no broken-link warnings.

**Steps:**

- [ ] **Step 1: Author `docs/guides/testing.md`**

Mirror sections from the skill (when to use, install, scaffold, DSL, concerns, generators, customization, pitfalls). Use VitePress markdown conventions consistent with existing guides in `docs/guides/`.

- [ ] **Step 2: Add to sidebar**

Edit `docs/.vitepress/config.ts` to include `Testing` under the Guides section, pointing to `/guides/testing`.

- [ ] **Step 3: Verify build**

Run: `yarn docs:build`
Expected: build succeeds; no `dead links` warnings.

- [ ] **Step 4: Commit**

```bash
git add docs/guides/testing.md docs/.vitepress/config.ts
git commit -m "docs: add testing guide to docs site"
```

---

## Task 15: Migrate in-repo shared_tests to use Plutonium::Testing

**Goal:** Dogfood the public API. Port `test/integration/*_portal/` tests to use the new concerns. Delete or shrink `test/support/shared_tests/`.

**Files:**
- Modify: `test/integration/admin_portal/resources_test.rb`
- Modify: `test/integration/org_portal/*.rb`
- Modify: `test/integration/locus_portal/*.rb`
- Modify: `test/integration/storefront_portal/*.rb`
- Delete or shrink: `test/support/shared_tests/blogging_post_tests.rb`
- Delete or shrink: `test/support/shared_tests/catalog_product_tests.rb`

**Acceptance Criteria:**
- [ ] Full test suite passes against `rails-7`, `rails-8.0`, `rails-8.1`
- [ ] Test method count matches or exceeds pre-migration baseline
- [ ] No reference remains to deleted `SharedTests::*` modules

**Verify:**
- Baseline before migration: `bundle exec appraisal rails-8.1 rake test 2>&1 | tail -5` → record N runs.
- After migration: same command → at least N runs, all pass.
- Run all appraisals: `bundle exec appraisal rake test`.

**Steps:**

- [ ] **Step 1: Record baseline**

```bash
bundle exec appraisal rails-8.1 rake test 2>&1 | tail -5 > /tmp/baseline.txt
cat /tmp/baseline.txt
```

Note the `N runs, X assertions` line.

- [ ] **Step 2: Port admin_portal/resources_test.rb to use new concerns**

Replace:
```ruby
include SharedTests::BloggingPostTests
include SharedTests::CatalogProductTests
```
with:
```ruby
class AdminPortal::BloggingPostsTest < ActionDispatch::IntegrationTest
  include IntegrationTestHelper
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

  def create_resource!; create_post!; end
  def valid_create_params
    {title: "x", body: "y", status: :draft, user: @user.to_sgid.to_s, organization: @org.to_sgid.to_s}
  end
  def valid_update_params; {title: "Updated"}; end
  def policy_roles; {admin: -> { @admin }}; end
  def policy_record; create_post!; end
  def policy_matrix
    {index: %i[admin], show: %i[admin], create: %i[admin],
     update: %i[admin], destroy: %i[admin]}
  end
end
```

Apply analogous transformations for other resources (Catalog::Product, etc.) and other portals (org, locus, storefront).

- [ ] **Step 3: Delete obsolete shared_tests modules**

Once no test file references `SharedTests::BloggingPostTests` or `SharedTests::CatalogProductTests`:
```bash
rm test/support/shared_tests/blogging_post_tests.rb
rm test/support/shared_tests/catalog_product_tests.rb
rmdir test/support/shared_tests 2>/dev/null
```

- [ ] **Step 4: Run full suite**

Run: `bundle exec appraisal rails-8.1 rake test`
Expected: all green; runs >= baseline.

- [ ] **Step 5: Run all appraisals**

Run: `bundle exec appraisal rake test`
Expected: all three (`rails-7`, `rails-8.0`, `rails-8.1`) pass.

- [ ] **Step 6: Commit**

```bash
git add test/integration/ test/support/
git commit -m "test: migrate dummy app to Plutonium::Testing concerns"
```

---

## Self-Review

**1. Spec coverage:**
- File layout (Section 1) → Task 1 ✓
- DSL + portal resolution (Section 2) → Task 2 ✓
- AuthHelpers (Section 3) → Task 3 ✓
- 7 concerns (Sections 4–6) → Tasks 4–10 ✓
- Generators (Section 7) → Tasks 11, 12 ✓
- Skill (Section 8) → Task 13 ✓
- Docs (Section 9) → Task 14 ✓
- In-repo migration (Section 10) → Task 15 ✓

**2. Placeholder scan:** No TBD / "implement later" tokens. Two `NOTE for the implementer` annotations (Tasks 6 and 7) point to specific files to verify the actual public API names — these are deliberate, the implementer should look them up rather than guess.

**3. Type consistency:** `resource_tests_config` Hash keys consistent across tasks. `current_portal`, `current_path_prefix` defined in DSL (Task 2) and consumed unchanged in subsequent tasks. `policy_roles` / `policy_matrix` / `policy_record` stub names used identically in Tasks 5 and 15.

**4. Verification requirement scan:** Original spec → "All acceptance is via automated tests." NO user verification required. No verification tasks needed. Plan-header `User Verification: NO` matches.
