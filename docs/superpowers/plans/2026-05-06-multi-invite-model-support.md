# Multi-Invite-Model Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `pu:invites:install` parameterizable on `--invite_model` so a host app can run it multiple times for different entity types and get fully independent invite flows side-by-side, and extend `PendingInviteCheck` to look across all invite classes.

**Architecture:** Add a single `--invite_model=NAME` generator option (default `UserInvite`). Derive every per-flow name (model, table, controller, mailer, policy, definition, route helpers, file paths) from that name. Templates take ERB-resolved class/path names; generator renames destination paths via interpolation. Concerns gain hooks: `invite_classes` (Array) on `PendingInviteCheck`, overridable `invitation_path_for(token)` on `Controller`, and auto `append_view_path` so generated controllers don't need manual wiring. Welcome controller is generated once on first invocation; subsequent invocations inject the new class into its `invite_classes` array.

**Tech Stack:** Ruby on Rails 8.x generators (Thor), ActiveSupport::Concern, Plutonium gem, Phlex, ActionPolicy, Rodauth (optional), Standard Ruby (linter), Minitest.

**User Verification:** NO — no user verification required.

**Non-goals (called out, not implemented):**
- Migrating prior installs to renamed schemas (host app upgrades manually).
- Cookie-key namespacing — pending-invite cookie remains `:pending_invitation`; first matching class wins on lookup.
- A shared `/invitations/:token` route across flows; each flow owns `/<invitations_path>/:token`.

---

## Existing Groundwork (already shipped in commit `3279be0`)

These are **not** tasks here — they're the baseline this plan builds on:
- `Plutonium::Invites::Concerns::InviteUser#invite_entity_attribute` hook (default `:entity`).
- `Plutonium::Invites::Concerns::InviteToken#user_attribute` hook (default `:user`).
- Policy template uses `entity_association_name` instead of `:entity` in `permitted_attributes_for_*`.
- Model template `create_membership_for` uses `user_association_name`.
- Model template overrides `user_attribute` (when `user_table != "user"`) and `invite_entity_attribute` (when `entity_association_name != "entity"`).
- Layout templates fall back to `javascript_include_tag` when `Importmap` is undefined.

---

## File Structure

### Concerns (`lib/plutonium/invites/`)
- `controller.rb` — auto `append_view_path` on include; replace hardcoded `invitation_path(token: ...)` with overridable `invitation_path_for(token)`; default reads route helper from `invitation_path_helper` (default `:invitation`).
- `pending_invite_check.rb` — `invite_classes` returning `Array<Class>`; `invite_class` kept as a backward-compat shim that returns `[invite_class]`; lookup iterates classes and returns first valid pending invite; auto `append_view_path` on include.

### Generator (`lib/generators/pu/invites/`)
- `install_generator.rb` — add `--invite_model` option (default `UserInvite`); add naming helpers (`invite_model`, `invite_underscore`, `invite_table`, `invitations_controller_class`, `invitations_path`, `invite_route_prefix`); make file-creation steps use derived destination paths; make welcome controller generation one-shot; make route addition scoped + idempotent; on second invocation, inject new invite class into existing welcome controller's `invite_classes`.

### Templates (`lib/generators/pu/invites/templates/`)
All renamed via interpolation in `template "..."` calls so each invocation writes to its own paths:
- `packages/invites/app/models/invites/<%= invite_underscore %>.rb`
- `packages/invites/app/policies/invites/<%= invite_underscore %>_policy.rb`
- `packages/invites/app/definitions/invites/<%= invite_underscore %>_definition.rb`
- `packages/invites/app/mailers/invites/<%= invite_underscore %>_mailer.rb`
- `packages/invites/app/controllers/invites/<%= invitations_path %>_controller.rb`
- `packages/invites/app/views/invites/<%= invite_underscore %>_mailer/invitation.{html,text}.erb`
- `packages/invites/app/views/invites/<%= invitations_path %>/{landing,show,signup,error}.html.erb`
- `db/migrate/create_<%= invite_table %>.rb`

Class names inside templates: `Invites::<InviteModel>`, `Invites::<InviteModel>Mailer`, `Invites::<InviteModel>Policy`, `Invites::<InviteModel>Definition`, `Invites::<InvitationsControllerClass>`. URL helpers: `<%= invite_route_prefix %>_invitation_path`, etc.

Welcome layout (`packages/invites/app/views/layouts/invites/invitation.html.erb`) and welcome controller (`packages/invites/app/controllers/invites/welcome_controller.rb`) are **generated once** (on first invocation only) and remain unparameterized.

### Tests
- `test/generators/invites_install_generator_test.rb` — extend with cases for custom `--invite_model` and a dual-invocation scenario.
- `test/plutonium/invites/pending_invite_check_test.rb` — **new** unit test for multi-class support.
- `test/plutonium/invites/controller_test.rb` — **new** unit test for `invitation_path_for` override and view-path inclusion.

### Docs
- `.claude/skills/plutonium-invites/SKILL.md` — add "Multiple invite flows in one app" section.
- `docs/guides/user-invites.md` — add section.

---

## Task 1: PendingInviteCheck — multi-class support

**Goal:** Make `PendingInviteCheck` look across an Array of invite classes for the first valid pending invite, while preserving backward compatibility with the existing single-class `invite_class` override.

**Files:**
- Modify: `lib/plutonium/invites/pending_invite_check.rb`
- Create: `test/plutonium/invites/pending_invite_check_test.rb`

**Acceptance Criteria:**
- [ ] Public method `pending_invite` returns the first invite found across all classes returned by `invite_classes`, or `nil`.
- [ ] Public method `redirect_to_pending_invite!` redirects to `invitation_path(token: token)` if a valid invite is found in any class.
- [ ] Hosts can override either `invite_class` (single, returning a Class) — backward-compat — or `invite_classes` (returning `Array<Class>`).
- [ ] Default `invite_classes` wraps `invite_class` in an Array.
- [ ] If neither is overridden, calling `pending_invite` raises `NotImplementedError` with a helpful message.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/pending_invite_check_test.rb` → 4 tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

Create `test/plutonium/invites/pending_invite_check_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::Invites::PendingInviteCheckTest < Minitest::Test
  # Stub invite class that emulates `find_for_acceptance`.
  class StubInvite
    @valid_tokens = {}

    class << self
      attr_accessor :valid_tokens

      def find_for_acceptance(token)
        valid_tokens[token]
      end
    end
  end

  class OtherInvite < StubInvite
    @valid_tokens = {}
  end

  # Bare host that includes the concern.
  class Host
    include Plutonium::Invites::PendingInviteCheck

    attr_accessor :_invite_classes

    def cookies = @cookies ||= {encrypted: {}}
    # The concern reads cookies.encrypted[:pending_invitation]; minimal stub:
    def cookies = @cookies ||= Class.new {
      def encrypted = @encrypted ||= {}
      def delete(_key) end
    }.new

    def invite_classes
      _invite_classes
    end
  end

  def setup
    StubInvite.valid_tokens = {}
    OtherInvite.valid_tokens = {}
  end

  def test_finds_invite_in_first_class
    invite = Object.new
    StubInvite.valid_tokens["t1"] = invite

    host = Host.new
    host._invite_classes = [StubInvite, OtherInvite]
    host.cookies.encrypted[:pending_invitation] = "t1"

    assert_equal invite, host.send(:pending_invite)
  end

  def test_finds_invite_in_second_class_when_first_misses
    invite = Object.new
    OtherInvite.valid_tokens["t2"] = invite

    host = Host.new
    host._invite_classes = [StubInvite, OtherInvite]
    host.cookies.encrypted[:pending_invitation] = "t2"

    assert_equal invite, host.send(:pending_invite)
  end

  def test_returns_nil_when_no_class_finds
    host = Host.new
    host._invite_classes = [StubInvite, OtherInvite]
    host.cookies.encrypted[:pending_invitation] = "missing"

    assert_nil host.send(:pending_invite)
  end

  def test_invite_class_singular_override_still_works
    invite = Object.new
    StubInvite.valid_tokens["t3"] = invite

    legacy_host = Class.new {
      include Plutonium::Invites::PendingInviteCheck

      def cookies = @cookies ||= Class.new {
        def encrypted = @encrypted ||= {pending_invitation: "t3"}
        def delete(_key) end
      }.new

      def invite_class
        StubInvite
      end
    }.new

    assert_equal invite, legacy_host.send(:pending_invite)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/pending_invite_check_test.rb`
Expected: tests fail because the concern still raises `NotImplementedError` from `invite_class` and has no `invite_classes` method.

- [ ] **Step 3: Implement the multi-class support**

Modify `lib/plutonium/invites/pending_invite_check.rb`:

```ruby
# frozen_string_literal: true

module Plutonium
  module Invites
    # PendingInviteCheck provides post-login invitation handling.
    #
    # Include this in a controller that users land on after login
    # (e.g., WelcomeController, DashboardController) to check for
    # pending invitations stored in cookies.
    #
    # Hosts may override either `invite_classes` (preferred — returns
    # an Array of invite classes to check, in priority order) or
    # `invite_class` (single class, kept for backward compatibility).
    #
    # @example Single invite class
    #   def invite_class
    #     ::Invites::UserInvite
    #   end
    #
    # @example Multiple invite classes
    #   def invite_classes
    #     [::Invites::FunderInvite, ::Invites::SpenderInvite]
    #   end
    module PendingInviteCheck
      extend ActiveSupport::Concern

      private

      # Check for a pending invitation and redirect if found.
      def redirect_to_pending_invite!
        token = cookies.encrypted[:pending_invitation]
        return false unless token

        if find_pending_invite(token)
          redirect_to invitation_path(token: token)
          true
        else
          cookies.delete(:pending_invitation)
          false
        end
      end

      # Returns the pending invite if one exists across any invite_classes.
      def pending_invite
        token = cookies.encrypted[:pending_invitation]
        return nil unless token

        invite = find_pending_invite(token)
        unless invite
          cookies.delete(:pending_invitation)
          return nil
        end

        invite
      end

      # Override to specify multiple invite model classes (preferred).
      # Defaults to `[invite_class]` for backward compatibility.
      # @return [Array<Class>]
      def invite_classes
        [invite_class]
      end

      # Override to specify a single invite model class. Maintained for
      # backward compatibility; prefer `invite_classes` for multi-flow apps.
      # @return [Class]
      def invite_class
        raise NotImplementedError,
          "#{self.class}#invite_class or #invite_classes must return the invite model class(es)"
      end

      def find_pending_invite(token)
        invite_classes.each do |klass|
          invite = klass.find_for_acceptance(token)
          return invite if invite
        end
        nil
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/pending_invite_check_test.rb`
Expected: 4 tests, 4 assertions, 0 failures.

- [ ] **Step 5: Lint**

Run: `bundle exec standardrb lib/plutonium/invites/pending_invite_check.rb test/plutonium/invites/pending_invite_check_test.rb`
Expected: no violations.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/invites/pending_invite_check.rb test/plutonium/invites/pending_invite_check_test.rb
git commit -m "feat(invites): support multiple invite classes in PendingInviteCheck"
```

---

## Task 2: Auto append_view_path in invites concerns + qualify flash partial

**Goal:** Generated invite controllers should resolve Plutonium's shared partials (e.g., `plutonium/flash`) without each one calling `prepend_view_path` manually. Two parts:

1. Auto-append Plutonium's `app/views` on include of `Plutonium::Invites::Controller` and `Plutonium::Invites::PendingInviteCheck`, mirroring the pattern in `Plutonium::Core::Controller` and `Plutonium::Rodauth::ControllerMethods`.
2. Fix `app/views/plutonium/_flash.html.erb` — currently does `render "flash_toasts"` (unprefixed), which Rails resolves relative to the calling controller's path. Outside Plutonium's portal context (e.g., the invitations controller), that resolution fails. Qualify it as `render "plutonium/flash_toasts"` so the inner partial is always found relative to the source.

**Files:**
- Modify: `lib/plutonium/invites/controller.rb`
- Modify: `lib/plutonium/invites/pending_invite_check.rb`
- Modify: `app/views/plutonium/_flash.html.erb`
- Create: `test/plutonium/invites/controller_test.rb`

**Acceptance Criteria:**
- [ ] Including `Plutonium::Invites::Controller` in an `ActionController::Base` subclass adds Plutonium's `app/views` to its lookup paths.
- [ ] Including `Plutonium::Invites::PendingInviteCheck` in an `ActionController::Base` subclass adds Plutonium's `app/views` to its lookup paths.
- [ ] The path is added with `append_view_path` (not `prepend_view_path`) so host app templates win on conflict.
- [ ] `app/views/plutonium/_flash.html.erb` calls `render "plutonium/flash_toasts"` (qualified path) so it works from any controller that has Plutonium's `app/views` on its lookup path.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/controller_test.rb` → tests pass.

**Steps:**

- [ ] **Step 1: Write the failing test**

Create `test/plutonium/invites/controller_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::Invites::ControllerTest < Minitest::Test
  Plutonium_root_views = File.expand_path("app/views", Plutonium.root)

  def test_controller_concern_appends_plutonium_views
    klass = Class.new(ActionController::Base) do
      include Plutonium::Invites::Controller
    end

    paths = klass.view_paths.map { |p| p.to_s.chomp("/") }
    assert_includes paths, Plutonium_root_views.chomp("/")
  end

  def test_pending_invite_check_concern_appends_plutonium_views
    klass = Class.new(ActionController::Base) do
      include Plutonium::Invites::PendingInviteCheck
    end

    paths = klass.view_paths.map { |p| p.to_s.chomp("/") }
    assert_includes paths, Plutonium_root_views.chomp("/")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/controller_test.rb`
Expected: both tests fail; the Plutonium views path is not in lookup paths.

- [ ] **Step 3: Wire the path append in `Plutonium::Invites::Controller`**

Edit `lib/plutonium/invites/controller.rb`, replace the `included do ... end` block:

```ruby
      included do
        append_view_path File.expand_path("app/views", Plutonium.root)
        helper_method :current_user if respond_to?(:helper_method)
      end
```

- [ ] **Step 4: Wire the path append in `Plutonium::Invites::PendingInviteCheck`**

Edit `lib/plutonium/invites/pending_invite_check.rb`, add `included do` block right after `extend ActiveSupport::Concern`:

```ruby
      extend ActiveSupport::Concern

      included do
        append_view_path File.expand_path("app/views", Plutonium.root)
      end

      private
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/controller_test.rb`
Expected: 2 tests, 2 assertions, 0 failures.

- [ ] **Step 6: Qualify the flash partial path**

Edit `app/views/plutonium/_flash.html.erb`. Replace:

```erb
<%= render "flash_toasts" %>
```

with:

```erb
<%= render "plutonium/flash_toasts" %>
```

This makes the `plutonium/flash` partial usable from any controller that has Plutonium's `app/views` on its lookup path — Rails would otherwise resolve `flash_toasts` relative to the calling controller's path (e.g. `invites/_flash_toasts.html.erb`), which doesn't exist.

- [ ] **Step 7: Run the full invites test set + system tests to confirm no regressions**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/pending_invite_check_test.rb`
Expected: still 4 tests, 4 assertions, 0 failures (Task 1 stays green).

If the test suite has system tests that render flash messages in resource pages, run those too to confirm the qualified path doesn't break the existing portal flow:

Run: `bundle exec appraisal rails-8.1 rake test 2>&1 | tail -20`
Expected: any pre-existing flash-rendering tests still pass.

- [ ] **Step 8: Commit**

```bash
git add lib/plutonium/invites/controller.rb lib/plutonium/invites/pending_invite_check.rb app/views/plutonium/_flash.html.erb test/plutonium/invites/controller_test.rb
git commit -m "feat(invites): auto-append Plutonium views and qualify flash partial path"
```

---

## Task 3: Plutonium::Invites::Controller — overridable invitation_path

**Goal:** Replace the two hardcoded `invitation_path(...)` references in `Plutonium::Invites::Controller` with an overridable `invitation_path_for(token)` so renamed routes (e.g., `funder_invitation_path`) can be plugged in by generated subclasses.

**Files:**
- Modify: `lib/plutonium/invites/controller.rb`
- Modify: `test/plutonium/invites/controller_test.rb`

**Acceptance Criteria:**
- [ ] Concern exposes `invitation_path_for(token)` (private). Default implementation calls `invitation_path(token: token)` (preserves current behavior for single-flow apps).
- [ ] Internal callers (`accept` failure redirect; signup back-link not in concern, but the cookie-based flow) call `invitation_path_for(token)` instead of `invitation_path(token: token)`.
- [ ] Subclass override of `invitation_path_for` is honored.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/controller_test.rb` → 3 tests pass.

**Steps:**

- [ ] **Step 1: Add a test that asserts the override is honored**

Append to `test/plutonium/invites/controller_test.rb`:

```ruby
  def test_invitation_path_for_is_overridable
    klass = Class.new(ActionController::Base) do
      include Plutonium::Invites::Controller

      def invitation_path_for(token)
        "/funder_invitations/#{token}"
      end
    end

    instance = klass.new
    assert_equal "/funder_invitations/abc", instance.send(:invitation_path_for, "abc")
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/controller_test.rb`
Expected: new test fails with `NoMethodError: undefined method 'invitation_path_for'`.

- [ ] **Step 3: Add the helper and route the call site through it**

In `lib/plutonium/invites/controller.rb`:

Replace this block in `accept`:

```ruby
        unless current_user
          redirect_to invitation_path(token: params[:token]),
            alert: "Please sign in to accept this invitation"
          return
        end
```

with:

```ruby
        unless current_user
          redirect_to invitation_path_for(params[:token]),
            alert: "Please sign in to accept this invitation"
          return
        end
```

Then add this private method (next to `invite_class`):

```ruby
      # Override to customize the invitation URL helper.
      # Default uses Rails' `invitation_path(token:)` helper, which is what
      # `pu:invites:install` generates for single-flow apps. Multi-flow apps
      # whose generator scoped the route as `<prefix>_invitation_path` should
      # override this.
      #
      # @param token [String] the invitation token
      # @return [String] the URL path
      def invitation_path_for(token)
        invitation_path(token: token)
      end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/controller_test.rb`
Expected: 3 tests, 3 assertions, 0 failures.

- [ ] **Step 5: Lint**

Run: `bundle exec standardrb lib/plutonium/invites/controller.rb test/plutonium/invites/controller_test.rb`
Expected: no violations.

- [ ] **Step 6: Commit**

```bash
git add lib/plutonium/invites/controller.rb test/plutonium/invites/controller_test.rb
git commit -m "feat(invites): make invitation_path_for overridable"
```

---

## Task 4: install_generator — `--invite_model` option + naming helpers

**Goal:** Introduce the `--invite_model` CLI option and the private naming helpers that subsequent tasks will consume. No template renaming yet — this task only adds the option, helpers, and verifies they compute correctly. Default value `UserInvite` keeps existing behavior intact.

**Files:**
- Modify: `lib/generators/pu/invites/install_generator.rb`
- Modify: `test/generators/invites_install_generator_test.rb`

**Acceptance Criteria:**
- [ ] New `class_option :invite_model, type: :string, default: "UserInvite"` accepted.
- [ ] Private helpers added (each returns a String):
  - [ ] `invite_model` — `"UserInvite"`, `"FunderInvite"`
  - [ ] `invite_underscore` — `"user_invite"`, `"funder_invite"`
  - [ ] `invite_table` — `"user_invites"`, `"funder_invites"`
  - [ ] `invitations_controller_class` — `"UserInvitationsController"`, `"FunderInvitationsController"`
  - [ ] `invitations_path` — `"user_invitations"`, `"funder_invitations"` (URL segment + controller filename)
  - [ ] `invite_route_prefix` — `"user"`, `"funder"` (route helper prefix)
- [ ] Existing tests still pass (default `UserInvite` produces all the prior assertions).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb` → all tests pass (existing + 1 new helper test).

**Steps:**

- [ ] **Step 1: Write the failing helper test**

Append to `test/generators/invites_install_generator_test.rb` (after the existing `default_args` definition):

```ruby
  test "naming helpers derive correctly for default invite_model" do
    generator = Pu::Invites::InstallGenerator.new(default_args, [])
    assert_equal "UserInvite", generator.send(:invite_model)
    assert_equal "user_invite", generator.send(:invite_underscore)
    assert_equal "user_invites", generator.send(:invite_table)
    assert_equal "UserInvitationsController", generator.send(:invitations_controller_class)
    assert_equal "user_invitations", generator.send(:invitations_path)
    assert_equal "user", generator.send(:invite_route_prefix)
  end

  test "naming helpers derive correctly for custom invite_model" do
    generator = Pu::Invites::InstallGenerator.new(
      default_args + ["--invite-model=FunderInvite"], []
    )
    assert_equal "FunderInvite", generator.send(:invite_model)
    assert_equal "funder_invite", generator.send(:invite_underscore)
    assert_equal "funder_invites", generator.send(:invite_table)
    assert_equal "FunderInvitationsController", generator.send(:invitations_controller_class)
    assert_equal "funder_invitations", generator.send(:invitations_path)
    assert_equal "funder", generator.send(:invite_route_prefix)
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/naming helpers/"`
Expected: 2 tests fail with `NoMethodError` for `invite_model` etc.

- [ ] **Step 3: Add option + helpers to install_generator**

In `lib/generators/pu/invites/install_generator.rb`:

Add new `class_option` next to the others (after `class_option :user_model`):

```ruby
      class_option :invite_model, type: :string, default: "UserInvite",
        desc: "The invite model class name (e.g., FunderInvite for Invites::FunderInvite). Run multiple times with different values for separate flows."
```

Add to the `private` section (next to `entity_model`):

```ruby
      def invite_model
        options[:invite_model].camelize
      end

      def invite_underscore
        invite_model.underscore
      end

      def invite_table
        invite_model.tableize
      end

      # e.g. UserInvite -> UserInvitationsController, FunderInvite -> FunderInvitationsController.
      # If the input ends in "Invite", swap to "Invitations"; else append "Invitations".
      def invitations_controller_class
        base = invite_model.sub(/Invite\z/, "")
        "#{base}InvitationsController"
      end

      def invitations_path
        invitations_controller_class.sub(/Controller\z/, "").underscore
      end

      # Route helper prefix: "user" for UserInvite, "funder" for FunderInvite.
      def invite_route_prefix
        invite_model.sub(/Invite\z/, "").underscore.presence || "invite"
      end
```

- [ ] **Step 4: Run helper tests to verify pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/naming helpers/"`
Expected: 2 tests pass.

- [ ] **Step 5: Run full generator test suite to confirm no regressions**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb`
Expected: all existing + 2 new tests pass; assertions count grows by ~14.

- [ ] **Step 6: Commit**

```bash
git add lib/generators/pu/invites/install_generator.rb test/generators/invites_install_generator_test.rb
git commit -m "feat(invites/generator): add --invite_model option and naming helpers"
```

---

## Task 5: Parameterize all templates by invite model name

**Goal:** Rename every per-flow template's destination path and replace every hardcoded `UserInvite` / `user_invite` / `UserInvitations` reference inside templates with ERB-resolved derived names. Welcome controller + invitation layout remain global (one-shot, unchanged in this task).

**Files:**
- Modify: `lib/generators/pu/invites/install_generator.rb` — destination paths in `template "..."` calls.
- Modify: `lib/generators/pu/invites/templates/db/migrate/create_user_invites.rb.tt` — class name only (filename handled in generator step below).
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/models/invites/user_invite.rb.tt`
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/policies/invites/user_invite_policy.rb.tt`
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/definitions/invites/user_invite_definition.rb.tt`
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/mailers/invites/user_invite_mailer.rb.tt`
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/controllers/invites/user_invitations_controller.rb.tt`
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/views/invites/user_invite_mailer/{invitation.html,invitation.text}.erb.tt`
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/views/invites/user_invitations/{landing,show,signup,error}.html.erb.tt`
- Modify: `lib/generators/pu/invites/templates/app/interactions/invite_user_interaction.rb.tt`
- Modify: `lib/generators/pu/invites/templates/app/interactions/user_invite_user_interaction.rb.tt`
- Modify: `test/generators/invites_install_generator_test.rb` — add coverage for custom `--invite_model`.

**Acceptance Criteria:**
- [ ] Default `--invite_model=UserInvite` produces identical file paths and content to today (no regressions in existing tests).
- [ ] Generated controller's `sign_in_user` calls `rodauth.login_session("signup")` instead of `rodauth.login("signup")` (so post-accept redirect isn't pre-empted).
- [ ] `--invite_model=FunderInvite` produces:
  - Migration `db/migrate/<timestamp>_create_funder_invites.rb` with `create_table :funder_invites`.
  - Model `packages/invites/app/models/invites/funder_invite.rb` with `class FunderInvite < Invites::ResourceRecord`.
  - Policy `packages/invites/app/policies/invites/funder_invite_policy.rb` with `class FunderInvitePolicy`.
  - Definition `packages/invites/app/definitions/invites/funder_invite_definition.rb`.
  - Mailer `packages/invites/app/mailers/invites/funder_invite_mailer.rb` with `class FunderInviteMailer`.
  - Controller `packages/invites/app/controllers/invites/funder_invitations_controller.rb` with `class FunderInvitationsController`.
  - Mailer views under `packages/invites/app/views/invites/funder_invite_mailer/`.
  - Controller views under `packages/invites/app/views/invites/funder_invitations/`.
- [ ] Inside generated controller: `invite_class` returns `::Invites::FunderInvite`; `invitation_path_for` overrides default to call `funder_invitation_path(token: token)`.
- [ ] Mailer reads `invitation_url(token: ...)` via the route helper named `<invite_route_prefix>_invitation_url`.
- [ ] All view path helpers in templates use the prefixed route helper name.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb` → all existing + new custom-invite-model tests pass.

**Steps:**

- [ ] **Step 1: Write a failing test for `--invite_model=FunderInvite` outputs**

Add to `test/generators/invites_install_generator_test.rb`:

```ruby
  test "generates funder invite model with custom invite_model" do
    run_generator default_args + ["--invite-model=FunderInvite"]

    assert_migration "db/migrate/create_funder_invites.rb" do |content|
      assert_match(/create_table :funder_invites/, content)
    end

    assert_file "packages/invites/app/models/invites/funder_invite.rb" do |content|
      assert_match(/class FunderInvite < Invites::ResourceRecord/, content)
      assert_match(/include Plutonium::Invites::Concerns::InviteToken/, content)
      assert_match(/Invites::FunderInviteMailer/, content)
    end

    assert_file "packages/invites/app/policies/invites/funder_invite_policy.rb" do |content|
      assert_match(/class FunderInvitePolicy/, content)
    end

    assert_file "packages/invites/app/definitions/invites/funder_invite_definition.rb" do |content|
      assert_match(/class FunderInviteDefinition/, content)
      assert_match(/Invites::ResendInviteInteraction/, content)
    end

    assert_file "packages/invites/app/mailers/invites/funder_invite_mailer.rb" do |content|
      assert_match(/class FunderInviteMailer < ApplicationMailer/, content)
      assert_match(/funder_invitation_url\(token:/, content)
    end

    assert_file "packages/invites/app/controllers/invites/funder_invitations_controller.rb" do |content|
      assert_match(/class FunderInvitationsController < ApplicationController/, content)
      assert_match(/::Invites::FunderInvite/, content)
      assert_match(/funder_invitation_path\(token: token\)/, content)
    end

    assert_file "packages/invites/app/views/invites/funder_invitations/landing.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invitations/show.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invitations/signup.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invitations/error.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invite_mailer/invitation.html.erb"
    assert_file "packages/invites/app/views/invites/funder_invite_mailer/invitation.text.erb"
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n test_generates_funder_invite_model_with_custom_invite_model`
Expected: file/migration assertions fail because all files still write to `user_invite*` paths and class names are still `UserInvite*`.

- [ ] **Step 3: Update destination paths in install_generator**

In `lib/generators/pu/invites/install_generator.rb`, edit each `def create_*` step that uses `template`. Replace destination paths with interpolated ones.

```ruby
      def create_user_invites_migration
        migration_template "db/migrate/create_user_invites.rb",
          "db/migrate/create_#{invite_table}.rb"
      end

      def create_model
        template "packages/invites/app/models/invites/user_invite.rb",
          "packages/invites/app/models/invites/#{invite_underscore}.rb"
      end

      def create_mailer
        template "packages/invites/app/mailers/invites/user_invite_mailer.rb",
          "packages/invites/app/mailers/invites/#{invite_underscore}_mailer.rb"

        template "packages/invites/app/views/invites/user_invite_mailer/invitation.html.erb",
          "packages/invites/app/views/invites/#{invite_underscore}_mailer/invitation.html.erb"

        template "packages/invites/app/views/invites/user_invite_mailer/invitation.text.erb",
          "packages/invites/app/views/invites/#{invite_underscore}_mailer/invitation.text.erb"
      end

      def create_controllers
        template "packages/invites/app/controllers/invites/user_invitations_controller.rb",
          "packages/invites/app/controllers/invites/#{invitations_path}_controller.rb"

        # Welcome controller is a one-shot — only generate if it doesn't exist yet.
        welcome_path = "packages/invites/app/controllers/invites/welcome_controller.rb"
        unless File.exist?(Rails.root.join(welcome_path))
          template "packages/invites/app/controllers/invites/welcome_controller.rb",
            welcome_path
        end
      end

      def create_views
        %w[landing show signup error].each do |view|
          template "packages/invites/app/views/invites/user_invitations/#{view}.html.erb",
            "packages/invites/app/views/invites/#{invitations_path}/#{view}.html.erb"
        end

        # Welcome view is a one-shot too.
        pending_path = "packages/invites/app/views/invites/welcome/pending_invitation.html.erb"
        unless File.exist?(Rails.root.join(pending_path))
          template "packages/invites/app/views/invites/welcome/pending_invitation.html.erb",
            pending_path
        end

        layout_path = "packages/invites/app/views/layouts/invites/invitation.html.erb"
        unless File.exist?(Rails.root.join(layout_path))
          template "packages/invites/app/views/layouts/invites/invitation.html.erb",
            layout_path
        end
      end

      def create_definition
        template "packages/invites/app/definitions/invites/user_invite_definition.rb",
          "packages/invites/app/definitions/invites/#{invite_underscore}_definition.rb"
      end

      def create_policy
        template "packages/invites/app/policies/invites/user_invite_policy.rb",
          "packages/invites/app/policies/invites/#{invite_underscore}_policy.rb"
      end
```

- [ ] **Step 4: Update template content — model**

Edit `lib/generators/pu/invites/templates/packages/invites/app/models/invites/user_invite.rb.tt`. Replace:

```erb
module Invites
  class UserInvite < Invites::ResourceRecord
    ...
    def invitation_mailer
      Invites::UserInviteMailer
    end
```

with:

```erb
module Invites
  class <%= invite_model %> < Invites::ResourceRecord
    ...
    def invitation_mailer
      Invites::<%= invite_model %>Mailer
    end
```

- [ ] **Step 5: Update template content — policy**

Edit `lib/generators/pu/invites/templates/packages/invites/app/policies/invites/user_invite_policy.rb.tt`. Replace:

```erb
module Invites
  class UserInvitePolicy < Invites::ResourcePolicy
```

with:

```erb
module Invites
  class <%= invite_model %>Policy < Invites::ResourcePolicy
```

- [ ] **Step 6: Update template content — definition**

Edit `lib/generators/pu/invites/templates/packages/invites/app/definitions/invites/user_invite_definition.rb.tt`. Replace:

```erb
module Invites
  class UserInviteDefinition < Invites::ResourceDefinition
```

with:

```erb
module Invites
  class <%= invite_model %>Definition < Invites::ResourceDefinition
```

- [ ] **Step 7: Update template content — mailer**

Edit `lib/generators/pu/invites/templates/packages/invites/app/mailers/invites/user_invite_mailer.rb.tt`. Replace:

```erb
module Invites
  class UserInviteMailer < ApplicationMailer
    ...
    def invitation(user_invite)
      @user_invite = user_invite
      @invitation_url = invitation_url(token: user_invite.token)
```

with:

```erb
module Invites
  class <%= invite_model %>Mailer < ApplicationMailer
    ...
    def invitation(invite)
      @invite = invite
      @invitation_url = <%= invite_route_prefix %>_invitation_url(token: invite.token)
```

Also rename `@user_invite` → `@invite` further in the file (subject, template_name lookups). Update mailer-view templates accordingly:

In `packages/invites/app/views/invites/user_invite_mailer/invitation.html.erb.tt` and `.text.erb.tt`, replace every `@user_invite` with `@invite`. (Single-flow apps see no behavioral change; this just unifies naming.)

- [ ] **Step 8: Update template content — controller**

Edit `lib/generators/pu/invites/templates/packages/invites/app/controllers/invites/user_invitations_controller.rb.tt`. Replace:

```erb
module Invites
  class UserInvitationsController < ApplicationController
```

with:

```erb
module Invites
  class <%= invitations_controller_class %> < ApplicationController
```

Replace:

```erb
    def invite_class
      ::Invites::UserInvite
    end
```

with:

```erb
    def invite_class
      ::Invites::<%= invite_model %>
    end

    def invitation_path_for(token)
      <%= invite_route_prefix %>_invitation_path(token: token)
    end
```

Drop the now-unnecessary `prepend_view_path Invites::Engine.root.join("app/views")` line (the engine's view path resolves automatically once the engine is mounted; Plutonium views are now appended by the concern from Task 2).

Also fix the post-signup sign-in flow. Replace:

```erb
    def sign_in_user(user)
      rodauth.account_from_login(user.email)
      rodauth.login("signup")
    end
```

with:

```erb
    def sign_in_user(user)
      rodauth.account_from_login(user.email)
      # login_session just persists the session; `login` would redirect to
      # rodauth.login_redirect and short-circuit our post-accept redirect.
      rodauth.login_session("signup")
    end
```

Reason: `rodauth.login` issues a redirect to `rodauth.login_redirect`, which short-circuits the controller's `redirect_to after_accept_path` and breaks the post-acceptance flow. `login_session` only persists the session.

- [ ] **Step 9: Update view templates — replace hardcoded route helpers**

In `packages/invites/app/views/invites/user_invitations/{landing,show,signup,error}.html.erb.tt`:

- Replace `invitation_signup_path(token: ...)` with `<%= invite_route_prefix %>_invitation_signup_path(token: ...)`.
- Replace `invitation_path(token: ...)` with `<%= invite_route_prefix %>_invitation_path(token: ...)`.
- Replace `accept_invitation_path(token: ...)` with `accept_<%= invite_route_prefix %>_invitation_path(token: ...)`.

Where the helper name is interpolated, double-escape ERB so the host file calls Rails' helper, e.g.:

```erb
<%%= link_to "Create Account", <%= invite_route_prefix %>_invitation_signup_path(token: params[:token]),
```

- [ ] **Step 10: Update interaction templates**

Both `lib/generators/pu/invites/templates/app/interactions/invite_user_interaction.rb.tt` and `user_invite_user_interaction.rb.tt` reference `Invites::UserInvite.roles.keys`. Replace with:

```erb
  input :role, as: :select, choices: Invites::<%= invite_model %>.roles.keys.excluding("owner")
```

- [ ] **Step 11: Update entity association injection**

In install_generator's `add_entity_association` step, the line currently injects:

```ruby
"  has_many :user_invites, class_name: \"Invites::UserInvite\", dependent: :destroy\n"
```

Make it interpolated and use a per-invite name:

```ruby
"  has_many :#{invite_table}, class_name: \"Invites::#{invite_model}\", dependent: :destroy\n"
```

(For `UserInvite` this still emits `:user_invites`; for `FunderInvite` it emits `:funder_invites`.)

- [ ] **Step 12: Run the full generator test**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb`
Expected:
- All existing default-`UserInvite` tests still pass.
- New `funder invite model` test passes.

- [ ] **Step 13: Commit**

```bash
git add lib/generators/pu/invites lib/plutonium/invites test/generators
git commit -m "feat(invites/generator): parameterize templates on invite_model"
```

---

## Task 6: Scope routes per invite type (idempotent re-run)

**Goal:** `add_routes` in install_generator should append a route block scoped to the current `--invite_model` (URL prefix + helper prefix), and skip any block that's already present, so a second invocation with a different `--invite_model` adds new routes without disturbing existing ones.

**Files:**
- Modify: `lib/generators/pu/invites/install_generator.rb` — `add_routes` method.
- Modify: `test/generators/invites_install_generator_test.rb` — add a route-content assertion test.

**Acceptance Criteria:**
- [ ] After `pu:invites:install --invite_model=UserInvite`, `config/routes.rb` contains:

  ```ruby
  scope module: :invites do
    get "user_invitations/welcome", to: "welcome#index", as: :invites_welcome_check
    delete "user_invitations/welcome", to: "welcome#skip", as: :invites_welcome_skip
    get "user_invitations/:token", to: "user_invitations#show", as: :user_invitation
    post "user_invitations/:token/accept", to: "user_invitations#accept", as: :accept_user_invitation
    get "user_invitations/:token/signup", to: "user_invitations#signup", as: :user_invitation_signup
    post "user_invitations/:token/signup", to: "user_invitations#signup"
  end
  ```
  (welcome routes are global — generated once, see step below.)
- [ ] After a second run with `--invite_model=FunderInvite`, the same file contains an additional block with `funder_invitations`/`funder_invitation` helpers, and the `welcome` block is **not** duplicated.
- [ ] Re-running the same `--invite_model` is idempotent (skips with `say_status :skip`).

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/scopes routes/"` → passes.

**Steps:**

- [ ] **Step 1: Add the route-scoping test**

Append to `test/generators/invites_install_generator_test.rb`:

```ruby
  test "scopes routes per invite_model" do
    run_generator default_args

    assert_file "config/routes.rb" do |content|
      assert_match(/get "user_invitations\/:token", to: "user_invitations#show", as: :user_invitation/, content)
      assert_match(/post "user_invitations\/:token\/accept", to: "user_invitations#accept", as: :accept_user_invitation/, content)
      assert_match(/get "user_invitations\/welcome".*as: :invites_welcome_check/, content)
    end
  end

  test "second invocation adds funder routes without duplicating welcome" do
    run_generator default_args
    run_generator default_args + ["--invite-model=FunderInvite"]

    assert_file "config/routes.rb" do |content|
      assert_match(/as: :user_invitation/, content)
      assert_match(/as: :funder_invitation/, content)
      # Welcome route block appears exactly once
      welcome_count = content.scan(/as: :invites_welcome_check/).size
      assert_equal 1, welcome_count, "expected exactly one welcome route, got #{welcome_count}"
    end
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/scopes routes|second invocation/"`
Expected: tests fail because routes still use the un-prefixed `:invitation` helper and the `add_routes` method doesn't scope or guard.

- [ ] **Step 3: Update `add_routes` to scope and guard per invite type**

Replace the body of `add_routes` in `lib/generators/pu/invites/install_generator.rb`:

```ruby
      def add_routes
        routes_content = File.read(Rails.root.join("config/routes.rb"))
        marker = "# Invitation routes for #{invite_model}"

        if routes_content.include?(marker)
          say_status :skip, "Invitation routes for #{invite_model} already present", :yellow
        else
          welcome_present = routes_content.include?("# Invitation welcome routes")

          welcome_block = if welcome_present
            ""
          else
            <<-RUBY

  # Invitation welcome routes (shared across all invite flows)
  scope module: :invites do
    get "invitations/welcome", to: "welcome#index", as: :invites_welcome_check
    delete "invitations/welcome", to: "welcome#skip", as: :invites_welcome_skip
  end
            RUBY
          end

          flow_block = <<-RUBY

  #{marker}
  scope module: :invites do
    get "#{invitations_path}/:token", to: "#{invitations_path}#show", as: :#{invite_route_prefix}_invitation
    post "#{invitations_path}/:token/accept", to: "#{invitations_path}#accept", as: :accept_#{invite_route_prefix}_invitation
    get "#{invitations_path}/:token/signup", to: "#{invitations_path}#signup", as: :#{invite_route_prefix}_invitation_signup
    post "#{invitations_path}/:token/signup", to: "#{invitations_path}#signup"
  end
          RUBY

          inject_into_file "config/routes.rb",
            welcome_block + flow_block,
            before: /^end\s*\z/
        end

        # If no main WelcomeController exists, add /welcome route pointing to
        # Invites::WelcomeController so Rodauth's login_redirect "/welcome" works.
        unless File.exist?(Rails.root.join("app/controllers/welcome_controller.rb")) ||
               routes_content.include?(%(get "welcome", to: "invites/welcome#index"))
          welcome_route = <<-RUBY

  # Welcome route (handled by invites package — replace with pu:saas:welcome for full onboarding)
  get "welcome", to: "invites/welcome#index"
          RUBY

          inject_into_file "config/routes.rb",
            welcome_route,
            before: /^\s*# Invitation welcome routes|^\s*# Invitation routes for/
        end
      end
```

- [ ] **Step 4: Run tests to verify pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/scopes routes|second invocation/"`
Expected: 2 tests, 4+ assertions, 0 failures.

- [ ] **Step 5: Run full generator test suite to confirm no regressions**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb`
Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/generators/pu/invites/install_generator.rb test/generators/invites_install_generator_test.rb
git commit -m "feat(invites/generator): scope routes per invite_model with idempotent re-run"
```

---

## Task 7: Welcome controller — multi-class integration on re-run

**Goal:** Make the welcome controller honor multiple invite classes. On first invocation, generate a welcome controller that calls `invite_classes` returning a single-element array. On subsequent invocations, inject the new class into the existing array.

**Files:**
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/controllers/invites/welcome_controller.rb.tt` — switch to `invite_classes` returning Array.
- Modify: `lib/generators/pu/invites/install_generator.rb` — add `add_welcome_invite_class` step that inserts the new class on second+ invocation.
- Modify: `lib/generators/pu/invites/templates/packages/invites/app/controllers/invites/user_invitations_controller.rb.tt` — switch generated user-invitations controller to also expose `invite_classes`? No — single-flow controller still uses `invite_class`. Welcome is the multi-class point.
- Modify: `test/generators/invites_install_generator_test.rb` — add re-run test.

**Acceptance Criteria:**
- [ ] First invocation generates welcome controller with `def invite_classes; [::Invites::UserInvite]; end`.
- [ ] Second invocation with `--invite_model=FunderInvite` mutates that to `[::Invites::UserInvite, ::Invites::FunderInvite]`.
- [ ] Third invocation with same model is a no-op (idempotent).
- [ ] Existing `WelcomeController` integration (`integrate_with_welcome_controller`) still updates host's `app/controllers/welcome_controller.rb` with `invite_classes`.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/welcome.*multi/"` → passes.

**Steps:**

- [ ] **Step 1: Update the welcome_controller template**

Edit `lib/generators/pu/invites/templates/packages/invites/app/controllers/invites/welcome_controller.rb.tt`. Replace:

```ruby
    def invite_class
      ::Invites::UserInvite
    end
```

with:

```ruby
    def invite_classes
      [::Invites::<%= invite_model %>]
    end
```

- [ ] **Step 2: Add a re-run test**

Append to `test/generators/invites_install_generator_test.rb`:

```ruby
  test "welcome controller invite_classes accumulates across invocations" do
    run_generator default_args
    run_generator default_args + ["--invite-model=FunderInvite"]

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_match(/def invite_classes/, content)
      assert_match(/::Invites::UserInvite/, content)
      assert_match(/::Invites::FunderInvite/, content)
      # Order matters for first-match semantics; both should appear in the same array literal.
      assert_match(/\[\s*::Invites::UserInvite\s*,\s*::Invites::FunderInvite\s*\]/m, content)
    end
  end

  test "welcome controller invite_classes injection is idempotent" do
    run_generator default_args
    run_generator default_args  # second run, same invite_model
    run_generator default_args  # third run, same invite_model

    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_equal 1, content.scan(/::Invites::UserInvite/).size
    end
  end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/welcome.*invite_classes/"`
Expected: tests fail — welcome controller is regenerated and overwritten on re-run, not accumulated.

- [ ] **Step 4: Add the `add_welcome_invite_class` step in install_generator**

In `lib/generators/pu/invites/install_generator.rb`, add this step after `create_controllers` and before `create_views`:

```ruby
      def add_welcome_invite_class
        welcome_path = "packages/invites/app/controllers/invites/welcome_controller.rb"
        return unless File.exist?(Rails.root.join(welcome_path))

        content = File.read(Rails.root.join(welcome_path))
        new_class = "::Invites::#{invite_model}"

        # Already present? bail.
        return if content =~ /\b#{Regexp.escape(new_class)}\b/

        # Find `def invite_classes` block; inject before the closing `]`.
        injection = content.sub(/(\bdef invite_classes\b.*?\[)([^\]]*)(\])/m) do
          before, list, after = Regexp.last_match[1], Regexp.last_match[2], Regexp.last_match[3]
          existing = list.strip
          new_list = existing.empty? ? new_class : "#{existing.chomp(",").strip}, #{new_class}"
          "#{before}#{new_list}#{after}"
        end

        if injection != content
          File.write(Rails.root.join(welcome_path), injection)
          say_status :inject, "Added #{new_class} to welcome controller's invite_classes", :green
        end
      end
```

Then update `create_controllers` so the welcome controller is generated only when missing (already done in Task 5, step 3 — confirm it's in place).

- [ ] **Step 5: Update host welcome controller integration**

In `integrate_with_welcome_controller`, replace the existing `def invite_class` injection with multi-class equivalent:

```ruby
        # Add invite_classes method if neither it nor invite_class is present
        unless file_content =~ /def invite_classes\b/ || file_content =~ /def invite_class\b/
          inject_into_file relative_path,
            "\n  def invite_classes\n    [::Invites::#{invite_model}]\n  end\n",
            before: /^end\s*\z/
        else
          # Inject this invite_model into the existing invite_classes array if missing.
          host_content = File.read(Rails.root.join(relative_path))
          if host_content =~ /def invite_classes\b/ && host_content !~ /::Invites::#{invite_model}\b/
            updated = host_content.sub(/(\bdef invite_classes\b.*?\[)([^\]]*)(\])/m) do
              before, list, after = Regexp.last_match[1], Regexp.last_match[2], Regexp.last_match[3]
              existing = list.strip
              new_list = existing.empty? ? "::Invites::#{invite_model}" : "#{existing.chomp(",").strip}, ::Invites::#{invite_model}"
              "#{before}#{new_list}#{after}"
            end
            File.write(Rails.root.join(relative_path), updated)
          end
        end
```

- [ ] **Step 6: Run tests to verify pass**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n "/welcome.*invite_classes|idempotent/"`
Expected: both tests pass.

- [ ] **Step 7: Run full generator test suite**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb`
Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
git add lib/generators/pu/invites/install_generator.rb lib/generators/pu/invites/templates/packages/invites/app/controllers/invites/welcome_controller.rb.tt test/generators/invites_install_generator_test.rb
git commit -m "feat(invites/generator): accumulate invite_classes across invocations"
```

---

## Task 8: End-to-end dual-invocation generator test

**Goal:** A single test that runs the generator twice with two different `--invite_model` values and asserts that both flows live side-by-side without collisions.

**Files:**
- Modify: `test/generators/invites_install_generator_test.rb`

**Acceptance Criteria:**
- [ ] Two invocations succeed without raising.
- [ ] Both migrations exist and target different tables.
- [ ] Both models, policies, definitions, mailers, controllers exist.
- [ ] Routes file contains both flows + a single welcome block.
- [ ] Welcome controller `invite_classes` lists both classes.
- [ ] Entity model has `has_many` for both invite tables.

**Verify:** `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n test_dual_invocation_yields_independent_flows` → passes.

**Steps:**

- [ ] **Step 1: Write the test**

Append to `test/generators/invites_install_generator_test.rb`:

```ruby
  test "dual invocation yields independent flows" do
    run_generator default_args  # UserInvite (default)
    run_generator default_args + ["--invite-model=FunderInvite"]

    # Both migrations exist, with distinct tables.
    assert_migration "db/migrate/create_user_invites.rb"
    assert_migration "db/migrate/create_funder_invites.rb"

    # Both models, policies, definitions, mailers, controllers exist.
    assert_file "packages/invites/app/models/invites/user_invite.rb"
    assert_file "packages/invites/app/models/invites/funder_invite.rb"
    assert_file "packages/invites/app/policies/invites/user_invite_policy.rb"
    assert_file "packages/invites/app/policies/invites/funder_invite_policy.rb"
    assert_file "packages/invites/app/definitions/invites/user_invite_definition.rb"
    assert_file "packages/invites/app/definitions/invites/funder_invite_definition.rb"
    assert_file "packages/invites/app/mailers/invites/user_invite_mailer.rb"
    assert_file "packages/invites/app/mailers/invites/funder_invite_mailer.rb"
    assert_file "packages/invites/app/controllers/invites/user_invitations_controller.rb"
    assert_file "packages/invites/app/controllers/invites/funder_invitations_controller.rb"

    # Routes contain both helpers + welcome appears exactly once.
    assert_file "config/routes.rb" do |content|
      assert_match(/as: :user_invitation\b/, content)
      assert_match(/as: :funder_invitation\b/, content)
      assert_equal 1, content.scan(/as: :invites_welcome_check\b/).size
    end

    # Entity has has_many for both invite tables.
    assert_file "app/models/organization.rb" do |content|
      assert_match(/has_many :user_invites, class_name: "Invites::UserInvite"/, content)
      assert_match(/has_many :funder_invites, class_name: "Invites::FunderInvite"/, content)
    end

    # Welcome controller invite_classes lists both.
    assert_file "packages/invites/app/controllers/invites/welcome_controller.rb" do |content|
      assert_match(/::Invites::UserInvite/, content)
      assert_match(/::Invites::FunderInvite/, content)
    end
  end
```

- [ ] **Step 2: Run the test**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb -n test_dual_invocation_yields_independent_flows`
Expected: test passes (Tasks 4–7 should have laid the foundation).

- [ ] **Step 3: Run the entire generator test file**

Run: `bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb`
Expected: all existing + all new tests pass; total run count grew from 48 → ~55.

- [ ] **Step 4: Commit**

```bash
git add test/generators/invites_install_generator_test.rb
git commit -m "test(invites/generator): cover dual-invocation independent flows"
```

---

## Task 9: Update skill + guide docs

**Goal:** Document the new `--invite_model` option and multi-flow welcome integration in both the user-facing guide and the AI skill.

**Files:**
- Modify: `.claude/skills/plutonium-invites/SKILL.md`
- Modify: `docs/guides/user-invites.md`

**Acceptance Criteria:**
- [ ] Skill includes a "Multiple invite flows" section with the two-invocation example.
- [ ] Guide includes the same in user-facing prose, plus a note on how `pending_invite` traverses all classes.
- [ ] Both mention the `invite_classes` Array hook and the `invitation_path_for` override.

**Verify:** `yarn docs:build` (in `docs/`) → no broken-link errors. (Optional: visually inspect the rendered guide.)

**Steps:**

- [ ] **Step 1: Read the current skill to find the right insertion point**

Run: `head -80 .claude/skills/plutonium-invites/SKILL.md`

Find the section listing options for `pu:invites:install`. Add a sub-section after it.

- [ ] **Step 2: Append the multi-flow section to the skill**

Append the following to `.claude/skills/plutonium-invites/SKILL.md` (under the install options or examples section):

```markdown
## Multiple invite flows in one app

Run `pu:invites:install` once per entity type. Pass `--invite_model=<Class>` to scope every per-flow file, route, and class:

```bash
rails g pu:invites:install \
  --entity_model=FunderOrganization \
  --user_model=SpenderAccount \
  --invite_model=FunderInvite

rails g pu:invites:install \
  --entity_model=Project \
  --user_model=Member \
  --invite_model=ProjectInvite
```

Each invocation creates an independent flow: model `Invites::FunderInvite` on `funder_invites`, controller `Invites::FunderInvitationsController` on `/funder_invitations/:token`, helper `funder_invitation_path`, etc. The shared `Invites::WelcomeController` accumulates each new class into its `invite_classes` array, so `pending_invite` checks all flows in priority order (first-match wins).

Override hooks at the model level:
- `def user_attribute; :spender_account; end` — when `belongs_to :spender_account` instead of `:user`.
- `def invite_entity_attribute; :funder_organization; end` — when `belongs_to :funder_organization` instead of `:entity`.

Override hooks at the controller level (auto-generated by the install generator):
- `def invite_classes; [::Invites::UserInvite, ::Invites::FunderInvite]; end` on `WelcomeController`.
- `def invitation_path_for(token); funder_invitation_path(token: token); end` on each invitations controller.
```

- [ ] **Step 3: Append a similar section to the docs guide**

Append to `docs/guides/user-invites.md`:

```markdown
## Multiple invite flows in one app

Some apps invite users to several distinct kinds of entity. Run `pu:invites:install` once per kind, passing `--invite_model` to scope class names, table names, and routes:

```bash
rails g pu:invites:install \
  --entity_model=FunderOrganization \
  --user_model=SpenderAccount \
  --invite_model=FunderInvite
```

Each invocation produces independent migrations, models, policies, definitions, mailers, controllers, view templates, and route helpers. The shared `Invites::WelcomeController` keeps a running list of invite classes; after-login checks consult all of them and use the first matching token.

If you need to plug a third-party invite class into the welcome flow, override `invite_classes` directly:

```ruby
class WelcomeController < ApplicationController
  include Plutonium::Invites::PendingInviteCheck

  def invite_classes
    [::Invites::UserInvite, ::Invites::FunderInvite, ::Foreign::ApiInvite]
  end
end
```
```

- [ ] **Step 4: Validate docs build**

Run: `cd docs && yarn docs:build`
Expected: build completes; no broken links touching the user-invites guide.

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/plutonium-invites/SKILL.md docs/guides/user-invites.md
git commit -m "docs(invites): document multi-invite-model support"
```

---

## Final integration check

Run the complete test suite for both Rails 8.0 and 8.1 to confirm no global regressions:

```bash
bundle exec appraisal rails-8.0 ruby -Itest test/generators/invites_install_generator_test.rb
bundle exec appraisal rails-8.0 ruby -Itest test/plutonium/invites/pending_invite_check_test.rb
bundle exec appraisal rails-8.0 ruby -Itest test/plutonium/invites/controller_test.rb
bundle exec appraisal rails-8.1 ruby -Itest test/generators/invites_install_generator_test.rb
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/pending_invite_check_test.rb
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/invites/controller_test.rb
```

All green → ready to push and tag a release.
