# PLUTONIUM_DEV Asset Overrides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `PLUTONIUM_DEV=1` from clobbering a consumer app's customized stylesheet/script URLs. The dev override should only apply to assets the consumer hasn't configured.

**Architecture:** `Plutonium::Configuration::AssetConfiguration` tracks per-attribute customization via generated setters. `Plutonium::Helpers::AssetsHelper#resource_asset_url_for` checks that flag before substituting the dev `/build/*` URL. No new env vars; PLUTONIUM_DEV continues to drive the Ruby reloader and the dev asset server mount.

**Tech Stack:** Ruby on Rails, Minitest, Plutonium gem internals.

**Spec:** `docs/superpowers/specs/2026-05-09-plutonium-dev-asset-overrides-design.md`

**Branch:** Create a new branch off the current `feature/ui-layout-overhaul`. Suggested name: `fix/plutonium-dev-respect-custom-assets`.

---

## File Structure

| Path | Status | Responsibility |
|---|---|---|
| `lib/plutonium/configuration.rb` | modify | Replace `AssetConfiguration`'s `attr_accessor` block with `DEFAULTS` map + generated readers/setters that record customization. Add `customized?(attr)` predicate. |
| `lib/plutonium/helpers/assets_helper.rb` | modify | In `resource_asset_url_for`, skip the dev URL swap when the relevant attr is customized. |
| `test/plutonium/configuration_test.rb` | create | Unit tests for `AssetConfiguration` defaults, setters, and `customized?` predicate. |
| `test/plutonium/helpers/assets_helper_test.rb` | create | Unit tests for `resource_asset_url_for` across the dev/non-dev × default/customized matrix. |
| `docs/guides/theming.md` | modify | Document that customizing `config.assets.stylesheet`/`script` opts out of the dev override. |
| `docs/reference/assets/index.md` | modify | Same note alongside the existing asset config example. |
| `CLAUDE.md` | modify | Clarify scope of "uses local assets instead of packaged ones" under the `PLUTONIUM_DEV=1` description. |

The dummy app and `lib/plutonium/railtie.rb` are intentionally untouched — see spec "What stays unchanged."

---

## Task 1: Setup branch

**Files:**
- (no file changes; git only)

- [ ] **Step 1: Create the working branch**

```bash
cd /home/mnforson/plutonium-core
git checkout -b fix/plutonium-dev-respect-custom-assets
git status
```

Expected: `On branch fix/plutonium-dev-respect-custom-assets`, working tree shows the same modified files as the starting state (the in-progress UI-overhaul edits).

---

## Task 2: AssetConfiguration tracks customization (TDD)

**Files:**
- Test: `test/plutonium/configuration_test.rb` (create)
- Modify: `lib/plutonium/configuration.rb:94-114` (the `AssetConfiguration` inner class)

- [ ] **Step 1: Write the failing test file**

Create `test/plutonium/configuration_test.rb` with this exact content:

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::ConfigurationTest < Minitest::Test
  class AssetConfigurationTest < Minitest::Test
    def setup
      @assets = Plutonium::Configuration::AssetConfiguration.new
    end

    def test_defaults_match_documented_values
      assert_equal "plutonium.png", @assets.logo
      assert_equal "plutonium.ico", @assets.favicon
      assert_equal "plutonium.css", @assets.stylesheet
      assert_equal "plutonium.min.js", @assets.script
    end

    def test_customized_is_false_for_fresh_configuration
      refute @assets.customized?(:logo)
      refute @assets.customized?(:favicon)
      refute @assets.customized?(:stylesheet)
      refute @assets.customized?(:script)
    end

    def test_setting_stylesheet_marks_only_stylesheet_customized
      @assets.stylesheet = "application"

      assert @assets.customized?(:stylesheet)
      refute @assets.customized?(:script)
      refute @assets.customized?(:logo)
      refute @assets.customized?(:favicon)
      assert_equal "application", @assets.stylesheet
    end

    def test_setting_script_marks_only_script_customized
      @assets.script = "application"

      assert @assets.customized?(:script)
      refute @assets.customized?(:stylesheet)
    end

    def test_assigning_default_value_still_marks_customized
      @assets.stylesheet = "plutonium.css"

      assert @assets.customized?(:stylesheet),
        "Explicit assignment counts as customization even when the new value matches the default"
    end

    def test_customized_with_unknown_attr_returns_false
      refute @assets.customized?(:nonexistent)
    end

    def test_logo_and_favicon_setters_track_customization
      @assets.logo = "custom.png"
      @assets.favicon = "custom.ico"

      assert @assets.customized?(:logo)
      assert @assets.customized?(:favicon)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/configuration_test.rb
```

Expected: tests run, several fail with `NoMethodError: undefined method 'customized?'` for the configured tests. The `test_defaults_match_documented_values` test should pass (defaults already exist).

If `bundle exec appraisal rails-8.1` is unavailable, fall back to:

```bash
bundle exec ruby -Itest test/plutonium/configuration_test.rb
```

- [ ] **Step 3: Implement the AssetConfiguration changes**

Open `lib/plutonium/configuration.rb`. Replace the entire `AssetConfiguration` inner class (lines 93–114 in the current file) with this implementation:

```ruby
    # Asset configuration for Plutonium
    class AssetConfiguration
      DEFAULTS = {
        logo: "plutonium.png",
        favicon: "plutonium.ico",
        stylesheet: "plutonium.css",
        script: "plutonium.min.js"
      }.freeze

      # @return [String] path to logo file
      # @return [String] path to favicon file
      # @return [String] path to stylesheet file
      # @return [String] path to JavaScript file

      def initialize
        @customized = {}
        DEFAULTS.each { |key, value| instance_variable_set(:"@#{key}", value) }
      end

      DEFAULTS.each_key do |attr|
        attr_reader attr

        define_method(:"#{attr}=") do |value|
          @customized[attr] = true
          instance_variable_set(:"@#{attr}", value)
        end
      end

      # Whether the given asset attribute was set explicitly by user code.
      #
      # An asset is considered customized once any value is assigned to it,
      # even if that value happens to equal the default. The dev-mode asset
      # URL override (see Plutonium::Helpers::AssetsHelper#resource_asset_url_for)
      # only applies to attributes that have NOT been customized.
      #
      # @param attr [Symbol] one of :logo, :favicon, :stylesheet, :script
      # @return [Boolean]
      def customized?(attr)
        @customized.fetch(attr, false)
      end
    end
```

Leave the rest of `lib/plutonium/configuration.rb` (the outer `Configuration` class, the `Plutonium.configuration` / `Plutonium.configure` accessors) unchanged.

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/configuration_test.rb
```

Expected: all 7 tests in `AssetConfigurationTest` pass.

- [ ] **Step 5: Commit**

```bash
cd /home/mnforson/plutonium-core
git add lib/plutonium/configuration.rb test/plutonium/configuration_test.rb
git commit -m "feat(config): track per-attribute asset customization

AssetConfiguration now records when each asset attr (logo, favicon,
stylesheet, script) has been explicitly assigned. A new customized?
predicate exposes that state. Reader behavior and default values
are unchanged.

Refs: docs/superpowers/specs/2026-05-09-plutonium-dev-asset-overrides-design.md"
```

---

## Task 3: AssetsHelper respects customization in dev mode (TDD)

**Files:**
- Test: `test/plutonium/helpers/assets_helper_test.rb` (create)
- Modify: `lib/plutonium/helpers/assets_helper.rb:73-79` (the `resource_asset_url_for` method)

- [ ] **Step 1: Write the failing test file**

Create `test/plutonium/helpers/assets_helper_test.rb` with this exact content:

```ruby
# frozen_string_literal: true

require "test_helper"

class Plutonium::Helpers::AssetsHelperTest < Minitest::Test
  class TestHost
    include Plutonium::Helpers::AssetsHelper
  end

  def setup
    @host = TestHost.new
    @original_config = Plutonium.instance_variable_get(:@configuration)
    Plutonium.instance_variable_set(:@configuration, Plutonium::Configuration.new)
  end

  def teardown
    Plutonium.instance_variable_set(:@configuration, @original_config)
  end

  def test_non_dev_mode_returns_fallback_for_default_stylesheet
    Plutonium.configuration.development = false

    url = @host.send(:resource_asset_url_for, :css, "plutonium.css")

    assert_equal "plutonium.css", url
  end

  def test_non_dev_mode_returns_fallback_for_customized_stylesheet
    Plutonium.configuration.development = false
    Plutonium.configuration.assets.stylesheet = "application"

    url = @host.send(:resource_asset_url_for, :css, "application")

    assert_equal "application", url
  end

  def test_dev_mode_with_default_stylesheet_uses_build_url
    Plutonium.configuration.development = true

    url = @host.send(:resource_asset_url_for, :css, "plutonium.css")

    assert_match %r{\A/build/}, url,
      "Expected dev override to substitute a /build/* URL when stylesheet is at default; got #{url.inspect}"
  end

  def test_dev_mode_with_customized_stylesheet_returns_fallback
    Plutonium.configuration.development = true
    Plutonium.configuration.assets.stylesheet = "application"

    url = @host.send(:resource_asset_url_for, :css, "application")

    assert_equal "application", url,
      "Customized stylesheet must opt out of the dev URL override"
  end

  def test_dev_mode_with_default_script_uses_build_url
    Plutonium.configuration.development = true

    url = @host.send(:resource_asset_url_for, :js, "plutonium.min.js")

    assert_match %r{\A/build/}, url
  end

  def test_dev_mode_with_customized_script_returns_fallback
    Plutonium.configuration.development = true
    Plutonium.configuration.assets.script = "application"

    url = @host.send(:resource_asset_url_for, :js, "application")

    assert_equal "application", url
  end

  def test_customizing_stylesheet_does_not_affect_script_override
    Plutonium.configuration.development = true
    Plutonium.configuration.assets.stylesheet = "application"

    js_url = @host.send(:resource_asset_url_for, :js, "plutonium.min.js")

    assert_match %r{\A/build/}, js_url,
      "Customizing stylesheet only must not silence the dev override on script"
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/helpers/assets_helper_test.rb
```

Expected: `test_dev_mode_with_customized_stylesheet_returns_fallback`, `test_dev_mode_with_customized_script_returns_fallback`, and `test_customizing_stylesheet_does_not_affect_script_override` (last assertion irrelevant — script not yet customized in that test, so it might already pass) FAIL because the helper currently overrides regardless of customization. The two `test_dev_mode_with_default_*` tests should pass (existing behavior). Non-dev tests should pass.

It is fine if some "PASS" mixes in. The point is: at least one of the customized-in-dev-mode tests must currently fail. If they all pass, the test isn't actually exercising the bug — re-read the test before proceeding.

- [ ] **Step 3: Implement the helper change**

Open `lib/plutonium/helpers/assets_helper.rb`. Replace the existing `resource_asset_url_for` method (lines 73–79 in the current file) with:

```ruby
      # Generate the appropriate asset URL based on the environment
      #
      # In development mode, framework assets are normally served from the
      # /build mount so source edits in the gem hot-reload. That override is
      # skipped when the consumer has customized the asset config — otherwise
      # the consumer's bundled application stylesheet/script (which already
      # imports plutonium at source) would be replaced by the raw framework
      # asset, dropping all of their tokens, theme, and JS controllers.
      #
      # @param type [Symbol] asset type (:css or :js)
      # @param fallback [String] fallback asset path
      # @return [String] asset URL
      def resource_asset_url_for(type, fallback)
        attr = (type == :css) ? :stylesheet : :script
        if Plutonium.configuration.development? &&
            !Plutonium.configuration.assets.customized?(attr)
          resource_development_asset_url(type)
        else
          fallback
        end
      end
```

Leave `resource_development_asset_url` and the rest of `assets_helper.rb` unchanged.

- [ ] **Step 4: Run the test to verify it passes**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 ruby -Itest test/plutonium/helpers/assets_helper_test.rb
```

Expected: all 7 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /home/mnforson/plutonium-core
git add lib/plutonium/helpers/assets_helper.rb test/plutonium/helpers/assets_helper_test.rb
git commit -m "fix(assets): respect consumer asset config under PLUTONIUM_DEV

resource_asset_url_for now skips the /build/* dev override whenever
the consumer has set config.assets.stylesheet or .script. With
PLUTONIUM_DEV=1, customized apps continue to ship their bundled
application.css / application.js (with their tokens, theme, and JS
controllers); apps that haven't customized still benefit from the
hot-served /build URLs.

Refs: docs/superpowers/specs/2026-05-09-plutonium-dev-asset-overrides-design.md"
```

---

## Task 4: Run the full test suite for regression check

**Files:**
- (none — verification only)

- [ ] **Step 1: Run the targeted suite**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 rake test TEST="test/plutonium/configuration_test.rb test/plutonium/helpers/assets_helper_test.rb test/plutonium_test.rb"
```

Expected: all tests pass. `test/plutonium_test.rb` includes the existing `test_development?` case that flips `PLUTONIUM_DEV` between `"true"` and `"false"`; verify it still passes.

- [ ] **Step 2: Run the broader helper + configuration tests**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 rake test TEST="test/plutonium/helpers/**/*.rb test/plutonium/configuration_test.rb test/plutonium_test.rb"
```

Expected: all pass.

- [ ] **Step 3: Run the full suite**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 rake test
```

Expected: same pass/fail ratio as before this branch started. Compare to `master`/`feature/ui-layout-overhaul` baseline if anything looks suspicious — there are pre-existing failures in some areas of the repo that this change must not make worse.

If a test fails that didn't fail before, do NOT proceed. Investigate: most likely cause is something else in the codebase calling `Plutonium.configuration.assets.<attr>=` and now unintentionally tripping `customized?`. The fix should preserve all current behavior for non-dev mode.

---

## Task 5: Manual verification in the dummy app

**Files:**
- (none — runtime check)

- [ ] **Step 1: Build the gem's dev assets**

```bash
cd /home/mnforson/plutonium-core
yarn build
```

Or, if a `yarn dev` watcher is already running in another terminal, skip this step.

Expected: `src/build/css.manifest`, `src/build/js.manifest`, and the hashed CSS/JS appear and are recent.

- [ ] **Step 2: Boot the dummy app under PLUTONIUM_DEV**

```bash
cd /home/mnforson/plutonium-core/test/dummy
PLUTONIUM_DEV=1 bin/rails server -p 3001
```

In a browser, open `http://localhost:3001/` (or whatever the dummy app's home / admin route is — `bin/rails routes | head` if unsure).

- [ ] **Step 3: Confirm dummy app behavior is unchanged**

In the browser, view source. Look for the `<link rel="stylesheet">` and `<script>` tags emitted via `resource_stylesheet_tag` / `resource_script_tag`.

Expected: URLs include `/build/plutonium-<hash>.css` and `/build/plutonium-<hash>.js` (the dummy app does not customize asset config, so the dev override still applies and hot-reload via `/build` continues to work).

Stop the server (`Ctrl-C`).

- [ ] **Step 4: (Optional) Confirm the consumer-app fix on a separate app**

If a real consumer-app checkout is available locally:

1. In the consumer app, ensure `pu:core:assets` has been run (it sets `config.assets.stylesheet = "application"` etc.).
2. Point its Gemfile at this branch (e.g. `gem "plutonium", path: "../plutonium-core"`), then `bundle install`.
3. Run the consumer's `yarn dev` and `PLUTONIUM_DEV=1 bin/rails server`.
4. View source: stylesheet/script URLs should be the consumer's bundled `application.css` / `application.js` — **not** `/build/...`. The page should render with the consumer's theme/tokens and Stimulus controllers active.

If no consumer app is available, this step is skipped. The unit tests cover the behavior; the dummy-app step (3) is the load-bearing check.

---

## Task 6: Documentation updates

**Files:**
- Modify: `docs/guides/theming.md` (around line 250 where asset config is shown)
- Modify: `docs/reference/assets/index.md` (around line 37–40)
- Modify: `CLAUDE.md` (project root, the `PLUTONIUM_DEV=1` description block — lines that read "Uses local assets instead of packaged ones")

- [ ] **Step 1: Read the current docs to find exact insertion points**

```bash
cd /home/mnforson/plutonium-core
grep -n "config.assets" docs/guides/theming.md docs/reference/assets/index.md
grep -n "PLUTONIUM_DEV\|local assets" CLAUDE.md
```

Note the line numbers; they're needed for the edits below.

- [ ] **Step 2: Update `docs/guides/theming.md`**

Find the existing block that shows:

```ruby
  config.assets.stylesheet = "application"  # Your CSS file
  config.assets.script = "application"      # Your JS file
  config.assets.logo = "my_logo.png"        # Logo image
  config.assets.favicon = "my_favicon.ico"  # Favicon
```

Immediately after that fenced code block, insert this paragraph:

```markdown

> **PLUTONIUM_DEV interaction:** Setting `config.assets.stylesheet` or `config.assets.script` opts out of the dev-mode asset URL override that `PLUTONIUM_DEV=1` applies. Your bundled `application.css` / `application.js` ships in all modes; the gem's source is still hot-reloaded through your build pipeline because `application.tailwind.css` already imports `gem:plutonium/src/css/plutonium.css`.

```

- [ ] **Step 3: Update `docs/reference/assets/index.md`**

Find the existing block that shows:

```ruby
  config.assets.stylesheet = "application"    # Your CSS file
  config.assets.script = "application"        # Your JS file
  config.assets.logo = "my_logo.png"          # Logo image
  config.assets.favicon = "my_favicon.ico"    # Favicon
```

Immediately after that block, insert the same paragraph as in Step 2.

- [ ] **Step 4: Update `CLAUDE.md`**

Find this section:

```markdown
This enables development mode which:
- Uses local assets instead of packaged ones
- Enables hot reloading of components
- Shows more detailed error messages
```

Replace the first bullet so the section reads:

```markdown
This enables development mode which:
- Uses local assets from `src/build/` instead of packaged ones — but only for assets the consumer has not customized via `config.assets.stylesheet` / `.script`. Once you run `pu:core:assets` (or set those values yourself), your bundled `application.css` / `application.js` ships in all modes.
- Enables hot reloading of components
- Shows more detailed error messages
```

- [ ] **Step 5: Check the plutonium-assets skill for PLUTONIUM_DEV references**

```bash
cd /home/mnforson/plutonium-core
grep -n "PLUTONIUM_DEV\|local assets\|/build" .claude/skills/plutonium-assets/SKILL.md 2>/dev/null || true
```

If matches appear that describe the *old* behavior ("dev mode replaces your assets"), update them in the same spirit as the CLAUDE.md edit: note that customization opts out of the override. If no matches, skip.

If you edit the skill, add it to the same docs commit in Step 7 (`git add .claude/skills/plutonium-assets/SKILL.md`).

- [ ] **Step 6: Verify the docs site builds**

```bash
cd /home/mnforson/plutonium-core
yarn docs:build
```

Expected: build completes without broken-link errors. If `yarn docs:build` is not available in the environment, skip this step — the changes are pure prose.

- [ ] **Step 7: Commit the docs**

```bash
cd /home/mnforson/plutonium-core
git add docs/guides/theming.md docs/reference/assets/index.md CLAUDE.md
git commit -m "docs(assets): document PLUTONIUM_DEV opt-out for customized assets

Setting config.assets.stylesheet or .script now opts the consumer
out of the dev-mode /build URL override. Note this in the theming
guide, the assets reference, and the project CLAUDE.md."
```

---

## Task 7: Final verification & branch hygiene

**Files:**
- (none)

- [ ] **Step 1: Run the test suite one more time**

```bash
cd /home/mnforson/plutonium-core
bundle exec appraisal rails-8.1 rake test
```

Expected: same pass/fail set as on the parent branch, plus the new tests passing.

- [ ] **Step 2: Inspect the branch's diff against the parent**

```bash
cd /home/mnforson/plutonium-core
git log --oneline feature/ui-layout-overhaul..HEAD
git diff --stat feature/ui-layout-overhaul..HEAD
```

Expected: 3 commits (config, helper, docs), changes confined to the files listed in "File Structure" above. No drift into railtie, reloader, dummy app, or unrelated areas.

- [ ] **Step 3: Hand off**

Report to the user:
- Branch name
- Commits made
- Test results
- Whether the manual dummy-app verification was completed (and any consumer-app verification, if performed)

Do not merge or push without explicit user instruction.
